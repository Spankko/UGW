local QBCore = exports['qb-core']:GetCoreObject()

-- Configurações de Recompensa
local BASE_REWARD = 1000000 -- Valor base a cada 1 segundo

RegisterNetEvent('ugw_legionearn:server:giveReward', function(timeInZone)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if Player and type(timeInZone) == "number" then
        -- Cálculo do Multiplicador baseado no tempo em segundos
        local multiplier = 1.0

        if timeInZone >= 60 then
            multiplier = 5.0 -- Acima de 1 minuto em movimento: 5x o valor
        elseif timeInZone >= 30 then
            multiplier = 2.0 -- Entre 30s e 59s: 2x o valor
        elseif timeInZone >= 10 then
            multiplier = 1.5 -- Entre 10s e 29s: 1.5x o valor
        end

        local finalReward = math.floor(BASE_REWARD * multiplier)
        
        -- Entrega o dinheiro na mão (cash)
        Player.Functions.AddMoney('cash', finalReward, 'legion-square-progressive-reward')

        -- Responde ao client para atualizar o texto na tela
        TriggerClientEvent('ugw_legionearn:client:updateDisplay', src, finalReward, multiplier)
    end
end)