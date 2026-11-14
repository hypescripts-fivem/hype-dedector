local categoryValues = {}
for _, category in ipairs(Config.Categories) do
    categoryValues[category.value] = true
end

--- Checks everything the admin menu sent and returns a clean copy. Pure, so tests can run it.
--- @param data any
--- @return DetectorInput? detector
--- @return string? errorKey locale key
function ValidateDetector(data)
    if type(data) ~= "table" then return nil, "error_invalid_detector" end

    local name = TrimString(type(data.name) == "string" and data.name or "")
    local nameLength = utf8.len(name)
    if not nameLength or nameLength < 1 or nameLength > Config.Limits.nameLength then
        return nil, "error_invalid_name"
    end

    local location = type(data.location) == "table" and data.location or {}
    local x, y, z = tonumber(location.x), tonumber(location.y), tonumber(location.z)
    if not x or not y or not z or (x == 0 and y == 0 and z == 0) then
        return nil, "error_invalid_location"
    end

    local categories, seen = {}, {}
    for _, value in ipairs(type(data.categories) == "table" and data.categories or {}) do
        if not categoryValues[value] then return nil, "error_invalid_categories" end

        if not seen[value] then
            seen[value] = true
            categories[#categories + 1] = value
        end
    end
    if #categories == 0 then return nil, "error_invalid_categories" end

    -- Whether this detector's alarms reach Config.Alert.server (police / security). On unless turned off
    local alert = data.alert
    if alert == nil then alert = true end
    if type(alert) ~= "boolean" then return nil, "error_invalid_detector" end

    local area = type(location.label) == "string" and TrimString(location.label) or ""

    return {
        name = name,
        area = area:sub(1, 64),
        x = x,
        y = y,
        z = z,
        heading = (tonumber(location.heading) or 0.0) % 360.0,
        categories = categories,
        alert = alert,
    }
end

--- @param errorKey string
--- @return CallbackResponse
local function failValidation(errorKey)
    return Fail(locale(errorKey, Config.Limits.nameLength))
end

--- @param playerId number?
--- @return boolean
local function isAdmin(playerId)
    return playerId ~= nil and Framework.Server.IsAdmin(playerId) == true
end

--- Sends an admin action to the webhook, if logAlarms is on
--- @param playerId number The admin
--- @param key string Locale key; the admin is its first argument
local function logAdmin(playerId, key, ...)
    SendWebhookLog("logAlarms", locale("log_title_admin"), locale(key, ("%s (%s)"):format(GetPlayerDisplayName(playerId), playerId), ...))
end

--- "YYYY-MM-DD" for the last `count` days, oldest first
--- @param count integer
--- @return string[]
local function lastDays(count)
    local days = {}
    local now = os.time()

    for index = count - 1, 0, -1 do
        days[#days + 1] = os.date("%Y-%m-%d", now - index * 86400) --[[@as string]]
    end

    return days
end

--- @param row table
--- @return AlarmLog
local function formatLog(row)
    return {
        id = row.id,
        detectorId = row.detector_id,
        detectorName = row.detector_name,
        name = row.name,
        createdAt = (tonumber(row.created_at) or 0) * 1000,
    }
end

--- @param detector Detector
--- @param alarmsToday integer?
local function adminDetector(detector, alarmsToday)
    return {
        id = detector.id,
        name = detector.name,
        area = detector.area,
        x = detector.x,
        y = detector.y,
        z = detector.z,
        heading = detector.heading,
        categories = detector.categories,
        alert = detector.alert,
        status = detector.status,
        alarmsToday = alarmsToday or 0,
    }
end

--- Re-reads one detector from the database into the cache and tells every client
--- @param detectorId integer
--- @return Detector?
local function refreshDetector(detectorId)
    local row = MySQL.single.await(Queries.GetDetector, { detectorId })
    Detectors[detectorId] = row and FormatDetector(row) or nil
    BroadcastDetectors()
    return Detectors[detectorId]
end

lib.addCommand(Config.Commands.AdminMenu.name, {
    help = Config.Commands.AdminMenu.help,
    params = {},
    restricted = "group.admin",
}, function(source)
    if not isAdmin(source) then
        Debug("warning", "player %s used /%s without being an admin", source, Config.Commands.AdminMenu.name)
        return
    end

    TriggerClientEvent("hype-dedector:client:open-admin-menu", source)
end)

-- Places the hand detector prop in the admin's hand to tune Config.HandDetector.prop
lib.addCommand(Config.Commands.PropEditor.name, {
    help = Config.Commands.PropEditor.help,
    params = {
        { name = "bone", type = "number", help = "Ped bone id, e.g. 18905 left hand, 57005 right hand", optional = true },
    },
    restricted = "group.admin",
}, function(source, args)
    if not isAdmin(source) then return end

    TriggerClientEvent("hype-dedector:client:prop-editor", source, args.bone)
end)

lib.callback.register("hype-dedector:server:get-admin-data", function(source)
    if not isAdmin(source) then return Fail(locale("error_no_permission")) end

    local alarmsByDetector = {}
    for _, row in ipairs(MySQL.query.await(Queries.GetAlarmsTodayByDetector) or {}) do
        alarmsByDetector[row.detector_id] = tonumber(row.count) or 0
    end

    local detectors, active = {}, 0
    for _, detector in pairs(Detectors) do
        detectors[#detectors + 1] = adminDetector(detector, alarmsByDetector[detector.id])
        if detector.status == "active" then active = active + 1 end
    end
    table.sort(detectors, function(a, b) return a.id > b.id end)

    -- Days without an alarm still show up on the chart as 0
    local alarmsByDay = {}
    for _, row in ipairs(MySQL.query.await(Queries.GetDailyAlarms, { Config.Limits.statsDays - 1 }) or {}) do
        alarmsByDay[row.day] = tonumber(row.alarms) or 0
    end

    local daily = {}
    for index, day in ipairs(lastDays(Config.Limits.statsDays)) do
        daily[index] = { date = day, alarms = alarmsByDay[day] or 0 }
    end

    local recent = {}
    for index, row in ipairs(MySQL.query.await(Queries.GetLogs, { 0, 0, Config.Limits.recentLogs, 0 }) or {}) do
        recent[index] = formatLog(row)
    end

    local categories = {}
    for index, category in ipairs(Config.Categories) do
        categories[index] = { value = category.value, label = category.label }
    end

    return {
        success = true,
        data = {
            detectors = detectors,
            categories = categories,
            defaultCategories = Config.DefaultCategories,
            settings = Settings,
            limits = {
                nameLength = Config.Limits.nameLength,
                maxCooldown = Config.Limits.maxCooldown,
                maxRetentionDays = Config.Limits.maxRetentionDays,
            },
            stats = {
                total = #detectors,
                active = active,
                alarmsToday = tonumber(MySQL.scalar.await(Queries.CountAlarmsToday)) or 0,
            },
            daily = daily,
            recent = recent,
        },
    }
end)

lib.callback.register("hype-dedector:server:create-detector", function(source, data)
    if not isAdmin(source) then return Fail(locale("error_no_permission")) end

    local detector, err = ValidateDetector(data)
    if not detector then return failValidation(err --[[@as string]]) end

    if MySQL.scalar.await(Queries.GetDetectorNearPosition, { 0, detector.x, detector.y, detector.z, Config.Limits.detectorSpacing }) then
        return Fail(locale("error_too_close"))
    end

    local id = MySQL.insert.await(Queries.InsertDetector, {
        detector.name, detector.area, detector.x, detector.y, detector.z, detector.heading, json.encode(detector.categories),
        detector.alert and 1 or 0,
    })
    if not id then return Fail(locale("error_database")) end

    local saved = refreshDetector(id)
    logAdmin(source, "log_admin_created", detector.name, id)

    return { success = true, data = saved and adminDetector(saved) }
end)

lib.callback.register("hype-dedector:server:update-detector", function(source, data)
    if not isAdmin(source) then return Fail(locale("error_no_permission")) end

    local id = type(data) == "table" and tonumber(data.id)
    if not id or not Detectors[id] then return Fail(locale("error_not_found")) end

    local detector, err = ValidateDetector(data)
    if not detector then return failValidation(err --[[@as string]]) end

    if MySQL.scalar.await(Queries.GetDetectorNearPosition, { id, detector.x, detector.y, detector.z, Config.Limits.detectorSpacing }) then
        return Fail(locale("error_too_close"))
    end

    MySQL.update.await(Queries.UpdateDetector, {
        detector.name, detector.area, detector.x, detector.y, detector.z, detector.heading, json.encode(detector.categories),
        detector.alert and 1 or 0, id,
    })

    local saved = refreshDetector(id)
    logAdmin(source, "log_admin_updated", detector.name, id)

    return { success = true, data = saved and adminDetector(saved) }
end)

lib.callback.register("hype-dedector:server:delete-detector", function(source, data)
    if not isAdmin(source) then return Fail(locale("error_no_permission")) end

    local id = type(data) == "table" and tonumber(data.id)
    local detector = id and Detectors[id]
    if not detector then return Fail(locale("error_not_found")) end

    MySQL.query.await(Queries.DeleteDetector, { id })
    MySQL.query.await(Queries.DeleteDetectorLogs, { id })
    refreshDetector(id)
    logAdmin(source, "log_admin_deleted", detector.name, id)

    return { success = true }
end)

lib.callback.register("hype-dedector:server:set-status", function(source, data)
    if not isAdmin(source) then return Fail(locale("error_no_permission")) end

    local id = type(data) == "table" and tonumber(data.id)
    local detector = id and Detectors[id]
    if not detector then return Fail(locale("error_not_found")) end

    local status = data.status
    if status ~= "active" and status ~= "disabled" then return Fail(locale("error_invalid_status")) end

    MySQL.update.await(Queries.SetDetectorStatus, { status, id })
    local saved = refreshDetector(id)
    logAdmin(source, "log_admin_status", detector.name, id, status)

    return { success = true, data = saved and adminDetector(saved) }
end)

lib.callback.register("hype-dedector:server:get-logs", function(source, data)
    if not isAdmin(source) then return Fail(locale("error_no_permission")) end

    data = type(data) == "table" and data or {}
    local detectorId = math.tointeger(tonumber(data.detectorId) or 0) or 0
    local page = math.max(0, math.tointeger(tonumber(data.page) or 0) or 0)
    local size = Config.Limits.logPageSize

    -- One extra row tells whether there is a next page
    local rows = MySQL.query.await(Queries.GetLogs, { detectorId, detectorId, size + 1, page * size }) or {}
    local logs = {}
    for index = 1, math.min(#rows, size) do
        logs[index] = formatLog(rows[index])
    end

    return { success = true, data = { logs = logs, hasMore = #rows > size } }
end)

lib.callback.register("hype-dedector:server:save-settings", function(source, data)
    if not isAdmin(source) then return Fail(locale("error_no_permission")) end
    if type(data) ~= "table" then return Fail(locale("error_invalid_settings")) end

    local cooldownSeconds = math.tointeger(tonumber(data.cooldown))
    local retention = math.tointeger(tonumber(data.logRetentionDays))

    if not cooldownSeconds or cooldownSeconds < 0 or cooldownSeconds > Config.Limits.maxCooldown
        or not retention or retention < 1 or retention > Config.Limits.maxRetentionDays
        or type(data.logAlarms) ~= "boolean" then
        return Fail(locale("error_invalid_settings"))
    end

    -- The webhook is never taken from here: it only lives in config/sv-config.lua on the server
    SaveSetting("cooldown", cooldownSeconds)
    SaveSetting("logRetentionDays", retention)
    SaveSetting("logAlarms", data.logAlarms)
    logAdmin(source, "log_admin_settings")

    return { success = true, data = Settings }
end)

lib.callback.register("hype-dedector:server:get-detector-position", function(source, data)
    if not isAdmin(source) then return Fail(locale("error_no_permission")) end

    local detector = type(data) == "table" and Detectors[tonumber(data.id)]
    if not detector then return Fail(locale("error_not_found")) end

    return { success = true, data = { x = detector.x, y = detector.y, z = detector.z, heading = detector.heading } }
end)
