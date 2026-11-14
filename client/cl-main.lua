---@class ClientDetector
---@field data { id: integer, name: string, x: number, y: number, z: number, heading: number }
---@field point table lib.points
---@field entity integer?
---@field inside boolean player within spawnDistance
---@field inGate boolean player inside the trigger box last check
---@field lastCoords vector3? player position last check, nil while out of checkDistance

--- @type table<integer, ClientDetector>
local detectors = {}

local gate = Config.Detector.gate

--- @param detector ClientDetector
local function removeEntity(detector)
    if detector.entity and DoesEntityExist(detector.entity) then
        DeleteEntity(detector.entity)
    end

    detector.entity = nil
end

--- @param detectorId integer
local function removeDetector(detectorId)
    local detector = detectors[detectorId]
    if not detector then return end

    detector.point:remove()
    removeEntity(detector)
    detectors[detectorId] = nil
end

--- @param detector ClientDetector
local function spawnProp(detector)
    local data = detector.data
    local model = joaat(Config.Detector.model)

    if not lib.requestModel(model, 10000) then
        Debug("error", "could not load %s for detector %s", Config.Detector.model, data.id)
        return
    end

    -- The detector was moved, removed or left behind while the model loaded
    if detectors[data.id] ~= detector or not detector.inside or detector.entity then
        SetModelAsNoLongerNeeded(model)
        return
    end

    local entity = CreateObjectNoOffset(model, data.x, data.y, data.z, false, false, false)
    SetEntityHeading(entity, data.heading)
    FreezeEntityPosition(entity, true)
    SetModelAsNoLongerNeeded(model)

    detector.entity = entity
    Debug("info", "spawned the prop of detector %s", data.id)
end

--- @param data { id: integer, name: string, x: number, y: number, z: number, heading: number }
local function addDetector(data)
    local detector = { data = data, inside = false, inGate = false }

    detector.point = lib.points.new({
        coords = vec3(data.x, data.y, data.z),
        distance = Config.Detector.spawnDistance,
        onEnter = function()
            detector.inside = true
            spawnProp(detector)
        end,
        onExit = function()
            detector.inside = false
            detector.inGate = false
            removeEntity(detector)
        end,
    })

    detectors[data.id] = detector
end

--- Replaces the detector list. Unchanged detectors keep their prop
--- @param list { id: integer, name: string, x: number, y: number, z: number, heading: number }[]
local function setDetectors(list)
    local incoming = {}
    for _, data in ipairs(list or {}) do
        incoming[data.id] = data
    end

    for id, detector in pairs(detectors) do
        local data = incoming[id]
        local same = data and data.x == detector.data.x and data.y == detector.data.y
            and data.z == detector.data.z and data.heading == detector.data.heading

        if same then
            detector.data = data
            incoming[id] = nil
        else
            removeDetector(id)
        end
    end

    for _, data in pairs(incoming) do
        addDetector(data)
    end

    Debug("info", "now tracking %d detector(s)", TableSize(detectors))
end

local function loadDetectors()
    setDetectors(lib.callback.await("hype-dedector:server:get-detectors", false))
end

RegisterNetEvent("hype-dedector:client:set-detectors", setDetectors)

