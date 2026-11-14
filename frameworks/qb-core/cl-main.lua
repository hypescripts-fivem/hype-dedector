---@diagnostic disable: duplicate-set-field
if Framework.Name ~= 'qb-core' then return end

---@return boolean
function Framework.Client.IsLoaded()
    return LocalPlayer.state.isLoggedIn or false
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    Wait(1500)
    TriggerEvent('hype-dedector:client:player-loaded')
end)

local QBCore = exports['qb-core']:GetCoreObject()

--- The local player's job, for the hand detector's target option. The server checks it again
---@return { name: string, onDuty: boolean }?
function Framework.Client.GetJob()
    local job = QBCore.Functions.GetPlayerData().job
    return job and { name = job.name, onDuty = job.onduty == true } or nil
end
