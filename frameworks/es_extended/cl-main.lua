---@diagnostic disable: duplicate-set-field
if Framework.Name ~= 'es_extended' then return end

local ESX = exports.es_extended:getSharedObject()

---@return boolean
function Framework.Client.IsLoaded()
    return ESX.IsPlayerLoaded() or false
end

RegisterNetEvent('esx:playerLoaded', function()
    Wait(1500)
    TriggerEvent('hype-dedector:client:player-loaded')
end)

--- The local player's job, for the hand detector's target option. The server checks it again
---@return { name: string, onDuty: boolean }?
function Framework.Client.GetJob()
    local job = ESX.GetPlayerData().job
    return job and { name = job.name, onDuty = job.onDuty ~= false } or nil
end
