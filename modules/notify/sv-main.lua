--- Sends a notification to a player from the server, through the client's notify module.
---@param playerId number Pass -1 to notify everyone.
---@param title string
---@param message string
---@param time number|nil Defaults to 5000.
---@param type string|nil "success", "error", "info" or "warning". Defaults to "success".
function Modules.Server.Notify.SendNotify(playerId, title, message, time, type)
    TriggerClientEvent("hype-dedector:client:send-notify", playerId, title, message, time, type)
end
