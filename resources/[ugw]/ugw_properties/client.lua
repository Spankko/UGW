local QBCore = exports['qb-core']:GetCoreObject()

local isHudOpen = false
local currentProperty = nil
local spawnedBlips = {}

-- Função para atualizar/redesenhar todos os blips do mapa
local function RefreshBlips(propertiesState)
    -- Remove blips antigos para evitar duplicidade
    for _, blip in pairs(spawnedBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    spawnedBlips = {}

    if not Config or not Config.Properties then return end

    for id, prop in pairs(Config.Properties) do
        local blip = AddBlipForCoord(prop.coords.x, prop.coords.y, prop.coords.z)
        local isOwned = propertiesState and propertiesState[id] and propertiesState[id].owner ~= nil

        SetBlipSprite(blip, 475)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, 0.45)
        
        -- Cor 52 = Verde (Disponível) | Cor 1 = Vermelho (Comprada/Ocupada)
        if isOwned then
            SetBlipColour(blip, 1)
        else
            SetBlipColour(blip, 52)
        end

        SetBlipAsShortRange(blip, true)

        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(prop.name)
        EndTextCommandSetBlipName(blip)

        spawnedBlips[id] = blip
    end
end

-- Inicialização e sincronização de blips com o servidor
CreateThread(function()
    Wait(1000)
    QBCore.Functions.TriggerCallback('ugw_properties:server:getPropertiesState', function(propertiesState)
        RefreshBlips(propertiesState)
    end)
end)

-- Evento enviado pelo servidor ao comprar ou vender uma propriedade
RegisterNetEvent('ugw_properties:client:updateBlips', function(propertiesState)
    RefreshBlips(propertiesState)
end)

-- Interação no solo
CreateThread(function()
    while true do
        local sleep = 1000
        local pCoords = GetEntityCoords(PlayerPedId())

        if Config and Config.Properties then
            for id, prop in pairs(Config.Properties) do
                local dist = #(pCoords - prop.coords)

                if dist < 10.0 then
                    sleep = 0

                    DrawMarker(
                        1,
                        prop.coords.x,
                        prop.coords.y,
                        prop.coords.z - 0.98,
                        0.0, 0.0, 0.0,
                        0.0, 0.0, 0.0,
                        1.2, 1.2, 0.8,
                        0, 200, 100, 100,
                        false, true, 2, false
                    )

                    if dist < 1.5 and not isHudOpen then
                        QBCore.Functions.DrawText3D(
                            prop.coords.x,
                            prop.coords.y,
                            prop.coords.z,
                            '[E] - Visualizar'
                        )

                        if IsControlJustPressed(0, 38) then
                            currentProperty = id

                            QBCore.Functions.TriggerCallback(
                                'ugw_properties:server:getPropertyData',
                                function(data)
                                    if not data then return end

                                    isHudOpen = true
                                    SetNuiFocus(true, true)

                                    SendNUIMessage({
                                        action = 'open',
                                        data = data
                                    })
                                end,
                                id
                            )
                        end
                    end
                end
            end
        end

        Wait(sleep)
    end
end)

-- Callbacks e eventos NUI
RegisterNUICallback('close', function(_, cb)
    isHudOpen = false
    currentProperty = nil
    SetNuiFocus(false, false)

    SendNUIMessage({ action = 'close' })
    cb('ok')
end)

RegisterNUICallback('buyProperty', function(data, cb)
    if not currentProperty then cb('ok') return end

    TriggerServerEvent('ugw_properties:server:buyProperty', currentProperty)
    cb('ok')

    Wait(500)
    QBCore.Functions.TriggerCallback('ugw_properties:server:getPropertyData', function(propertyData)
        if propertyData then
            SendNUIMessage({ action = 'update', data = propertyData })
        end
    end, currentProperty)
end)

RegisterNUICallback('sellProperty', function(data, cb)
    if not currentProperty then cb('ok') return end

    TriggerServerEvent('ugw_properties:server:sellProperty', currentProperty)
    cb('ok')

    Wait(500)
    QBCore.Functions.TriggerCallback('ugw_properties:server:getPropertyData', function(propertyData)
        if propertyData then
            SendNUIMessage({ action = 'update', data = propertyData })
        end
    end, currentProperty)
end)

RegisterNetEvent('ugw_properties:client:propertyUpdated', function(propId)
    if isHudOpen and currentProperty == propId then
        QBCore.Functions.TriggerCallback('ugw_properties:server:getPropertyData', function(data)
            if data then SendNUIMessage({ action = 'update', data = data }) end
        end, propId)
    end
end)

RegisterNetEvent('ugw_properties:client:sessionEarning', function(propId, amount, time)
    if not isHudOpen or currentProperty ~= propId then return end
    SendNUIMessage({ action = 'earning', amount = amount, time = time })
end)

CreateThread(function()
    while true do
        Wait(0)
        if isHudOpen and IsControlJustPressed(0, 322) then
            isHudOpen = false
            currentProperty = nil
            SetNuiFocus(false, false)
            SendNUIMessage({ action = 'close' })
        end
    end
end)