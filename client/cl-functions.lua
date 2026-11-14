local nuiLoaded = false

--- @return nil
local function checkNui()
    while not nuiLoaded do
        Wait(100)
    end
end

--- @param action string The action to be sent to the NUI.
--- @param payload table? The payload data to be sent with the action.
function NuiMessage(action, payload)
    checkNui()
    SendNUIMessage({
        action = action,
        payload = payload,
    })
end

--- @param message string
--- @param type? string
function Notify(message, type)
    Modules.Client.Notify.SendNotify(locale("notify_title"), message, 5000, type or "success")
end

--- @return nil
local function fetchNui()
    CreateThread(function()
        NuiMessage("setConfig", {
            debug = Config.Debug,
        })
    end)

    while not nuiLoaded do
        if NetworkIsSessionStarted() then
            SendNUIMessage({
                action = "nuiReady",
            })
        end
        Wait(2000)
    end
end

AddEventHandler("onResourceStart", function(resource)
    if resource == GetCurrentResourceName() then
        fetchNui()
    end
end)

RegisterNUICallback("nui-ready", function(data, cb)
    nuiLoaded = true
    Debug("success", "nui is ready")
    cb("ok")
end)

RegisterNUICallback("close", function(data, cb)
    SetNuiFocus(false, false)
    Debug("info", "nui closed")
    cb({})
end)
