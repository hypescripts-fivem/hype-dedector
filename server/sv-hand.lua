local hand = Config.HandDetector
if not hand.enabled then return end

---@class HandSearch
---@field target number
---@field startedAt integer GetGameTimer()

--- Searcher -> their search in progress
--- @type table<number, HandSearch>
local searches = {}
--- Target -> who is searching them
--- @type table<number, number>
local searchedBy = {}

local cooldown = Detection.NewCooldown()

--- @param playerId number
--- @param target number
--- @return number? distance nil when either player is gone
local function distanceBetween(playerId, target)
    local ped, targetPed = GetPlayerPed(playerId), GetPlayerPed(target)
    if ped == 0 or targetPed == 0 then return nil end

    return #(GetEntityCoords(ped) - GetEntityCoords(targetPed))
end

--- Job, duty and the item, checked again at the end so dropping the item mid-search doesn't help
--- @param playerId number
--- @return string? errorKey
local function checkSearcher(playerId)
    if not Detection.IsJobAllowed(Framework.Server.GetPlayerJob(playerId), hand.jobs, hand.requireDuty) then
        return "hand_error_job"
    end

    if hand.requireItem then
        local items = Modules.Server.Inventory.GetItems(playerId)
        if Modules.Server.Inventory.CountItem(items, hand.item) < 1 then return "hand_error_item" end
    end

    return nil
end

--- Ends a search and lets the target lower their hands
--- @param playerId number the searcher
local function endSearch(playerId)
    local search = searches[playerId]
    if not search then return end

    searches[playerId] = nil
    if searchedBy[search.target] == playerId then searchedBy[search.target] = nil end

    TriggerClientEvent("hype-dedector:client:hand-searched", search.target, false)
end

--- The beep, for everyone near the target
--- @param target number
--- @param result FeedbackResult
local function sendSound(target, result)
    local targetPed = GetPlayerPed(target)
    if targetPed == 0 then return end

    local coords = GetEntityCoords(targetPed)

    for _, id in ipairs(GetPlayers()) do
        local ped = GetPlayerPed(id)

        if ped ~= 0 and #(GetEntityCoords(ped) - coords) <= Config.Feedback.radius then
            TriggerClientEvent("hype-dedector:client:hand-sound", id, coords, result)
        end
    end
end

lib.callback.register("hype-dedector:server:hand-start", function(source, target)
    target = tonumber(target)

    if not target or target == source or GetPlayerPed(target) == 0 then
        return Fail(locale("hand_error_no_target"))
    end

    if searches[source] then return Fail(locale("hand_error_busy")) end
    if searchedBy[target] then return Fail(locale("hand_error_target_busy")) end
    if GetVehiclePedIsIn(GetPlayerPed(target), false) ~= 0 then return Fail(locale("hand_error_target_vehicle")) end

    local errorKey = checkSearcher(source)
    if errorKey then return Fail(locale(errorKey)) end

    local distance = distanceBetween(source, target)
    -- A little slack for the time between the client's check and this one
    if not distance or distance > hand.distance + 1.0 then return Fail(locale("hand_error_too_far")) end

    if not cooldown:check(source .. ":", GetGameTimer(), hand.cooldown * 1000) then
        return Fail(locale("hand_error_cooldown"))
    end

    searches[source] = { target = target, startedAt = GetGameTimer() }
    searchedBy[target] = source
    TriggerClientEvent("hype-dedector:client:hand-searched", target, true)

    Debug("info", "player %s started a hand search on %s", source, target)
    return { success = true, data = { duration = hand.duration } }
end)

lib.callback.register("hype-dedector:server:hand-finish", function(source)
    local search = searches[source]
    if not search then return Fail(locale("hand_error_no_search")) end

    local target = search.target
    -- The progress bar runs on the client, so the server makes sure the time really passed
    local tooEarly = GetGameTimer() - search.startedAt < hand.duration * 0.9
    endSearch(source)

    if tooEarly then return Fail(locale("hand_error_no_search")) end

    local distance = distanceBetween(source, target)
    if not distance or distance > hand.distance + 1.0 then return Fail(locale("hand_error_too_far")) end

    local errorKey = checkSearcher(source)
    if errorKey then return Fail(locale(errorKey)) end

    local metal = Detection.HasMetal(
        Modules.Server.Inventory.GetItems(target),
        Config.Categories,
        Config.NonMetal,
        hand.categories
    )
    local result = metal and "alarm" or "clear"

    sendSound(target, result)
    Debug("info", "hand search by %s on %s: %s", source, target, result)

    -- Only "metal" or "clean", never what it was
    return { success = true, data = { metal = metal } }
end)

lib.callback.register("hype-dedector:server:hand-cancel", function(source)
    endSearch(source)
    return { success = true }
end)

AddEventHandler("playerDropped", function()
    local playerId = source

    endSearch(playerId)
    cooldown:clear(playerId .. ":")

    -- The player being searched left: the searcher's finish call will fail on distance
    local searcher = searchedBy[playerId]
    if searcher then
        searchedBy[playerId] = nil
        searches[searcher] = nil
        TriggerClientEvent("hype-dedector:client:hand-cancel", searcher)
    end
end)

if hand.usableItem then
    Framework.Server.RegisterUsableItem(hand.item, function(playerId)
        TriggerClientEvent("hype-dedector:client:hand-use", playerId)
    end)
end
