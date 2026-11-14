--- @type table<integer, Detector>
Detectors = {}

--- Config.DefaultSettings with the admin menu's saved values on top
Settings = lib.table.deepclone(Config.DefaultSettings)

-- Settings.cooldown: how often one player can raise an alarm (alert, log, webhook) at one detector
local cooldown = Detection.NewCooldown()
-- Light and sound show on every pass; this only stops a client from spamming the event
local passGuard = Detection.NewCooldown()
local PASS_GUARD_MS <const> = 1500

--- @param message string
--- @return CallbackResponse
function Fail(message)
    Debug("warning", "request failed: %s", message)
    return { success = false, error = message }
end

--- JSON columns can come back decoded or as a string
--- @param value any
--- @return any
function DecodeJson(value)
    if type(value) ~= "string" then return value end
    local ok, decoded = pcall(json.decode, value)
    return ok and decoded or nil
end

--- @param playerId number
--- @return string
function GetPlayerDisplayName(playerId)
    return Framework.Server.GetCharacterName(playerId) or GetPlayerName(playerId) or "Unknown"
end

--- @param row table hype_dedector_detectors row
--- @return Detector
function FormatDetector(row)
    local categories = DecodeJson(row.categories)

    return {
        id = row.id,
        name = row.name,
        area = row.area or "",
        x = row.x + 0.0,
        y = row.y + 0.0,
        z = row.z + 0.0,
        heading = row.heading + 0.0,
        categories = type(categories) == "table" and categories or {},
        -- TINYINT(1) can come back as a boolean or a number depending on oxmysql's type casting
        alert = row.alert == true or row.alert == 1,
        status = row.status,
    }
end

--- What alerts and Config.ShouldScan get about a detector. Only where it is, never what it reacts to
--- @param detector Detector
function PublicDetector(detector)
    return {
        id = detector.id,
        name = detector.name,
        area = detector.area,
        coords = vector3(detector.x, detector.y, detector.z),
    }
end

function LoadDetectors()
    local detectors = {}

    for _, row in ipairs(MySQL.query.await(Queries.GetDetectors) or {}) do
        detectors[row.id] = FormatDetector(row)
    end

    Detectors = detectors
    Debug("info", "loaded %d detector(s)", TableSize(detectors))
end

--- Active detectors, as the clients need them for the prop and the trigger box
--- @return Detector[]
function GetActiveDetectors()
    local list = {}

    for _, detector in pairs(Detectors) do
        if detector.status == "active" then
            list[#list + 1] = {
                id = detector.id,
                name = detector.name,
                x = detector.x,
                y = detector.y,
                z = detector.z,
                heading = detector.heading,
            }
        end
    end

    return list
end

function BroadcastDetectors()
    TriggerClientEvent("hype-dedector:client:set-detectors", -1, GetActiveDetectors())
end

function LoadSettings()
    local settings = lib.table.deepclone(Config.DefaultSettings)

    for _, row in ipairs(MySQL.query.await(Queries.GetSettings) or {}) do
        local value = DecodeJson(row.value)
        if value ~= nil and settings[row.key] ~= nil then
            settings[row.key] = value
        end
    end

    Settings = settings
end

--- @param key string
--- @param value any
function SaveSetting(key, value)
    MySQL.query.await(Queries.SaveSetting, { key, json.encode(value) })
    Settings[key] = value
end

--- Only loaded on the server and never sent to clients, so the webhook can't be read in game
local ServerConfig <const> = require "config.sv-config"
local webhook <const> = type(ServerConfig.Webhook) == "string" and TrimString(ServerConfig.Webhook) or ""

--- @param kind string Settings key that has to be true for this log, e.g. "logAlarms"
--- @param title string
--- @param message string
function SendWebhookLog(kind, title, message)
    if not Settings[kind] or webhook == "" then return end

    PerformHttpRequest(webhook, function() end, "POST", json.encode({
        username = locale("notify_title"),
        embeds = {
            {
                title = title,
                description = message,
                color = 15158332,
                footer = { text = os.date("%d.%m.%Y %H:%M:%S") },
            },
        },
    }), { ["Content-Type"] = "application/json" })

    Debug("info", "webhook log sent: %s", title)
end

--- Default target of Config.Alert.server: sends Config.Alert.client to every player in Config.Alert.jobs
--- @param data AlertData
function SendAlertToJobs(data)
    local clientData = { detector = data.detector, time = data.time }
    local sent = 0

    for _, playerId in ipairs(Framework.Server.GetPlayers()) do
        local job = Framework.Server.GetPlayerJob(playerId)

        if Detection.IsJobIgnored(job, Config.Alert.jobs, Config.Alert.requireDuty) then
            TriggerClientEvent("hype-dedector:client:alert", playerId, clientData)
            sent = sent + 1
        end
    end

    Debug("info", "alert for detector %s sent to %d player(s)", data.detector.id, sent)
