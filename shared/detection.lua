--- Pure detection logic, shared by the client (gate box) and the server (scan, cooldown).
--- No natives in here, so it runs the same on the client and the server.
Detection = {}

---@param list string[]?
---@param value string
---@return boolean
local function contains(list, value)
    for _, entry in ipairs(list or {}) do
        if entry == value then return true end
    end

    return false
end

--- Like `contains`, ignoring case: config entries may be written WEAPON_KNIFE or weapon_knife
---@param list string[]?
---@param value string already lower case
---@return boolean
local function containsName(list, value)
    for _, entry in ipairs(list or {}) do
        if type(entry) == "string" and entry:lower() == value then return true end
    end

    return false
end

--- Lower-cases a Lua pattern's letters but keeps classes like %S or %A as they are
---@param pattern string
---@return string
local function lowerPattern(pattern)
    return (pattern:gsub("(%%?)(%a)", function(escape, letter)
        return escape ~= "" and escape .. letter or letter:lower()
    end))
end

--- Which category an item belongs to. An item listed in a category's `items` wins over any pattern,
--- so weapon_knife stays melee even though "^weapon_" (firearms) matches it too.
---@param itemName string
---@param categories Category[]
---@param nonMetal string[]
---@return string? category value, nil when the item isn't metal
function Detection.CategoryOf(itemName, categories, nonMetal)
    if type(itemName) ~= "string" then return nil end

    local name = itemName:lower()
    if containsName(nonMetal, name) then return nil end

    for _, category in ipairs(categories) do
        if containsName(category.items, name) then return category.value end
    end

    for _, category in ipairs(categories) do
        for _, pattern in ipairs(category.patterns or {}) do
            if name:find(lowerPattern(pattern)) then return category.value end
        end
    end

    return nil
end

--- Whether anything in `items` belongs to one of the `selected` categories
---@param items InventoryItem[]
---@param categories Category[]
---@param nonMetal string[]
---@param selected string[] the detector's categories
---@return boolean
function Detection.HasMetal(items, categories, nonMetal, selected)
    for _, item in ipairs(items or {}) do
        if (tonumber(item.count) or 0) > 0 then
            local category = Detection.CategoryOf(item.name, categories, nonMetal)
            if category and contains(selected, category) then return true end
        end
    end

    return false
end

--- Whether `point` is inside the detector's trigger box. The box is `size` big, centered `offset`
--- (in the prop's own axes: x right, y forward, z up) from the prop, and turned with the prop's heading.
---@param point { x: number, y: number, z: number }
---@param gate { x: number, y: number, z: number, heading: number }
---@param size { x: number, y: number, z: number }
---@param offset { x: number, y: number, z: number }
---@return boolean
function Detection.IsInsideGate(point, gate, size, offset)
    local heading = math.rad(gate.heading or 0.0)
    -- GTA headings: 0 faces +y and they turn counter-clockwise
    local rightX, rightY = math.cos(heading), math.sin(heading)
    local forwardX, forwardY = -math.sin(heading), math.cos(heading)

    local centerX = gate.x + rightX * offset.x + forwardX * offset.y
    local centerY = gate.y + rightY * offset.x + forwardY * offset.y
    local centerZ = gate.z + offset.z

    local dx, dy, dz = point.x - centerX, point.y - centerY, point.z - centerZ
    local localX = dx * rightX + dy * rightY
    local localY = dx * forwardX + dy * forwardY

    return math.abs(localX) <= size.x / 2
        and math.abs(localY) <= size.y / 2
        and math.abs(dz) <= size.z / 2
end

--- Whether the player went through the box since the last check: inside it now, or the straight line from
--- `previous` to `point` passes through it. A sprinting player moves further than the box is deep between checks.
---@param previous { x: number, y: number, z: number }? where the player was last check, nil if unknown
---@param point { x: number, y: number, z: number }
---@param gate { x: number, y: number, z: number, heading: number }
---@param size { x: number, y: number, z: number }
---@param offset { x: number, y: number, z: number }
---@return boolean
function Detection.CrossedGate(previous, point, gate, size, offset)
    if Detection.IsInsideGate(point, gate, size, offset) then return true end
    if not previous then return false end

    local dx, dy, dz = point.x - previous.x, point.y - previous.y, point.z - previous.z
    local distance = math.sqrt(dx * dx + dy * dy + dz * dz)

    -- A teleport or a respawn isn't walking through
    if distance > 10.0 then return false end

    -- Samples every 10cm, finer than the box is deep
    local steps = math.ceil(distance / 0.1)

    for step = 1, steps - 1 do
        local t = step / steps
        local sample = { x = previous.x + dx * t, y = previous.y + dy * t, z = previous.z + dz * t }
        if Detection.IsInsideGate(sample, gate, size, offset) then return true end
    end

    return false
end

---@param job JobInfo?
---@param jobs string[]
---@param requireDuty boolean
---@return boolean
function Detection.IsJobIgnored(job, jobs, requireDuty)
    if type(job) ~= "table" or not contains(jobs, job.name) then return false end
    if requireDuty and job.onDuty ~= true then return false end

    return true
end

--- Who may use the hand detector. Same rule as IsJobIgnored, except an empty job list lets everyone
---@param job JobInfo?
---@param jobs string[]
---@param requireDuty boolean
---@return boolean
function Detection.IsJobAllowed(job, jobs, requireDuty)
    if not jobs or #jobs == 0 then return true end

    return Detection.IsJobIgnored(job, jobs, requireDuty)
end

--- Where the searcher stands around the target during a hand search, each facing the target.
--- Angles are relative to the target's front and turn like GTA headings (90 = the target's left side).
---@param target { x: number, y: number, z: number }
---@param targetHeading number
---@param radius number metres from the target
---@param angles number[]
---@return { x: number, y: number, z: number, heading: number }[]
function Detection.SearchStops(target, targetHeading, radius, angles)
    local stops = {}

    for index, angle in ipairs(angles) do
        local direction = math.rad(targetHeading + angle)

        stops[index] = {
            x = target.x - math.sin(direction) * radius,
            y = target.y + math.cos(direction) * radius,
            z = target.z,
            heading = (targetHeading + angle + 180.0) % 360.0,
        }
    end

    return stops
end

--- Remembers when each key last passed. Keys are "<source>:<detectorId>" so a player's entries can be cleared
--- by prefix when they leave.
---@return { check: fun(self, key: string, now: integer, ms: integer): boolean, clear: fun(self, prefix: string) }
function Detection.NewCooldown()
    local last = {}

    return {
        --- True, and starts a new cooldown, when `key` hasn't passed in the last `ms`
        check = function(_, key, now, ms)
            local previous = last[key]
            if previous and now - previous < ms then return false end

            last[key] = now
            return true
        end,

        clear = function(_, prefix)
            for key in pairs(last) do
                if key:sub(1, #prefix) == prefix then last[key] = nil end
            end
        end,
    }
end
