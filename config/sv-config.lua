-- Server only. This file is never sent to players (it is not in the `files` list of fxmanifest.lua),
-- so secrets like the webhook can't be read from the game client. Don't move these to config.lua.
return {
    -- Discord webhook for alarms and admin actions. Leave empty to turn webhook logs off.
    -- Whether alarms are logged at all is set in the admin menu (Settings > Log alarms).
    Webhook = "",
}
