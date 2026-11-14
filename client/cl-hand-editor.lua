--- /dedectorprop (admins only, see server/sv-admin.lua): places the hand detector prop in game.
--- Move and turn it with the keys shown on screen, then press ENTER to print the values for the config in F8.
local hand = Config.HandDetector
if not hand.enabled then return end

-- Control ids: https://docs.fivem.net/docs/game-references/controls/
local keys <const> = {
    left = 174, right = 175, up = 172, down = 173,  -- arrows: x / y
    raise = 10, lower = 11,                           -- PAGE UP / PAGE DOWN: z
    mode = 38,                                        -- E: position / rotation
    fine = 21,                                        -- SHIFT: small steps
    save = 191,                                       -- ENTER
    cancel = 194,                                     -- BACKSPACE
}

local editing = false

--- @param value number
--- @return string
local function fmt(value)
    local text = ("%.3f"):format(value):gsub("%.?0+$", "")
    return (text:gsub("^%-0$", "0"))
end

--- @param pos vector3
--- @param rot vector3
--- @param bone integer
--- @return string
local function configText(pos, rot, bone)
    return ("bone = %d,\npos = vec3(%s, %s, %s),\nrot = vec3(%s, %s, %s),"):format(
        bone, fmt(pos.x), fmt(pos.y), fmt(pos.z), fmt(rot.x), fmt(rot.y), fmt(rot.z)
    )
end

RegisterNetEvent("hype-dedector:client:prop-editor", function(requestedBone)
    if editing then return end

    local ped = PlayerPedId()
    -- /dedectorprop 57005 tries another bone, e.g. the right hand
    local bone = tonumber(requestedBone) or hand.prop.bone
    local pos, rot = hand.prop.pos, hand.prop.rot
    local rotating = false

    if not pcall(lib.requestModel, hand.prop.model, 5000) then
        print(("^1[hype-dedector] could not load %s^0"):format(hand.prop.model))
        return
    end

    local coords = GetEntityCoords(ped)
    local prop = CreateObject(joaat(hand.prop.model), coords.x, coords.y, coords.z, false, false, false)
    SetEntityCollision(prop, false, false)

    if pcall(lib.requestAnimDict, hand.anim.dict, 3000) then
        TaskPlayAnim(ped, hand.anim.dict, hand.anim.clip, 3.0, 3.0, -1, hand.anim.flag or 49, 0.0, false, false, false)
    end

    editing = true
    local shownText

    while editing do
        -- Every key used here is disabled below, so they're read with IsDisabledControl*
        local fine = IsDisabledControlPressed(0, keys.fine)
        local step = fine and 0.002 or 0.01
        local angle = fine and 0.5 or 3.0
        local dx, dy, dz = 0.0, 0.0, 0.0

        for _, control in pairs(keys) do DisableControlAction(0, control, true) end

        if IsDisabledControlPressed(0, keys.left) then dx = -1 end
        if IsDisabledControlPressed(0, keys.right) then dx = 1 end
        if IsDisabledControlPressed(0, keys.up) then dy = 1 end
        if IsDisabledControlPressed(0, keys.down) then dy = -1 end
        if IsDisabledControlPressed(0, keys.raise) then dz = 1 end
        if IsDisabledControlPressed(0, keys.lower) then dz = -1 end

        if rotating then
            rot = rot + vec3(dx, dy, dz) * angle
        else
            pos = pos + vec3(dx, dy, dz) * step
        end

        if IsDisabledControlJustPressed(0, keys.mode) then rotating = not rotating end

        AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, bone), pos.x, pos.y, pos.z,
            rot.x, rot.y, rot.z,
            true, true, false, true, 1, true)

        local text = ("[%s]  \n%s  \nArrows: x / y · PgUp/PgDn: z · SHIFT: fine  \nE: %s · ENTER: print · BACKSPACE: quit"):format(
            rotating and "ROTATION" or "POSITION",
            configText(pos, rot, bone):gsub("\n", "  \n"),
            rotating and "position" or "rotation"
        )

        -- Sending the text UI every frame is costly, only send changes
        if text ~= shownText then
            lib.showTextUI(text)
            shownText = text
        end

        if IsDisabledControlJustPressed(0, keys.save) then
            print("^2[hype-dedector] Paste into Config.HandDetector.prop:^0\n" .. configText(pos, rot, bone))
            lib.notify({ title = "hype-dedector", description = "Values printed to F8.", type = "success" })
        end

        if IsDisabledControlJustPressed(0, keys.cancel) then editing = false end

        Wait(0)
    end

    lib.hideTextUI()
    DeleteEntity(prop)
    ClearPedSecondaryTask(ped)
    ClearPedTasks(ped)
end)
