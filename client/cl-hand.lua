local hand = Config.HandDetector
if not hand.enabled then return end

local searching = false
-- Cleans up the running search's prop and anims; nil when none is running
local stopPerformance

local targetOption = {
    name = "hype-dedector:hand-search",
    label = hand.label,
    icon = hand.icon,
    distance = hand.distance,
}

--- Only hides the option from players who can't use it; the server checks job and item again
--- @return boolean
local function canSearch()
    if searching or IsPedInAnyVehicle(PlayerPedId(), false) or IsEntityDead(PlayerPedId()) then return false end
    if not Framework.Client.GetJob then return true end

    return Detection.IsJobAllowed(Framework.Client.GetJob(), hand.jobs, hand.requireDuty)
end

--- Cancels the progress bar once the target walks off, dies or the searcher dies
--- @param targetPed number
local function watchDistance(targetPed)
    CreateThread(function()
        while searching do
            local ped = PlayerPedId()
            local tooFar = not DoesEntityExist(targetPed)
                or #(GetEntityCoords(ped) - GetEntityCoords(targetPed)) > hand.distance + 0.5

            if tooFar or IsEntityDead(ped) or IsEntityDead(targetPed) then
                lib.cancelProgress()
                return
            end

            Wait(250)
        end
    end)
end

local choreography = hand.choreography

--- Plays an upper-body anim. A dict that doesn't exist is skipped instead of breaking the search
--- @param ped number
--- @param anim { dict: string, clip: string, flag?: integer }
--- @return boolean played
local function playAnim(ped, anim)
    local loaded = pcall(lib.requestAnimDict, anim.dict, 3000)
    if not loaded then
        Debug("warning", "hand detector anim %s / %s could not be loaded", anim.dict, anim.clip)
        return false
    end

    TaskPlayAnim(ped, anim.dict, anim.clip, 3.0, 3.0, -1, anim.flag or 49, 0.0, false, false, false)
    RemoveAnimDict(anim.dict)
    return true
end

--- The networked detector prop, attached to the hand for the whole search, so everyone around sees it
--- @param ped number
--- @return number? entity
local function createProp(ped)
    local loaded = pcall(lib.requestModel, hand.prop.model, 5000)
    if not loaded then
        Debug("error", "could not load %s", hand.prop.model)
        return nil
    end

    local coords = GetEntityCoords(ped)
    local model = joaat(hand.prop.model)
    local entity = CreateObject(model, coords.x, coords.y, coords.z + 0.2, true, true, false)
    SetModelAsNoLongerNeeded(model)
    SetEntityCollision(entity, false, false)

    local pos, rot = hand.prop.pos, hand.prop.rot
    AttachEntityToEntity(entity, ped, GetPedBoneIndex(ped, hand.prop.bone), pos.x, pos.y, pos.z, rot.x, rot.y, rot.z,
        true, true, false, true, 1, true)

    return entity
end

