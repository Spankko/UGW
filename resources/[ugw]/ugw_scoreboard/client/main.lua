-- Author: Gustavo Spankko
-- Editado: HanzoBR - Incluso ping dinâmico
local QBCore = exports['qb-core']:GetCoreObject()
local isOpen = false

-- Tecla tab para abrir/fechar (Registrado no FiveM)
RegisterKeyMapping('ugw_scoreboard_toggle', 'Abrir/Fechar Placar (TAB)', 'keyboard', 'TAB')

-- [CORRIGIDO] Escuta o servidor enviando os pings e repassa direto para a sua interface NUI
RegisterNetEvent('ugw_scoreboard:client:receivePings')
AddEventHandler('ugw_scoreboard:client:receivePings', function(pingList)
    if isOpen then
        -- Esse print vai aparecer no seu F8 para provar que o código está recebendo o ping!
        print("[UGW-SCOREBOARD] Pings recebidos com sucesso do servidor.") 
        
        SendNUIMessage({
            type = "updatePings",
            pings = pingList
        })
    end
end)

RegisterCommand('ugw_scoreboard_toggle', function()
    if not isOpen then
        QBCore.Functions.TriggerCallback('ugw_scoreboard:server:getScoreboardData', function(players, total)
            isOpen = true
            SendNUIMessage({
                type = "open",
                players = players,
                total = total
            })

            -- [NOVO] Loop que roda enquanto o placar estiver aberto pedindo atualização do ping
            CreateThread(function()
                while isOpen do
                    TriggerServerEvent('ugw_scoreboard:server:updatePings')
                    Wait(2000) -- Atualiza a cada 2 segundos. Se quiser mais rápido, mude para 1000 (1 segundo).
                end
            end)
        end)
    else
        isOpen = false
        SendNUIMessage({
            type = "close"
        })
    end
end, false)
