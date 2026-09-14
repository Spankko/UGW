local QBCore = exports['qb-core']:GetCoreObject()
local currentTurf = nil
local TurfBlips = {}
local TurfPolyZones = {}
local DynamicGangColors = {}

-- ID 4 é a cor branca/cinza visível para áreas neutras (ID 0 é transparente no GTA)
local DEFAULT_NEUTRAL_COLOR = 4 

local function ParsePoints(points)
    local result = {}
    if not points then return result end
    for i = 1, #points do
        local p = points[i]
        if type(p) == "vector2" then
            table.insert(result, vector2(p.x, p.y))
        elseif type(p) == "table" and p.x and p.y then
            table.insert(result, vector2(tonumber(p.x), tonumber(p.y)))
        end
    end
    return result
end

local function BuildTurfBlips()
    -- Limpa Blips anteriores para evitar duplicação
    for id, blip in pairs(TurfBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    TurfBlips = {}
    TurfPolyZones = {}

    if not Config or not Config.Turfs then return end

    for id, turf in pairs(Config.Turfs) do
        local points = ParsePoints(turf.points)
        
        if #points >= 3 then
            -- Cria a zona do PolyZone para detecção de presença de jogador
            TurfPolyZones[id] = PolyZone:Create(points, {
                name = "turf_" .. id,
                minZ = -100.0,
                maxZ = 800.0,
                debugPoly = false
            })

            -- Calcula o centro e as dimensões da caixa
            local minX, maxX = 99999.0, -99999.0
            local minY, maxY = 99999.0, -99999.0

            for i = 1, #points do
                if points[i].x < minX then minX = points[i].x end
                if points[i].x > maxX then maxX = points[i].x end
                if points[i].y < minY then minY = points[i].y end
                if points[i].y > maxY then maxY = points[i].y end
            end

            local width = math.abs(maxX - minX)
            local height = math.abs(maxY - minY)
            local centerX = minX + (width / 2.0)
            local centerY = minY + (height / 2.0)

            -- Cria o Blip de Área no Mapa
            local areaBlip = AddBlipForArea(centerX, centerY, 0.0, width, height)
            SetBlipRotation(areaBlip, 0)
            SetBlipAlpha(areaBlip, 140) -- Opacidade da cor (0 a 255)
            SetBlipDisplay(areaBlip, 4) -- Exibe no mini-mapa e mapa principal
            SetBlipAsShortRange(areaBlip, false)

            -- Define a cor baseada no dono da gangue ou na cor neutra
            local color = DEFAULT_NEUTRAL_COLOR
            if turf.owner and DynamicGangColors[turf.owner] then
                color = DynamicGangColors[turf.owner]
            end
            SetBlipColour(areaBlip, color)

            TurfBlips[id] = areaBlip
        end
    end
end

RegisterNetEvent('ugw_turfs:client:syncTurfs', function(turfsData, gangColorsData)
    Config.Turfs = turfsData
    DynamicGangColors = gangColorsData or {}
    BuildTurfBlips()
end)

RegisterNetEvent('ugw_turfs:client:updateHud', function(turfName, owner, progress)
    SendNUIMessage({
        action = "updateHud",
        name = turfName,
        owner = owner,
        progress = progress or 0
    })
end)

-- Sincroniza ao ligar o recurso ou quando o jogador loga
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    Wait(500)
    TriggerServerEvent('ugw_turfs:server:requestSync')
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    Wait(1000)
    TriggerServerEvent('ugw_turfs:server:requestSync')
end)

-- Loop de verificação de entrada/saída de territórios
CreateThread(function()
    while true do
        local sleep = 1000
        local ped = PlayerPedId()

        if DoesEntityExist(ped) then
            local pCoords = GetEntityCoords(ped)
            local insideTurfId = nil

            for id, poly in pairs(TurfPolyZones) do
                if poly and poly.isPointInside and poly:isPointInside(pCoords) then
                    insideTurfId = id
                    sleep = 500
                    break
                end
            end

            if insideTurfId and currentTurf ~= insideTurfId then
                currentTurf = insideTurfId
                SendNUIMessage({ action = "toggleHud", show = true })
                TriggerServerEvent('ugw_turfs:server:enterTurf', insideTurfId)
            elseif not insideTurfId and currentTurf then
                SendNUIMessage({ action = "toggleHud", show = false })
                TriggerServerEvent('ugw_turfs:server:leaveTurf', currentTurf)
                currentTurf = nil
            end
        end

        Wait(sleep)
    end
end)

-- Comando manual de teste
RegisterCommand('testeturf', function()
    TriggerServerEvent('ugw_turfs:server:requestSync')
    QBCore.Functions.Notify('Recarregando blips de territórios...', 'success')
end, false)