--- Walks around the target stop by stop, playing the stop anims, until the search ends.
--- Runs next to the progress bar, which owns the timing and the cancel button
--- @param ped number
--- @param targetPed number
--- @param duration integer ms
--- @return fun() stop cleans up the prop and the anims
local function perform(ped, targetPed, duration)
    local state = { active = true, prop = createProp(ped) }

    playAnim(ped, hand.anim)

    -- The walk around the target
    CreateThread(function()
        local stops = choreography.stops
        local perStop = math.floor(duration / math.max(#stops, 1))

        for index, angle in ipairs(stops) do
            if not state.active then return end

            local stopEndsAt = GetGameTimer() + perStop
            -- From where the target is now, in case they shuffled
            local stop = Detection.SearchStops(GetEntityCoords(targetPed), GetEntityHeading(targetPed), choreography.radius, { angle })[1]

            TaskGoStraightToCoord(ped, stop.x, stop.y, stop.z, choreography.walkSpeed, math.floor(perStop * 0.6), stop.heading, 0.05)

            local walkEndsAt = GetGameTimer() + math.floor(perStop * 0.6)
            while state.active and GetGameTimer() < walkEndsAt
                and #(GetEntityCoords(ped).xy - vec2(stop.x, stop.y)) > 0.2 do
                Wait(50)
            end

            if not state.active then return end

            TaskTurnPedToFaceEntity(ped, targetPed, 600)

            local anim = choreography.stopAnims[(index - 1) % math.max(#choreography.stopAnims, 1) + 1]
            if not anim or not playAnim(ped, anim) then playAnim(ped, hand.anim) end

            while state.active and GetGameTimer() < stopEndsAt do
                Wait(50)
            end

            -- Back to holding the detector while walking to the next stop
            if anim then playAnim(ped, hand.anim) end
        end
    end)

    return function()
        state.active = false
        ClearPedTasks(ped)
        ClearPedSecondaryTask(ped)

        if state.prop and DoesEntityExist(state.prop) then
            DetachEntity(state.prop, true, false)
            DeleteEntity(state.prop)
        end
    end
end

--- @param targetPed number
local function search(targetPed)
    if searching then return end

    local playerIndex = NetworkGetPlayerIndexFromPed(targetPed)
    if playerIndex == -1 then return end

    local response = lib.callback.await("hype-dedector:server:hand-start", false, GetPlayerServerId(playerIndex))
    if not response or not response.success then
        Notify(response and response.error or locale("hand_error_no_target"), "error")
        return
    end

    searching = true
    watchDistance(targetPed)

    local ped = PlayerPedId()
    stopPerformance = perform(ped, targetPed, response.data.duration)

    -- Movement keys are off so the player doesn't fight the walk; the tasks still move the ped
    local completed = lib.progressBar({
        duration = response.data.duration,
        label = locale("hand_progress"),
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true, sprint = true },
    })

    stopPerformance()
    stopPerformance = nil
    searching = false

    if not completed then
        lib.callback.await("hype-dedector:server:hand-cancel", false)
        Notify(locale("hand_cancelled"), "error")
        return
    end

    local result = lib.callback.await("hype-dedector:server:hand-finish", false)
    if not result or not result.success then
        Notify(result and result.error or locale("hand_error_no_search"), "error")
        return
    end

    if result.data.metal then
        Notify(locale("hand_result_metal"), "error")
    else
        Notify(locale("hand_result_clear"), "success")
    end
end

-- The player being searched holds their hands up until it ends
RegisterNetEvent("hype-dedector:client:hand-searched", function(active)
    local anim = hand.targetAnim
    if not anim then return end

    local ped = PlayerPedId()

    if not active then
        StopAnimTask(ped, anim.dict, anim.clip, 1.0)
        return
    end

    if not lib.requestAnimDict(anim.dict, 5000) then return end

    TaskPlayAnim(ped, anim.dict, anim.clip, 3.0, 3.0, -1, anim.flag, 0.0, false, false, false)
    RemoveAnimDict(anim.dict)
end)

RegisterNetEvent("hype-dedector:client:hand-sound", function(coords, result)
    if not hand.sounds.enabled then return end

    local sound = result == "alarm" and hand.sounds.alarm or hand.sounds.clear
    PlaySoundFromCoord(-1, sound.name, coords.x, coords.y, coords.z, sound.set, false, 10, false)
end)

-- The player being searched left the server
RegisterNetEvent("hype-dedector:client:hand-cancel", function()
    if searching then lib.cancelProgress() end
end)

-- Using the item searches the closest player
RegisterNetEvent("hype-dedector:client:hand-use", function()
    if not canSearch() then return end

    local _, targetPed = lib.getClosestPlayer(GetEntityCoords(PlayerPedId()), hand.distance, false)
    if not targetPed then
        Notify(locale("hand_error_no_player_nearby"), "error")
        return
    end

    search(targetPed)
end)

AddEventHandler("onClientResourceStart", function(resource)
    if resource ~= GetCurrentResourceName() or not hand.target then return end

    targetOption.canInteract = function(entity)
        return canSearch() and not IsEntityDead(entity)
    end
    targetOption.onSelect = search

    if not Modules.Client.Target.AddPlayerOption(targetOption) then
        print("^3[hype-dedector] HandDetector.target is on but neither ox_target nor qb-target is running.^0")
    end
end)

AddEventHandler("onResourceStop", function(resource)
    if resource ~= GetCurrentResourceName() then return end

    if hand.target then Modules.Client.Target.RemovePlayerOption(targetOption) end
    if searching then lib.cancelProgress() end
    -- The networked prop would stay in the world after a restart
    if stopPerformance then stopPerformance() end
end)
