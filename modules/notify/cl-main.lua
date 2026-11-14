--- Shows a notification to the local player with the first running notification resource.
--- Supports: okokNotify, ps-ui, ox_lib (always there, it's a dependency). Add yours above ox_lib.
---@param title string
---@param message string
---@param time number|nil Milliseconds. Defaults to 5000.
---@param type string|nil "success", "error", "info" or "warning". Defaults to "success".
function Modules.Client.Notify.SendNotify(title, message, time, type)
    type = type or "success"
    time = time or 5000

    if GetResourceState("okokNotify") == "started" then
        exports["okokNotify"]:Alert(title, message, time, type)
    elseif GetResourceState("ps-ui") == "started" then
        exports["ps-ui"]:Notify(message, type, time)
    else
        lib.notify({
            title = title,
            description = message,
            type = type,
            duration = time,
        })
    end
end

RegisterNetEvent("hype-dedector:client:send-notify", function(...)
    Modules.Client.Notify.SendNotify(...)
end)
