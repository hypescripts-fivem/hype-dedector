return {
    Debug = false,     -- prints debug messages and draws each detector's trigger box
    AutoRunSQL = true, -- automatically runs INSTALL/insert-me.sql on resource start

    Commands = {
        AdminMenu = {
            name = "dedector",
            help = "Open the metal detector admin menu",
        },
        -- Admins: place the hand detector prop in your hand and print pos / rot for HandDetector.prop
        PropEditor = {
            name = "dedectorprop",
            help = "Tune the hand detector prop in your hand",
        },
    },

    Detector = {
        model = "ch_prop_ch_metal_detector_01a",
        spawnDistance = 60.0,  -- detector props are spawned within this range
        checkDistance = 15.0,  -- the client only checks detectors closer than this
        maxDistance = 4.0,     -- the server ignores a pass reported further than this from the detector
        ignoreVehicles = true, -- driving through a detector doesn't trigger it
        -- The invisible box that counts as "walking through", centered `offset` above the prop and turned with it.
        -- size.x is the width of the opening, size.y how deep it is, size.z how tall. Set Debug = true to see it
        gate = {
            size = vec3(0.9, 0.6, 2.2),
            offset = vec3(0.0, 0.0, 1.1),
        },
    },

    -- What everyone near the detector sees and hears after someone walks through
    Feedback = {
        radius = 25.0,    -- players within this range get the light and the sound
        duration = 2500,  -- ms the light stays on
        light = {
            offset = vec3(0.0, 0.0, 2.3), -- from the prop, where the light shines from
            range = 2.5,
            intensity = 6.0,
            alarm = { 255, 30, 30 },
            clear = { 40, 255, 80 },
        },
        -- Game sounds: https://wiki.rage.mp/index.php?title=Sounds
        sounds = {
            enabled = true,
            alarm = { name = "Beep_Red", set = "DLC_HEIST_HACKING_SNAKE_SOUNDS" },
            clear = { name = "Beep_Green", set = "DLC_HEIST_HACKING_SNAKE_SOUNDS" },
        },
    },

    -- What counts as metal. Each detector picks which categories it reacts to in the admin menu.
    -- An item listed in `items` belongs to that category, even if another category's pattern matches it too
    -- (weapon_knife is melee, not firearms). `patterns` are Lua patterns checked only for items no category lists.
    -- Names are compared in lower case, so WEAPON_PISTOL and weapon_pistol are the same.
    -- The categories are never shown to anyone: alerts, logs and the admin menu only say "metal detected".
    Categories = {
        {
            value = "firearms",
            label = "Firearms",
            items = {},
            patterns = { "^weapon_" },
        },
        {
            value = "melee",
            label = "Knives & melee",
            items = {
                "weapon_knife", "weapon_switchblade", "weapon_dagger", "weapon_machete", "weapon_hatchet",
                "weapon_battleaxe", "weapon_knuckle", "weapon_crowbar", "weapon_hammer", "weapon_wrench",
                "weapon_bottle", "weapon_stone_hatchet",
            },
        },
        {
            value = "explosives",
            label = "Explosives",
            items = {
                "weapon_grenade", "weapon_stickybomb", "weapon_pipebomb", "weapon_proxmine", "weapon_molotov",
                "thermite", "c4",
            },
        },
        {
            value = "ammo",
            label = "Ammunition",
            items = {},
            patterns = { "^ammo" },
        },
    },

    -- Never detected, even when a pattern above matches them
    NonMetal = {
        "weapon_bat", "weapon_poolcue", "weapon_flashlight", "weapon_petrolcan", "weapon_fireextinguisher",
        "weapon_snowball", "weapon_ball", "weapon_flare", "weapon_nightstick",
    },

    -- Categories ticked on a new detector in the admin menu
    DefaultCategories = { "firearms", "melee", "explosives" },

    -- These jobs walk through without an alarm (the detector still shows green)
    IgnoreJobs = {
        jobs = { "police", "security" },
        requireDuty = true, -- only while on duty
    },

    --- Server side. Return false to let this player through without a scan (the detector shows green).
    --- Use it for exceptions of your own, e.g. a weapon license.
    ---@param source number
    ---@param detector { id: number, name: string, area: string, coords: vector3 }
    ---@return boolean
    ShouldScan = function(source, detector)
        return true
    end,

    Alert = {
        -- Who gets the alert from the default `server` function below
        jobs = { "police", "security" },
        requireDuty = true,
        blip = { enabled = true, sprite = 161, color = 1, scale = 1.2, time = 60 }, -- time in seconds

        --- Runs on the server every time a detector finds metal.
        --- `data` never says what was found, only where. Replace the body to use your own dispatch.
        ---@param data { source: number, detector: { id: number, name: string, area: string, coords: vector3 }, time: number }
        server = function(data)
            -- Sends `client` below to every player in `jobs`
            SendAlertToJobs(data)

            -- ps-dispatch
            -- exports["ps-dispatch"]:CustomAlert({
            --     coords = data.detector.coords,
            --     message = "Metal detector alarm",
            --     description = data.detector.name,
            --     dispatchCode = "10-32",
            --     code = "metal-detector",
            --     icon = "fas fa-door-open",
            --     priority = 2,
            --     jobs = { "leo" },
            -- })

            -- cd_dispatch
            -- TriggerClientEvent("cd_dispatch:AddNotification", -1, {
            --     job_table = { "police" },
            --     coords = data.detector.coords,
            --     title = "10-32 - Metal detector",
            --     message = ("Alarm at %s (%s)"):format(data.detector.name, data.detector.area),
            --     flash = 0,
            --     unique_id = tostring(math.random(0000000, 9999999)),
            --     sound = 1,
            --     blip = { sprite = 161, scale = 1.2, colour = 1, flashes = false, text = "Metal detector", time = 5, radius = 0 },
            -- })

            -- qs-dispatch (call from the client of a player in the job, or use their server export)
            -- core_dispatch
            -- exports["core_dispatch"]:addCall("10-32", "Metal detector alarm", {
            --     { icon = "fa-door-open", info = data.detector.name },
            -- }, { data.detector.coords.x, data.detector.coords.y, data.detector.coords.z }, "police", 5000, 161, 1)
        end,

        --- Runs on the client of every player the server sends the alert to (see SendAlertToJobs).
        ---@param data { detector: { id: number, name: string, area: string, coords: vector3 }, time: number }
        client = function(data)
            Modules.Client.Notify.SendNotify(
                locale("alert_title"),
                locale("alert_message", data.detector.name, data.detector.area),
                8000,
                "error"
            )

            local blip = Config.Alert.blip
            if not blip.enabled then return end

            local coords = data.detector.coords
            local handle = AddBlipForCoord(coords.x, coords.y, coords.z)
            SetBlipSprite(handle, blip.sprite)
            SetBlipColour(handle, blip.color)
            SetBlipScale(handle, blip.scale)
            SetBlipFlashes(handle, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentSubstringPlayerName(locale("blip_label"))
            EndTextCommandSetBlipName(handle)

            SetTimeout(blip.time * 1000, function()
                RemoveBlip(handle)
            end)
        end,
    },

    -- Handheld detector: police / security search a player by hand. The result only says "metal" or "clean"
    HandDetector = {
        enabled = true,

        -- How a search starts. Both can be on
        target = true,       -- "Search with hand detector" on players, through ox_target or qb-target
        usableItem = false,  -- using the item searches the closest player

        item = "hand_detector",
        requireItem = true,  -- the searcher must carry `item` (also with target)

        -- Who can search. Leave the list empty to let everyone
        jobs = { "police", "security" },
        requireDuty = true,

        -- What the hand detector reacts to (Config.Categories values)
        categories = { "firearms", "melee", "explosives", "ammo" },

        duration = 12000, -- ms the search takes, the walk around the player included
        distance = 2.0,   -- how close the searcher must be to start, and stay during the search
        cooldown = 5,     -- seconds between two searches by the same player

        label = "Search with hand detector",
        icon = "fas fa-magnifying-glass",

        -- The searcher. The torch anims below hold the torch in the LEFT hand (bone 18905), so the prop goes there.
        -- Using a right-handed anim? Switch to bone 57005.
        -- Tune pos / rot in game: run /dedectorprop as an admin, then paste what it prints in F8 here
        prop = {
            model = "hype_hand_dedector",
            bone = 18905,
            pos = vec3(0.11, -0.03, 0.06),
            rot = vec3(-129.0, -30.0, 0.0),
        },
        -- Held the whole search, upper body only, so the searcher can walk with it
        anim = { dict = "amb@world_human_security_shine_torch@male@base", clip = "base", flag = 49 },

        -- The searcher walks around the player and plays a stop anim at every stop. The prop stays fixed in the hand.
        -- `duration` is shared evenly between the stops
        choreography = {
            radius = 0.85,                -- metres from the player the searcher stands
            stops = { 0, 90, 180, 270 },  -- angles around the player: 0 in front, 90 their left, 180 behind, 270 their right
            walkSpeed = 1.0,              -- 1.0 walk, 2.0 run
            -- Played at the stops in turn, upper body. Leave empty to keep `anim`. A clip that fails to load is skipped
            stopAnims = {
                { dict = "amb@world_human_security_shine_torch@male@idle_a", clip = "idle_a" },
                { dict = "amb@world_human_security_shine_torch@male@idle_a", clip = "idle_b" },
                { dict = "amb@world_human_security_shine_torch@male@idle_a", clip = "idle_c" },
                { dict = "amb@world_human_security_shine_torch@male@idle_b", clip = "idle_d" },
            },
        },

        -- The player being searched, held until the search ends. Set to false to leave them alone
        targetAnim = { dict = "missminuteman_1ig_2", clip = "handsup_base", flag = 49 },

        -- Heard by everyone within Feedback.radius when the search ends
        sounds = {
            enabled = true,
            alarm = { name = "Beep_Red", set = "DLC_HEIST_HACKING_SNAKE_SOUNDS" },
            clear = { name = "Beep_Green", set = "DLC_HEIST_HACKING_SNAKE_SOUNDS" },
        },
    },

    -- Fallback for hype_dedector_settings. The values saved in the admin menu take priority
    DefaultSettings = {
        cooldown = 10,         -- seconds before the same player can set off the same detector again
        logRetentionDays = 30, -- alarm logs older than this are deleted
        logAlarms = true,      -- keep alarm logs (admin menu and webhook). The webhook itself is in config/sv-config.lua
    },

    Limits = {
        nameLength = 64,
        detectorSpacing = 1.5, -- metres, two detectors can't be placed closer than this
        recentLogs = 10,       -- overview page
        logPageSize = 50,      -- alarm logs page
        statsDays = 7,         -- overview chart
        maxCooldown = 600,
        maxRetentionDays = 365,
    },
}
