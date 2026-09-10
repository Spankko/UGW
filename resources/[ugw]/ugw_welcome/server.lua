-- Author: Gustavo Spankko
local QBCore = exports['qb-core']:GetCoreObject()

RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
    local src = source
    
    -- Pequeno delay de 2 segundos para o chat carregar após o spawn
    SetTimeout(2000, function()
        TriggerClientEvent('chat:addMessage', src, {
            color = {255, 204, 0},
            args = {"UGW - DM", "===================================================="}
        })
        TriggerClientEvent('chat:addMessage', src, {
            color = {255, 204, 0},
            args = {"UGW - DM", "              UGW 1.0 FiveM - 2026"}
        })
        TriggerClientEvent('chat:addMessage', src, {
            color = {255, 255, 0},
            args = {"UGW - DM", " » Idealização Spankko, HanzoBR, ErmacÇ e Truta."}
        })
        TriggerClientEvent('chat:addMessage', src, {
            color = {0, 153, 255},
            args = {"UGW - DM", " » Créditos e Agradecimentos a Equipe UGW FiveM."}
        })
        TriggerClientEvent('chat:addMessage', src, {
            color = {204, 0, 0},
            args = {"UGW - DM", " » Créditos e Agradecimentos a Equipe GtO Games."}
        })
        TriggerClientEvent('chat:addMessage', src, {
            color = {255, 255, 255},
            args = {"UGW - DM", " » Para Mais Informações, Digite o Comando /ajuda"}
        })
        TriggerClientEvent('chat:addMessage', src, {
            color = {255, 204, 0},
            args = {"UGW - DM", "===================================================="}
        })
        TriggerClientEvent('chat:addMessage', src, {
            color = {0, 204, 102},
            args = {"UGW - DM", "Sejam todos bem vindos ao CLASSIC GANGWAR!"}
        })
    end)
end)