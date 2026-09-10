local QBCore = exports['qb-core']:GetCoreObject()

-- Dispara a tela de regras assim que o jogador carrega no servidor
RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
    local src = source
    SetTimeout(2000, function()
        TriggerClientEvent('ugw_intro:client:openIntro', src)
    end)
end)

-- Evento chamado quando o jogador clica em "Concordo" na NUI da intro
RegisterNetEvent('ugw_intro:server:spawnPlayer', function()
    local src = source
    TriggerClientEvent('ugw_respawn:client:firstLoginSpawn', src)
end)