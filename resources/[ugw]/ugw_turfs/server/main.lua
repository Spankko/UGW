local QBCore = exports['qb-core']:GetCoreObject()

local TurfData = {}
local GangColors = {}

-- Inicialização e carregamento dos dados do MySQL
AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    if Config and Config.Turfs then
        for id, _ in pairs(Config.Turfs) do
            TurfData[id] = { points = {}, owner = nil }
        end
    end

    local result = MySQL.query.await('SELECT * FROM gang_turfs', {})
    if result then
        for _, v in ipairs(result) do
            local tid = tonumber(v.turf_id)
            if Config.Turfs[tid] then
                Config.Turfs[tid].owner = v.owner_gang
                TurfData[tid].owner = v.owner_gang
            end
        end
    end

    local colorsResult = MySQL.query.await('SELECT gang_name, color_id FROM gang_colors', {})
    if colorsResult then
        for _, v in ipairs(colorsResult) do
            GangColors[v.gang_name] = tonumber(v.color_id)
        end
    end

    Wait(1000)
    TriggerClientEvent('ugw_turfs:client:syncTurfs', -1, Config.Turfs, GangColors)
end)

RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
    local src = source
    TriggerClientEvent('ugw_turfs:client:syncTurfs', src, Config.Turfs, GangColors)
end)

RegisterNetEvent('ugw_turfs:server:enterTurf', function(turfId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not Config.Turfs[turfId] then return end

    local gang = Player.PlayerData.gang.name
    if gang and gang ~= "none" then
        TriggerClientEvent('QBCore:Notify', src, 'Entrou na área: ' .. Config.Turfs[turfId].name, 'primary')
    end
end)

RegisterNetEvent('ugw_turfs:server:leaveTurf', function(turfId)
    local src = source
    if not Config.Turfs[turfId] then return end
    TriggerClientEvent('QBCore:Notify', src, 'Saiu de: ' .. Config.Turfs[turfId].name, 'error')
end)

-- Pontos por permanência (a cada 1 minuto)
CreateThread(function()
    while true do
        Wait(60000)

        if Config and Config.Turfs then
            for turfId, turfInfo in pairs(Config.Turfs) do
                local playersInZone = {}

                for _, playerId in ipairs(QBCore.Functions.GetPlayers()) do
                    local Player = QBCore.Functions.GetPlayer(playerId)
                    if Player then
                        local ped = GetPlayerPed(playerId)
                        local coords = GetEntityCoords(ped)
                        
                        local halfW = turfInfo.width / 2.0
                        local halfH = turfInfo.height / 2.0
                        
                        if (coords.x >= (turfInfo.coords.x - halfW) and coords.x <= (turfInfo.coords.x + halfW)) and
                           (coords.y >= (turfInfo.coords.y - halfH) and coords.y <= (turfInfo.coords.y + halfH)) then
                            
                            local gang = Player.PlayerData.gang.name
                            if gang and gang ~= "none" then
                                playersInZone[gang] = (playersInZone[gang] or 0) + 1
                            end
                        end
                    end
                end

                for gangName, count in pairs(playersInZone) do
                    TurfData[turfId].points[gangName] = (TurfData[turfId].points[gangName] or 0) + (count * 10)

                    if TurfData[turfId].points[gangName] >= 100 and TurfData[turfId].owner ~= gangName then
                        TurfData[turfId].owner = gangName
                        Config.Turfs[turfId].owner = gangName

                        MySQL.insert('INSERT INTO gang_turfs (turf_id, owner_gang) VALUES (?, ?) ON DUPLICATE KEY UPDATE owner_gang = ?', {
                            turfId, gangName, gangName
                        })

                        TriggerClientEvent('QBCore:Notify', -1, 'A gangue ' .. string.upper(gangName) .. ' dominou o território: ' .. turfInfo.name, 'success')
                        TriggerClientEvent('ugw_turfs:client:syncTurfs', -1, Config.Turfs, GangColors)
                    end
                end
            end
        end
    end
end)

-- Bônus de pontos por Kill
RegisterNetEvent('ugw_turfs:server:onPlayerKill', function(killerSrc, turfId)
    local Killer = QBCore.Functions.GetPlayer(killerSrc)
    if not Killer or not Config.Turfs[turfId] then return end

    local killerGang = Killer.PlayerData.gang.name
    if killerGang and killerGang ~= "none" then
        TurfData[turfId].points[killerGang] = (TurfData[turfId].points[killerGang] or 0) + 25
        
        TriggerClientEvent('QBCore:Notify', killerSrc, '+25 pontos para a gangue ' .. string.upper(killerGang) .. ' (Inimigo abatido)!', 'success')

        if TurfData[turfId].points[killerGang] >= 100 and TurfData[turfId].owner ~= killerGang then
            TurfData[turfId].owner = killerGang
            Config.Turfs[turfId].owner = killerGang

            MySQL.insert('INSERT INTO gang_turfs (turf_id, owner_gang) VALUES (?, ?) ON DUPLICATE KEY UPDATE owner_gang = ?', {
                turfId, killerGang, killerGang
            })

            TriggerClientEvent('QBCore:Notify', -1, 'A gangue ' .. string.upper(killerGang) .. ' tomou o território: ' .. Config.Turfs[turfId].name, 'success')
            TriggerClientEvent('ugw_turfs:client:syncTurfs', -1, Config.Turfs, GangColors)
        end
    end
end)

-- Recompensas periódicas por hora
CreateThread(function()
    while true do
        Wait(3600000)

        if Config and Config.Turfs then
            for id, turf in pairs(Config.Turfs) do
                if turf.owner then
                    local rewardAmount = 5000
                    MySQL.update('UPDATE gang_funds SET money = money + ? WHERE gang_name = ?', { rewardAmount, turf.owner })
                    print('^2[UGW_TURFS]^7 Recompensa de R$ ' .. rewardAmount .. ' adicionada ao cofre da gangue ' .. turf.owner .. ' pelo território ' .. turf.name)
                end
            end
        end
    end
end)