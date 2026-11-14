--- Adds an option to every player for the first running target resource.
--- Supports: ox_target, qb-target (qtarget-style). Add yours here.

---@class PlayerTargetOption
---@field name string
---@field label string
---@field icon string
---@field distance number
---@field canInteract fun(entity: number): boolean
---@field onSelect fun(entity: number)

---@param option PlayerTargetOption
---@return boolean added false when no supported target resource is running
function Modules.Client.Target.AddPlayerOption(option)
    if GetResourceState("ox_target") == "started" then
        exports.ox_target:addGlobalPlayer({
            {
                name = option.name,
                label = option.label,
                icon = option.icon,
                distance = option.distance,
                canInteract = function(entity) return option.canInteract(entity) end,
                onSelect = function(data) option.onSelect(data.entity) end,
            },
        })
        return true
    elseif GetResourceState("qb-target") == "started" then
        exports["qb-target"]:AddGlobalPlayer({
            options = {
                {
                    label = option.label,
                    icon = option.icon,
                    canInteract = function(entity) return option.canInteract(entity) end,
                    action = function(entity) option.onSelect(entity) end,
                },
            },
            distance = option.distance,
        })
        return true
    end

    return false
end

---@param option PlayerTargetOption
function Modules.Client.Target.RemovePlayerOption(option)
    if GetResourceState("ox_target") == "started" then
        exports.ox_target:removeGlobalPlayer(option.name)
    elseif GetResourceState("qb-target") == "started" then
        exports["qb-target"]:RemoveGlobalPlayer(option.label)
    end
end
