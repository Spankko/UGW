-- Author: Gustavo Spankko
local QBCore = exports['qb-core']:GetCoreObject()

RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
    local src = source
    
    SetTimeout(2000, function()
        TriggerClientEvent('ugw_welcome:showWelcomeMessages', src)
    end)
end)