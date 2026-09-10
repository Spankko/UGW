local QBCore = exports['qb-core']:GetCoreObject()

QBCore.Functions.CreateCallback('ugw_scoreboard:getPlayers', function(source, cb)
    local players = {}
    local qbPlayers = QBCore.Functions.GetQBPlayers()
    local totalPlayers = 0
    local processedPlayers = 0

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
            local gangName = Player.PlayerData.gang and Player.PlayerData.gang.name or "Nenhuma"

            exports.oxmysql:execute('SELECT kills, deaths FROM ugw_player_stats WHERE user_id = ?', { citizenId }, function(result)
                local kills = (result[1] and result[1].kills) or 0
                local deaths = (result[1] and result[1].deaths) or 0
                local kd = deaths > 0 and string.format("%.2f", kills / deaths) or string.format("%.2f", kills)

                table.insert(players, {
                    id = src,
                    name = Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname,
                    gang = string.upper(gangName),
                    kills = kills,
                    deaths = deaths,
                    kd = kd,
                    ping = ping
                })

                processedPlayers = processedPlayers + 1
                if processedPlayers == totalPlayers then
                    cb(players)
                end
            end)
        end
    end
end)