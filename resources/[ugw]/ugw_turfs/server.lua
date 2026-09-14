local QBCore = exports['qb-core']:GetCoreObject()

local TurfData = {}
local DynamicGangColors = {}
local AvailableBlipColors = { 83, 25, 46, 38, 1, 5, 2, 3, 4, 6, 7, 8, 9, 11, 15, 17, 18, 21, 26, 27 }

local function GetGangColor(gangName)
    if not gangName or gangName == "none" then return 0 end
    
    if DynamicGangColors[gangName] then
        return DynamicGangColors[gangName]
    end

    if QBCore.Shared and QBCore.Shared.Gangs and QBCore.Shared.Gangs[gangName] then
        local qbGang = QBCore.Shared.Gangs[gangName]
        if qbGang.color then
            DynamicGangColors[gangName] = qbGang.color
            return DynamicGangColors[gangName]
        end
    end

    local hash = 0
    for i = 1, #gangName do
        hash = hash + string.byte(gangName, i)
    end
    local colorIndex = (hash % #AvailableBlipColors) + 1
    DynamicGangColors[gangName] = AvailableBlipColors[colorIndex]

    return DynamicGangColors[gangName]
end

local function LoadTurfsFromDB()
    for id, _ in pairs(Config.Turfs) do
        TurfData[id] = { owner = nil, points = {} }
    end

    MySQL.query('SELECT * FROM gang_turfs', {}, function(result)
        if result and #result > 0 then
            for _, row in ipairs(result) do
                local turfId = tonumber(row.turf_id)
                if Config.Turfs[turfId] then
                    local owner = row.owner_gang
                    Config.Turfs[turfId].owner = owner
                    TurfData[turfId].owner = owner
                    if owner then GetGangColor(owner) end
                end
            end
        end
        print('^2[UGW Turfs] Territórios e Gangues Dinâmicas sincronizados com sucesso!^7')
        TriggerClientEvent('ugw_turfs:client:syncTurfs', -1, Config.Turfs, DynamicGangColors)
    end)
end

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    LoadTurfsFromDB()
end)

RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
    local src = source
    TriggerClientEvent('ugw_turfs:client:syncTurfs', src, Config.Turfs, DynamicGangColors)
end)

-- Permite ao cliente solicitar a lista a qualquer momento (evita tela em branco no restart)
RegisterNetEvent('ugw_turfs:server:requestSync', function()
    local src = source
    TriggerClientEvent('ugw_turfs:client:syncTurfs', src, Config.Turfs, DynamicGangColors)
end)

RegisterNetEvent('ugw_turfs:server:enterTurf', function(turfId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not Config.Turfs[turfId] then return end

    local turf = Config.Turfs[turfId]
    local owner = turf.owner or "Nenhum"
    local gangName = Player.PlayerData.gang and Player.PlayerData.gang.name or "none"
    local currentPoints = (TurfData[turfId] and TurfData[turfId].points[gangName]) or 0

    TriggerClientEvent('ugw_turfs:client:updateHud', src, turf.name, owner, currentPoints)
end)

RegisterNetEvent('ugw_turfs:server:onPlayerKill', function(turfId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not turfId or not Config.Turfs[turfId] then return end

    local gangName = Player.PlayerData.gang and Player.PlayerData.gang.name or "none"
    if not gangName or gangName == "none" or gangName == "unemployed" then return end

    TurfData[turfId].points[gangName] = (TurfData[turfId].points[gangName] or 0) + 15
    local currentPoints = TurfData[turfId].points[gangName]

    TriggerClientEvent('ugw_turfs:client:updateHud', src, Config.Turfs[turfId].name, Config.Turfs[turfId].owner or "Nenhum", currentPoints)

    if currentPoints >= 100 and TurfData[turfId].owner ~= gangName then
        TurfData[turfId].owner = gangName
        Config.Turfs[turfId].owner = gangName
        GetGangColor(gangName)

        MySQL.insert('INSERT INTO gang_turfs (turf_id, owner_gang) VALUES (?, ?) ON DUPLICATE KEY UPDATE owner_gang = ?', {
            turfId, gangName, gangName
        })

        TriggerClientEvent('QBCore:Notify', -1, 'A gangue ' .. string.upper(gangName) .. ' dominou o território: ' .. Config.Turfs[turfId].name, 'success')
        TriggerClientEvent('ugw_turfs:client:syncTurfs', -1, Config.Turfs, DynamicGangColors)
    end
end)

-- Comando Administrativo para definir o dono de um território
QBCore.Commands.Add('setturf', 'Definir o dono de um território (Apenas Admin)', {
    { name = 'id', help = 'ID do Território (1 a 72)' },
    { name = 'gangue', help = 'Nome da gangue (ex: ballas, vagos) ou none para limpar' }
}, true, function(source, args)
    local turfId = tonumber(args[1])
    local gangName = tolower and tolower(args[2]) or string.lower(args[2] or "")

    if not turfId or not Config.Turfs[turfId] then
        TriggerClientEvent('QBCore:Notify', source, 'ID de território inválido!', 'error')
        return
    end

    if gangName == "" then
        TriggerClientEvent('QBCore:Notify', source, 'Especifique o nome da gangue!', 'error')
        return
    end

    -- Se for "none" ou "nenhum", remove o dono
    if gangName == "none" or gangName == "nenhum" then
        TurfData[turfId].owner = nil
        Config.Turfs[turfId].owner = nil
        
        MySQL.query('DELETE FROM gang_turfs WHERE turf_id = ?', { turfId })
        TriggerClientEvent('QBCore:Notify', source, 'Território ' .. turfId .. ' resetado para Neutro.', 'primary')
    else
        TurfData[turfId].owner = gangName
        Config.Turfs[turfId].owner = gangName
        GetGangColor(gangName) -- Garante que a gangue ganhe uma cor registrada

        MySQL.insert('INSERT INTO gang_turfs (turf_id, owner_gang) VALUES (?, ?) ON DUPLICATE KEY UPDATE owner_gang = ?', {
            turfId, gangName, gangName
        })
        TriggerClientEvent('QBCore:Notify', source, 'Território ' .. turfId .. ' definido para: ' .. string.upper(gangName), 'success')
    end

    -- Sincroniza as mudanças com todos os jogadores conectados
    TriggerClientEvent('ugw_turfs:client:syncTurfs', -1, Config.Turfs, DynamicGangColors)
end, 'admin')