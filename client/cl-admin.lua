RegisterNetEvent("hype-dedector:client:open-admin-menu", function()
    Debug("info", "opening the admin menu")
    NuiMessage("setView", {
        view = "admin",
    })
    SetNuiFocus(true, true)
end)

RegisterNuiCallback("admin:get-data", function(data, cb)
    cb(lib.callback.await("hype-dedector:server:get-admin-data", false))
end)

-- Where the admin stands, on the ground, so the detector's box lines up with the floor
RegisterNuiCallback("admin:get-position", function(data, cb)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local streetHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local found, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 0.5, false)

    cb({
        success = true,
        data = {
            label = GetStreetNameFromHashKey(streetHash),
            x = coords.x,
            y = coords.y,
            z = found and groundZ or coords.z - 1.0,
            heading = GetEntityHeading(ped),
        },
    })
end)

RegisterNuiCallback("admin:create-detector", function(data, cb)
    cb(lib.callback.await("hype-dedector:server:create-detector", false, data))
end)

RegisterNuiCallback("admin:update-detector", function(data, cb)
    cb(lib.callback.await("hype-dedector:server:update-detector", false, data))
end)

RegisterNuiCallback("admin:delete-detector", function(data, cb)
    cb(lib.callback.await("hype-dedector:server:delete-detector", false, data))
end)

RegisterNuiCallback("admin:set-status", function(data, cb)
    cb(lib.callback.await("hype-dedector:server:set-status", false, data))
end)

RegisterNuiCallback("admin:get-logs", function(data, cb)
    cb(lib.callback.await("hype-dedector:server:get-logs", false, data))
end)

RegisterNuiCallback("admin:save-settings", function(data, cb)
    cb(lib.callback.await("hype-dedector:server:save-settings", false, data))
end)

-- Puts the admin 1.5m in front of the detector, facing it
RegisterNuiCallback("admin:teleport", function(data, cb)
    local response = lib.callback.await("hype-dedector:server:get-detector-position", false, data)

    if not response or not response.success then
        cb(response)
        return
    end

    local position = response.data
    -- The detector is stored at floor height; the ped's origin is about a metre above its feet
    position.z = position.z + 1.0
    local heading = math.rad(position.heading)
    local x = position.x - math.sin(heading) * 1.5
    local y = position.y + math.cos(heading) * 1.5
    local ped = PlayerPedId()

    -- Held in place until the ground loads, so a long teleport doesn't drop through the map
    FreezeEntityPosition(ped, true)
    RequestCollisionAtCoord(x, y, position.z)
    SetEntityCoords(ped, x, y, position.z, false, false, false, false)
    SetEntityHeading(ped, (position.heading + 180.0) % 360.0)

    local timeout = GetGameTimer() + 3000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < timeout do
        Wait(0)
    end

    FreezeEntityPosition(ped, false)
    cb({ success = true })
end)
