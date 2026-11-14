---@diagnostic disable: duplicate-set-field
if Framework.Name ~= 'es_extended' then return end

local ESX = exports.es_extended:getSharedObject()

---@return number[]
function Framework.Server.GetPlayers()
    local players = {}
    for _, xPlayer in pairs(ESX.GetExtendedPlayers()) do
        players[#players + 1] = xPlayer.source
    end
    return players
end

function Framework.Server.GetPlayer(playerId)
    return ESX.GetPlayerFromId(playerId)
end

---@return boolean
function Framework.Server.IsAdmin(playerId)
    return IsPlayerAceAllowed(tostring(playerId), "command") or false
end

---@return string?
function Framework.Server.GetPlayerIdentifier(playerId)
    local xPlayer = Framework.Server.GetPlayer(playerId)
    return xPlayer and xPlayer.getIdentifier() or nil
end

---@return string?
function Framework.Server.GetCharacterName(playerId)
    local xPlayer = Framework.Server.GetPlayer(playerId)
    return xPlayer and xPlayer.getName() or nil
end

---@return JobInfo?
function Framework.Server.GetPlayerJob(playerId)
    local xPlayer = Framework.Server.GetPlayer(playerId)
    local job = xPlayer and xPlayer.job
    if not job then return nil end

    return {
        name = job.name,
        label = job.label,
        grade = { name = job.grade_name, level = job.grade },
        -- Older ESX versions have no duty system, everyone counts as on duty there
        onDuty = job.onDuty ~= false,
    }
end

--- Weapons outside the inventory (ESX without ox_inventory)
---@return InventoryItem[]
function Framework.Server.GetLoadout(playerId)
    local xPlayer = Framework.Server.GetPlayer(playerId)
    if not xPlayer or not xPlayer.getLoadout then return {} end

    local weapons = {}
    for _, weapon in ipairs(xPlayer.getLoadout() or {}) do
        weapons[#weapons + 1] = { name = weapon.name, count = 1 }
    end
    return weapons
end

---@return table?
function Framework.Server.GetPlayerItems(playerId)
    local xPlayer = Framework.Server.GetPlayer(playerId)
    return xPlayer and xPlayer.getInventory and xPlayer.getInventory() or nil
end

AddEventHandler("esx:playerLoaded", function(playerId)
    TriggerEvent("hype-dedector:server:player-loaded", playerId)
end)

--- Runs `cb(playerId)` when a player uses `itemName`. Works with ox_inventory too, ESX passes it on
---@param itemName string
---@param cb fun(playerId: number)
function Framework.Server.RegisterUsableItem(itemName, cb)
    ESX.RegisterUsableItem(itemName, function(playerId) cb(playerId) end)
end
