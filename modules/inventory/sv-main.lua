--- Reads a player's whole inventory so the detector can look for metal in it.
--- Add your own inventory to GetRawItems if it isn't listed; anything returning items with a `name` and
--- a `count` / `amount` works.

--- Turns any inventory's item list (array or slot-keyed table) into { name, count }[]
---@param raw table?
---@return InventoryItem[]
function Modules.Server.Inventory.Normalize(raw)
    local items = {}
    if type(raw) ~= "table" then return items end

    for _, item in pairs(raw) do
        if type(item) == "table" and type(item.name) == "string" then
            items[#items + 1] = {
                name = item.name,
                count = tonumber(item.count or item.amount) or 1,
            }
        end
    end

    return items
end

--- How many of `itemName` are in a normalized item list, ignoring case (ox_inventory upper-cases weapons)
---@param items InventoryItem[]
---@param itemName string
---@return number
function Modules.Server.Inventory.CountItem(items, itemName)
    local wanted, total = itemName:lower(), 0

    for _, item in ipairs(items) do
        if item.name:lower() == wanted then total = total + item.count end
    end

    return total
end

---@param playerId number
---@return table?
local function getRawItems(playerId)
    if GetResourceState('ox_inventory') == 'started' then
        return exports.ox_inventory:GetInventoryItems(playerId)
    elseif GetResourceState('qs-inventory') == 'started' then
        return exports['qs-inventory']:GetInventory(playerId)
    elseif GetResourceState('codem-inventory') == 'started' then
        return exports['codem-inventory']:GetInventory(nil, playerId)
    elseif GetResourceState('tgiann-inventory') == 'started' then
        return exports['tgiann-inventory']:GetPlayerItems(playerId)
    end

    -- qb-inventory, ps-inventory, lj-inventory, jpr-inventory, origen_inventory and core_inventory keep
    -- the framework's item list in sync (PlayerData.items on qb/qbx, getInventory() on ESX)
    if Framework.Server.GetPlayerItems then
        return Framework.Server.GetPlayerItems(playerId)
    end

    return nil
end

--- Everything the player carries, ESX loadout weapons included. Never throws: a broken or missing
--- inventory counts as empty, so the detector shows green instead of erroring
---@param playerId number
---@return InventoryItem[]
function Modules.Server.Inventory.GetItems(playerId)
    local success, raw = pcall(getRawItems, playerId)

    if not success then
        Debug("error", "couldn't read the inventory of %s: %s", playerId, raw)
        return {}
    end

    local items = Modules.Server.Inventory.Normalize(raw)

    if Framework.Server.GetLoadout then
        local loaded, loadout = pcall(Framework.Server.GetLoadout, playerId)
        if loaded then
            for _, weapon in ipairs(loadout or {}) do items[#items + 1] = weapon end
        end
    end

    return items
end