--- The 8 corners of a detector's trigger box, for the debug outline
--- @param data { x: number, y: number, z: number, heading: number }
local function gateCorners(data)
    local heading = math.rad(data.heading)
    local right = vec3(math.cos(heading), math.sin(heading), 0.0)
    local forward = vec3(-math.sin(heading), math.cos(heading), 0.0)
    local center = vec3(data.x, data.y, data.z) + right * gate.offset.x + forward * gate.offset.y + vec3(0.0, 0.0, gate.offset.z)
    local corners = {}

    for _, sz in ipairs({ -1, 1 }) do
        for _, sy in ipairs({ -1, 1 }) do
            for _, sx in ipairs({ -1, 1 }) do
                corners[#corners + 1] = center + right * (sx * gate.size.x / 2) + forward * (sy * gate.size.y / 2)
                    + vec3(0.0, 0.0, sz * gate.size.z / 2)
            end
        end
    end

    return corners
end

local debugEdges <const> = { { 1, 2 }, { 3, 4 }, { 1, 3 }, { 2, 4 }, { 5, 6 }, { 7, 8 }, { 5, 7 }, { 6, 8 }, { 1, 5 }, { 2, 6 }, { 3, 7 }, { 4, 8 } }

local function drawDebugBox(data, inGate)
    local corners = gateCorners(data)
    local r, g = inGate and 255 or 80, inGate and 80 or 200

    for _, edge in ipairs(debugEdges) do
        local a, b = corners[edge[1]], corners[edge[2]]
        DrawLine(a.x, a.y, a.z, b.x, b.y, b.z, r, g, 80, 255)
    end
end

-- Watches the trigger boxes of nearby detectors and tells the server when the player walks into one
CreateThread(function()
    while true do
        local sleep = 1000
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local inVehicle = Config.Detector.ignoreVehicles and IsPedInAnyVehicle(ped, false)

        for id, detector in pairs(detectors) do
            local data = detector.data

            if detector.inside and #(coords - vec3(data.x, data.y, data.z)) <= Config.Detector.checkDistance then
                sleep = Config.Debug and 0 or 100

                -- The line from the last check counts too: sprinting covers more than the box is deep between checks
                local crossed = not inVehicle and Detection.CrossedGate(detector.lastCoords, coords, data, gate.size, gate.offset)
                local inGate = not inVehicle and Detection.IsInsideGate(coords, data, gate.size, gate.offset)

                -- Only going in counts, standing in the box doesn't repeat
                if crossed and not detector.inGate then
                    Debug("info", "walked through detector %s", id)
                    TriggerServerEvent("hype-dedector:server:passed", id)
                end

                detector.inGate = inGate
                detector.lastCoords = coords

                if Config.Debug then drawDebugBox(data, inGate) end
            else
                -- Coming back into range later must not draw a line from where the player left
                detector.lastCoords = nil
            end
        end

        Wait(sleep)
    end
end)

--- Light (and sound) on top of the detector for Config.Feedback.duration
RegisterNetEvent("hype-dedector:client:feedback", function(detectorId, result)
    local detector = detectors[detectorId]
    if not detector then return end

    local data = detector.data
    local feedback = Config.Feedback
    local color = result == "alarm" and feedback.light.alarm or feedback.light.clear
    local heading = math.rad(data.heading)
    local offset = feedback.light.offset
    local x = data.x + math.cos(heading) * offset.x - math.sin(heading) * offset.y
    local y = data.y + math.sin(heading) * offset.x + math.cos(heading) * offset.y
    local z = data.z + offset.z

    if feedback.sounds.enabled then
        local sound = result == "alarm" and feedback.sounds.alarm or feedback.sounds.clear
        PlaySoundFromCoord(-1, sound.name, x, y, z, sound.set, false, 15, false)
    end

    CreateThread(function()
        local endsAt = GetGameTimer() + feedback.duration

        while GetGameTimer() < endsAt do
            DrawLightWithRange(x, y, z, color[1], color[2], color[3], feedback.light.range, feedback.light.intensity)
            Wait(0)
        end
    end)
end)

RegisterNetEvent("hype-dedector:client:alert", function(data)
    local ok, err = pcall(Config.Alert.client, data)

    if not ok then
        print(("^1[hype-dedector] Config.Alert.client failed: %s^0"):format(err))
    end
end)

AddEventHandler("onResourceStart", function(resource)
    if resource ~= GetCurrentResourceName() then return end
    loadDetectors()
end)

AddEventHandler("hype-dedector:client:player-loaded", loadDetectors)

AddEventHandler("onResourceStop", function(resource)
    if resource ~= GetCurrentResourceName() then return end

    for _, detector in pairs(detectors) do
        removeEntity(detector)
    end
end)
