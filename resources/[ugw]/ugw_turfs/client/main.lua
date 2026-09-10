local QBCore = exports['qb-core']:GetCoreObject()
local currentTurf = nil
local TurfBlips = {}
local DynamicGangColors = {}

local DEFAULT_NEUTRAL_COLOR = 1 -- Vermelho/Sem dono

-- Função para verificar se a coordenada está dentro do quadrado
local function IsInSquareArea(pCoords, turfCoords, width, height)
    local halfW = width / 2.0
    local halfH = height / 2.0
    
    return (pCoords.x >= (turfCoords.x - halfW) and pCoords.x <= (turfCoords.x + halfW)) and
           (pCoords.y >= (turfCoords.y - halfH) and pCoords.y <= (turfCoords.y + halfH))
end

-- Atualiza ou cria os blips quadrados no mapa
local function UpdateTurfBlips(turfs)
    for id, turf in pairs(turfs) do
        if not TurfBlips[id] then
            local blip = AddBlipForArea(turf.coords.x, turf.coords.y, turf.coords.z, turf.width, turf.height)
            SetBlipRotation(blip, 0)
            SetBlipAlpha(blip, 128)
            TurfBlips[id] = blip
        end

        local color = DEFAULT_NEUTRAL_COLOR
        if turf.owner and DynamicGangColors[turf.owner] then
            color = DynamicGangColors[turf.owner]
        elseif turf.owner then
            color = 5 -- Azul padrão se a gangue não tiver cor cadastrada
        end

        SetBlipColour(TurfBlips[id], color)
    end
end

-- Sincronização vinda do servidor
RegisterNetEvent('ugw_turf:client:syncTurfs', function(turfsData, gangColorsData)
    Config.Turfs = turfsData
    DynamicGangColors = gangColorsData or {}
    UpdateTurfBlips(turfsData)
end)

-- Thread para checar entrada e saída dos territórios
CreateThread(function()
    while true do
        local sleep = 1000
        local pCoords = GetEntityCoords(PlayerPedId())
        local inside = false

        for id, turf in pairs(Config.Turfs) do
            if IsInSquareArea(pCoords, turf.coords, turf.width, turf.height) then
                inside = true
                if currentTurf ~= id then
                    currentTurf = id
                    TriggerServerEvent('ugw_turf:server:enterTurf', id)
                end
                break
            end
        end

        if not inside and currentTurf then
            TriggerServerEvent('ugw_turf:server:leaveTurf', currentTurf)
            currentTurf = nil
        end

        Wait(sleep)
    end
end)

-- Detecção de abate/kill dentro da área
AddEventHandler('gameEventTriggered', function(event, data)
    if event == "CEventNetworkEntityDamage" then
        local victim = data[1]
        local killer = data[2]
        local isDead = IsEntityDead(victim)

        if isDead and IsPedAPlayer(victim) and IsPedAPlayer(killer) then
            local victimPlayer = NetworkGetPlayerIndexFromPed(victim)
            local killerPlayer = NetworkGetPlayerIndexFromPed(killer)

            if victimPlayer == PlayerId() or killerPlayer == PlayerId() then
                local pCoords = GetEntityCoords(PlayerPedId())

                for id, turf in pairs(Config.Turfs) do
                    if IsInSquareArea(pCoords, turf.coords, turf.width, turf.height) then
                        if killerPlayer == PlayerId() then
                            TriggerServerEvent('ugw_turf:server:onPlayerKill', GetPlayerServerId(killerPlayer), id)
                        end
                        break
                    end
                end
            end
        end
    end
end)
