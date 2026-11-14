---@diagnostic disable: duplicate-set-field
if Framework.Name ~= 'qb-core' then return end

local QBCore = exports['qb-core']:GetCoreObject()

---@return number[]
function Framework.Server.GetPlayers()
    local players = {}
    for _, player in pairs(QBCore.Functions.GetQBPlayers()) do
        players[#players + 1] = player.PlayerData.source
    end
    return players
end

function Framework.Server.GetPlayer(playerId)
    return QBCore.Functions.GetPlayer(playerId)
end

---@return boolean
function Framework.Server.IsAdmin(playerId)
    return IsPlayerAceAllowed(tostring(playerId), "command") or false
end

---@return string?
function Framework.Server.GetPlayerIdentifier(playerId)
    local player = Framework.Server.GetPlayer(playerId)
    return player and player.PlayerData.citizenid or nil
end

---@return string?
function Framework.Server.GetCharacterName(playerId)
    local player = Framework.Server.GetPlayer(playerId)
    local charinfo = player and player.PlayerData.charinfo
    if not charinfo or not charinfo.firstname then return nil end
    return ("%s %s"):format(charinfo.firstname, charinfo.lastname or "")
end

---@return JobInfo?
function Framework.Server.GetPlayerJob(playerId)
    local player = Framework.Server.GetPlayer(playerId)
    local job = player and player.PlayerData.job
    if not job then return nil end

    return {
        name = job.name,
        label = job.label,
        grade = { name = job.grade and job.grade.name, level = job.grade and job.grade.level },
        onDuty = job.onduty == true,
    }
end

--- Weapons are inventory items on qb-core, so there is no separate loadout
---@return InventoryItem[]
function Framework.Server.GetLoadout(playerId)
    return {}
end

---@return table?
function Framework.Server.GetPlayerItems(playerId)
    local player = Framework.Server.GetPlayer(playerId)
    return player and player.PlayerData.items or nil
end

RegisterNetEvent("QBCore:Server:OnPlayerLoaded", function()
    TriggerEvent("hype-dedector:server:player-loaded", source)
end)

--- Runs `cb(playerId)` when a player uses `itemName`
---@param itemName string
---@param cb fun(playerId: number)
function Framework.Server.RegisterUsableItem(itemName, cb)
    QBCore.Functions.CreateUseableItem(itemName, function(playerId) cb(playerId) end)
end
