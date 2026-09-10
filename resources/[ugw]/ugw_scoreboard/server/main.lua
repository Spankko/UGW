-- Author: Gustavo Spankko
-- Editado: HanzoBR - Incluso ping dinâmico
local QBCore = exports['qb-core']:GetCoreObject()

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `player_dm_stats` (
            `citizenid` VARCHAR(50) NOT NULL,
            `name` VARCHAR(100) NOT NULL,
            `kills` INT(11) NOT NULL DEFAULT 0,
            `deaths` INT(11) NOT NULL DEFAULT 0,
            PRIMARY KEY (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
end)

-- Garante que o player existe na tabela quando entra no servidor
RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid
    local name = Player.PlayerData.charinfo.firstname .." ".. Player.PlayerData.charinfo.lastname

    MySQL.insert('INSERT INTO player_dm_stats (citizenid, name, kills, deaths) VALUES (?, ?, 0, 0) ON DUPLICATE KEY UPDATE name = ?', 
    { citizenid, name, name })
end)

-- Evento para computar Kills e Mortes permanentemente no Banco de Dados
RegisterNetEvent('ugw_scoreboard:server:addKills', function(targetSrc)
    local killerSrc = source
    local Killer = QBCore.Functions.GetPlayer(killerSrc)
    local Target = QBCore.Functions.GetPlayer(targetSrc)

    if Killer then
        MySQL.update('UPDATE player_dm_stats SET kills = kills + 1 WHERE citizenid = ?', { Killer.PlayerData.citizenid })
    end

    if Target then
        MySQL.update('UPDATE player_dm_stats SET deaths = deaths + 1 WHERE citizenid = ?', { Target.PlayerData.citizenid })
    end
end)

-- Callback para puxar os dados do banco e enviar ao Placar (TAB)
QBCore.Functions.CreateCallback('ugw_scoreboard:server:getScoreboardData', function(source, cb)
    local playersList = {}
    local activePlayers = QBCore.Functions.GetPlayers()

    for _, playerId in ipairs(activePlayers) do
        local Player = QBCore.Functions.GetPlayer(playerId)
        if Player then
            local citizenid = Player.PlayerData.citizenid
            
            MySQL.single('SELECT kills, deaths FROM player_dm_stats WHERE citizenid = ?', { citizenid }, function(result)
                local kills = result and result.kills or 0
                local deaths = result and result.deaths or 0
                local kd = string.format("%d/%d", kills, deaths)

                table.insert(playersList, {
                    id = tonumber(playerId),
                    name = Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname,
                    ping = GetPlayerPing(playerId),
                    kills = kills,
                    deaths = deaths,
                    kd = kd,
                    gang = Player.PlayerData.gang.label or "Nenhuma",
					cash = Player.PlayerData.money.cash or 0
                })

                if #playersList == #activePlayers then
                    table.sort(playersList, function(a, b)
                        return a.kills > b.kills
                    end)
                    cb(playersList, #activePlayers)
                end
            end)
        end
    end

    if #activePlayers == 0 then
        cb({}, 0)
    end
end)

-- [CORRIGIDO] Evento rápido para atualizar os pings em tempo real sem tocar no banco de dados
RegisterNetEvent('ugw_scoreboard:server:updatePings')
AddEventHandler('ugw_scoreboard:server:updatePings', function()
    local src = source
    local pingList = {}
    
    -- Usar GetPlayers() nativo garante que pegamos uma lista limpa apenas com os IDs (1, 2, 3...)
    local activePlayers = GetPlayers()

    for _, playerId in ipairs(activePlayers) do
        -- Pega o ping real do ID e salva na lista
        pingList[tostring(playerId)] = GetPlayerPing(playerId)
    end

    -- Envia a lista de pings de volta para o cliente que solicitou
    TriggerClientEvent('ugw_scoreboard:client:receivePings', src, pingList)
end)

-- Comando /stats para ver estatísticas gerais
QBCore.Commands.Add('stats', 'Visualizar suas estatísticas de Mata-Mata', {}, false, function(source, args)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid

    MySQL.single('SELECT kills, deaths FROM player_dm_stats WHERE citizenid = ?', { citizenid }, function(result)
        local kills = result and result.kills or 0
        local deaths = result and result.deaths or 0
        local kd = string.format("%d/%d", kills, deaths)

        TriggerClientEvent('chat:addMessage', src, {
            color = {255, 204, 0},
            multiline = true,
            args = {"UGW-DM", string.format("Suas Estatísticas Gerais -> Kills: %d | Mortes: %d | K/D: %s", kills, deaths, kd)}
        })
    end)
end)

-- Comando /statsid [ID] para ver o de outro player
QBCore.Commands.Add('statsid', 'Visualizar estatísticas de outro jogador', { { name = 'id', help = 'ID do jogador' } }, true, function(source, args)
    local src = source
    local targetId = tonumber(args[1])
    
    if not targetId then
        TriggerClientEvent('QBCore:Notify', src, 'ID inválido.', 'error')
        return
    end

    local Target = QBCore.Functions.GetPlayer(targetId)
    if not Target then
        TriggerClientEvent('QBCore:Notify', src, 'Jogador não encontrado ou offline.', 'error')
        return
    end

    local citizenid = Target.PlayerData.citizenid
    local targetName = Target.PlayerData.charinfo.firstname .. " " .. Target.PlayerData.charinfo.lastname

    MySQL.single('SELECT kills, deaths FROM player_dm_stats WHERE citizenid = ?', { citizenid }, function(result)
        local kills = result and result.kills or 0
        local deaths = result and result.deaths or 0
        local kd = string.format("%d/%d", kills, deaths)

        TriggerClientEvent('chat:addMessage', src, {
            color = {255, 204, 0},
            multiline = true,
            args = {"UGW-DM", string.format("Estatísticas de %s -> Kills: %d | Mortes: %d | K/D: %s", targetName, kills, deaths, kd)}
        })
    end)
end)