end

--- Light and sound for everyone close enough to see the detector
--- @param detector Detector
--- @param result FeedbackResult
local function sendFeedback(detector, result)
    local center = vector3(detector.x, detector.y, detector.z)

    for _, id in ipairs(GetPlayers()) do
        local ped = GetPlayerPed(id)

        if ped ~= 0 and #(GetEntityCoords(ped) - center) <= Config.Feedback.radius then
            TriggerClientEvent("hype-dedector:client:feedback", id, detector.id, result)
        end
    end
end

--- @param playerId number
--- @param detector Detector
local function onAlarm(playerId, detector)
    -- Turned off per detector in the admin menu: it still beeps and logs, but nobody is alerted
    if detector.alert then
        local ok, err = pcall(Config.Alert.server, { source = playerId, detector = PublicDetector(detector), time = os.time() })

        if not ok then
            print(("^1[hype-dedector] Config.Alert.server failed: %s^0"):format(err))
        end
    end

    if not Settings.logAlarms then return end

    local name = GetPlayerDisplayName(playerId)
    MySQL.insert(Queries.InsertLog, { detector.id, Framework.Server.GetPlayerIdentifier(playerId) or "", name:sub(1, 64) })
    SendWebhookLog("logAlarms", locale("log_title_alarm"), locale("log_alarm", name, detector.name, detector.area))
end

-- The client only says which detector it walked through. Everything else is checked here
RegisterNetEvent("hype-dedector:server:passed", function(detectorId)
    local playerId = source
    local detector = Detectors[tonumber(detectorId)]

    if not detector or detector.status ~= "active" then return end

    local ped = GetPlayerPed(playerId)
    if ped == 0 then return end

    local distance = #(GetEntityCoords(ped) - vector3(detector.x, detector.y, detector.z))
    if distance > Config.Detector.maxDistance then
        Debug("warning", "player %s reported detector %s from %.1fm away", playerId, detector.id, distance)
        return
    end

    local key = playerId .. ":" .. detector.id
    if not passGuard:check(key, GetGameTimer(), PASS_GUARD_MS) then return end

    local ignored = Detection.IsJobIgnored(Framework.Server.GetPlayerJob(playerId), Config.IgnoreJobs.jobs, Config.IgnoreJobs.requireDuty)

    if not ignored then
        local ok, scan = pcall(Config.ShouldScan, playerId, PublicDetector(detector))
        ignored = ok and scan == false
    end

    local alarm = not ignored and Detection.HasMetal(
        Modules.Server.Inventory.GetItems(playerId),
        Config.Categories,
        Config.NonMetal,
        detector.categories
    )

    Debug("info", "player %s passed detector %s: %s", playerId, detector.id, alarm and "alarm" or "clear")
    sendFeedback(detector, alarm and "alarm" or "clear")

    -- The detector still beeps red inside the cooldown, only the alert and the log are skipped
    if alarm and cooldown:check(key, GetGameTimer(), (tonumber(Settings.cooldown) or 0) * 1000) then
        onAlarm(playerId, detector)
    end
end)

lib.callback.register("hype-dedector:server:get-detectors", function()
    return GetActiveDetectors()
end)

AddEventHandler("playerDropped", function()
    cooldown:clear(source .. ":")
    passGuard:clear(source .. ":")
end)

AddEventHandler("onResourceStart", function(resource)
    if resource ~= GetCurrentResourceName() then return end

    initSQL()

    -- Fails when the table doesn't exist yet (AutoRunSQL off and the SQL not run); the rest of the start must go on
    local migrated, err = pcall(function()
        if (tonumber(MySQL.scalar.await(Queries.HasAlertColumn)) or 0) == 0 then
            MySQL.query.await(Queries.AddAlertColumn)
            print("^2[hype-dedector] Added the `alert` column to hype_dedector_detectors.^0")
        end
    end)

    if not migrated then
        print(("^1[hype-dedector] Could not add the `alert` column, run INSTALL/insert-me.sql: %s^0"):format(err))
    end

    -- Older versions saved the webhook from the admin menu; it must not stay in the database
    MySQL.query.await(Queries.DeleteSetting, { "webhook" })
    LoadSettings()
    LoadDetectors()
    BroadcastDetectors()

    -- Old alarm logs are removed once at start and then every hour
    CreateThread(function()
        while true do
            MySQL.query.await(Queries.PurgeLogs, { tonumber(Settings.logRetentionDays) or Config.DefaultSettings.logRetentionDays })
            Wait(60 * 60 * 1000)
        end
    end)
end)
