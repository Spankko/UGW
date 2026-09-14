local QBCore = exports['qb-core']:GetCoreObject()

-- =======================================================
-- SISTEMA NUI DO PAINEL DA GANGUE (/painelgangue)
-- =======================================================

RegisterCommand('painelgangue', function()
    QBCore.Functions.TriggerCallback('ugw_gangs:server:getGangData', function(data)
        SetNuiFocus(true, true)
        
        if data and data.hasGang then
            SendNUIMessage({
                action = "openPanel",
                hasGang = true,
                gangData = data,
                creationCost = Config.CreationCost
            })
        else
            SendNUIMessage({
                action = "openPanel",
                hasGang = false,
                creationCost = Config.CreationCost
            })
        end
    end)
end)

RegisterNUICallback('closePanel', function(data, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('createGang', function(data, cb)
    local name = data.name
    local label = data.label

    if name and label and name ~= "" and label ~= "" then
        QBCore.Functions.TriggerCallback('ugw_gangs:server:createNewGang', function(success, gangData)
            if success then
                SetNuiFocus(true, true)
                SendNUIMessage({
                    action = "openPanel",
                    hasGang = true,
                    gangData = gangData,
                    creationCost = Config.CreationCost
                })
            else
                SetNuiFocus(false, false)
            end
        end, name, label)
    else
        QBCore.Functions.Notify("Preencha todos os campos para criar a equipe!", "error")
        SetNuiFocus(true, true)
    end
    
    cb('ok')
end)

RegisterNUICallback('depositBank', function(data, cb)
    local amount = tonumber(data.amount)
    if amount and amount > 0 then
        TriggerServerEvent('ugw_gangs:server:depositMoney', amount)
    end
    cb('ok')
end)

RegisterNUICallback('withdrawBank', function(data, cb)
    local amount = tonumber(data.amount)
    if amount and amount > 0 then
        TriggerServerEvent('ugw_gangs:server:withdrawMoney', amount)
    end
    cb('ok')
end)

RegisterNUICallback('inviteMember', function(data, cb)
    local targetId = tonumber(data.targetId)
    if targetId then
        ExecuteCommand('convidar ' .. targetId)
    end
    cb('ok')
end)

RegisterNUICallback('promoteMember', function(data, cb)
    if data.citizenid then
        TriggerServerEvent('ugw_gangs:server:promoteMemberByCitizenId', data.citizenid)
    end
    cb('ok')
end)

RegisterNUICallback('demoteMember', function(data, cb)
    if data.citizenid then
        TriggerServerEvent('ugw_gangs:server:demoteMemberByCitizenId', data.citizenid)
    end
    cb('ok')
end)

RegisterNUICallback('kickMember', function(data, cb)
    if data.citizenid then
        TriggerServerEvent('ugw_gangs:server:kickMemberByCitizenId', data.citizenid)
    end
    cb('ok')
end)

RegisterNetEvent('ugw_gangs:client:refreshPanel', function()
    local PlayerData = QBCore.Functions.GetPlayerData()
    if PlayerData.gang and PlayerData.gang.name ~= "none" then
        QBCore.Functions.TriggerCallback('ugw_gangs:server:getGangData', function(data)
            if data then
                SendNUIMessage({
                    action = "updateData",
                    gangData = data
                })
            end
        end)
    end
end)

-- =======================================================
-- GERENCIAMENTO DE VEÍCULOS E COFRE
-- =======================================================

RegisterNetEvent('ugw_gangs:client:ejectUnauthorizedDrivers', function(baseId, newGangOwner)
    local ped = PlayerPedId()

    if IsPedInAnyVehicle(ped, false) then
        local veh = GetVehiclePedIsIn(ped, false)
        local vehBaseId = Entity(veh).state.baseId

        if vehBaseId and tonumber(vehBaseId) == tonumber(baseId) then
            local PlayerData = QBCore.Functions.GetPlayerData()

            if not PlayerData.gang or PlayerData.gang.name ~= newGangOwner then
                TaskLeaveVehicle(ped, veh, 16)
                SetVehicleDoorsLocked(veh, 2)
                QBCore.Functions.Notify("A base trocou de dono! Você foi ejetado do veículo.", "error")
            end
        end
    end
end)

AddEventHandler('gameEventTriggered', function(event, args)
    if event == "CEventNetworkPlayerEnteredVehicle" then
        local playerPed = args[1]
        local vehicle = args[2]

        if playerPed == PlayerPedId() then
            local gangOwner = Entity(vehicle).state.gangOwner
            local PlayerData = QBCore.Functions.GetPlayerData()

            if gangOwner then
                if PlayerData.gang and PlayerData.gang.name == gangOwner then
                    TriggerEvent("vehiclekeys:client:SetOwner", QBCore.Functions.GetPlate(vehicle))
                    SetVehicleDoorsLocked(vehicle, 1)
                else
                    SetVehicleEngineOn(vehicle, false, false, true)
                    SetVehicleDoorsLocked(vehicle, 2)
                    QBCore.Functions.Notify("Este veículo pertence a outra organização!", "error")
                end
            end
        end
    end
end)

RegisterCommand('cofre', function()
    local PlayerData = QBCore.Functions.GetPlayerData()

    if not PlayerData.gang or PlayerData.gang.name == "none" then
        QBCore.Functions.Notify('Você não pertence a nenhuma equipe!', 'error')
        return
    end

    TriggerServerEvent('ugw_gangs:server:openStash')
end)