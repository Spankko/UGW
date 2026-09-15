local QBCore = exports['qb-core']:GetCoreObject()

QBCore.Functions.CreateCallback('ugw_scoreboard:getPlayers', function(source, cb)
    local players = {}
    local qbPlayers = QBCore.Functions.GetQBPlayers()
    local totalPlayers = 0
    local processedPlayers = 0

    -- Conta o total de jogadores online na sessão
    for _, Player in pairs(qbPlayers) do
        if Player then
            totalPlayers = totalPlayers + 1
        end
    end

    if totalPlayers == 0 then
        cb({})
        return
    end

    for _, Player in pairs(qbPlayers) do
        if Player then
            local src = Player.PlayerData.source
            local citizenId = Player.PlayerData.citizenid
            local ping = GetPlayerPing(src)
            
            -- Lendo a coluna customizada do ugw_gangues injetada na sessão do jogador
            local gangName = Player.PlayerData.ugw_gang or "Nenhuma"

            -- CORREÇÃO DE ESTABILIDADE: Puxando dados de forma síncrona (Sync) para garantir que
            -- a tabela monte na ordem correta sem dar gargalo ou travar o callback sob estresse.
            local result = exports.oxmysql:fetchAllSync('SELECT kills, deaths FROM ugw_player_stats WHERE user_id = ?', { citizenId })
            
            local kills = (result and result[1] and result[1].kills) or 0
            local deaths = (result and result[1] and result[1].deaths) or 0
            local kd = string.format("%d/%d", kills, deaths)

            table.insert(players, {
                id = src,
                name = Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname,
                gang = string.upper(gangName), 
                kills = kills,
                deaths = deaths,
                kd = kd,
                ping = ping,
                cash = Player.PlayerData.money.cash or 0
            })

            processedPlayers = processedPlayers + 1
            if processedPlayers == totalPlayers then
                cb(players)
            end
        end
    end
end)
