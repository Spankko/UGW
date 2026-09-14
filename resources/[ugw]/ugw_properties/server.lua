local QBCore = exports['qb-core']:GetCoreObject()
local PropertiesState = {}
local SessionEarnings = {}

-- Função auxiliar para obter o nome do proprietário
local function GetOwnerDisplayName(ownerCitizenId, ownerGang)
    if not ownerCitizenId then return 'Disponível' end

    local charName = nil

    local Player = QBCore.Functions.GetPlayerByCitizenId(ownerCitizenId)
    if Player and Player.PlayerData and Player.PlayerData.charinfo then
        local info = Player.PlayerData.charinfo
        charName = info.firstname .. ' ' .. info.lastname
    else
        local result = MySQL.query.await('SELECT charinfo FROM players WHERE citizenid = ?', { ownerCitizenId })
        if result and result[1] and result[1].charinfo then
            local info = json.decode(result[1].charinfo)
            if info and info.firstname and info.lastname then
                charName = info.firstname .. ' ' .. info.lastname
            end
        end
    end

    if not charName then
        charName = 'Proprietário'
    end

    if ownerGang and ownerGang ~= 'none' and ownerGang ~= '' then
        return charName .. ' (' .. ownerGang:upper() .. ')'
    end

    return charName
end

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    local result = MySQL.query.await('SELECT * FROM gang_properties', {})

    if result then
        for _, v in ipairs(result) do
            PropertiesState[v.property_id] = {
                gang = v.owner_gang,
                owner = v.owner_identifier
            }
        end
    end
end)

RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not Player then return end

    local citizenId = Player.PlayerData.citizenid
    SessionEarnings[citizenId] = {}
    
    -- Atualiza os blips ao carregar o jogador
    TriggerClientEvent('ugw_properties:client:updateBlips', src, PropertiesState)
end)

AddEventHandler('playerDropped', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if Player then
        SessionEarnings[Player.PlayerData.citizenid] = nil
    end
end)

-- Callback para carregar os blips ao iniciar
QBCore.Functions.CreateCallback('ugw_properties:server:getPropertiesState', function(source, cb)
    cb(PropertiesState)
end)

-- Compra / Tomada de Propriedade
RegisterNetEvent('ugw_properties:server:buyProperty', function(propId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not Player then return end

    local citizenId = Player.PlayerData.citizenid
    local gang = Player.PlayerData.gang.name
    local prop = Config.Properties[propId]

    if not prop then
        TriggerClientEvent('QBCore:Notify', src, 'Propriedade inválida.', 'error')
        return
    end

    local previousState = PropertiesState[propId]

    -- Impede de comprar uma propriedade que já é sua
    if previousState and previousState.owner == citizenId then
        TriggerClientEvent('QBCore:Notify', src, 'Você já é o proprietário desta empresa!', 'error')
        return
    end

    -- Tenta remover o dinheiro em mãos do comprador
    if Player.Functions.RemoveMoney('cash', prop.price, 'buy-property') then
        
        -- Se já existia um dono anterior, transfere o valor em dinheiro pra mão dele (se estiver online)
        if previousState and previousState.owner then
            local PreviousOwner = QBCore.Functions.GetPlayerByCitizenId(previousState.owner)
            if PreviousOwner then
                PreviousOwner.Functions.AddMoney('cash', prop.price, 'property-bought-out')
                TriggerClientEvent('QBCore:Notify', PreviousOwner.PlayerData.source, 'Sua propriedade ' .. prop.name .. ' foi comprada por outro jogador por $' .. prop.price, 'primary')
            end
        end

        -- Atualiza o novo dono
        PropertiesState[propId] = {
            gang = gang,
            owner = citizenId
        }

        SessionEarnings[citizenId] = SessionEarnings[citizenId] or {}

        MySQL.insert(
            'INSERT INTO gang_properties (property_id, owner_gang, owner_identifier) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE owner_gang = ?, owner_identifier = ?',
            {
                propId,
                gang,
                citizenId,
                gang,
                citizenId
            }
        )

        TriggerClientEvent('QBCore:Notify', src, 'Você adquiriu o domínio da propriedade!', 'success')
        TriggerClientEvent('ugw_properties:client:propertyUpdated', -1, propId)
        TriggerClientEvent('ugw_properties:client:updateBlips', -1, PropertiesState)
    else
        TriggerClientEvent('QBCore:Notify', src, 'Saldo insuficiente em mãos.', 'error')
    end
end)

-- Venda da propriedade pelo dono
RegisterNetEvent('ugw_properties:server:sellProperty', function(propId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not Player then return end

    local citizenId = Player.PlayerData.citizenid
    local prop = Config.Properties[propId]
    local state = PropertiesState[propId]

    if not prop or not state then
        TriggerClientEvent('QBCore:Notify', src, 'Esta propriedade não possui dono.', 'error')
        return
    end

    if state.owner ~= citizenId then
        TriggerClientEvent('QBCore:Notify', src, 'Você não é o dono desta propriedade.', 'error')
        return
    end

    Player.Functions.AddMoney('cash', prop.price, 'sell-property')

    PropertiesState[propId] = nil
    if SessionEarnings[citizenId] then
        SessionEarnings[citizenId][propId] = nil
    end

    MySQL.query('DELETE FROM gang_properties WHERE property_id = ?', { propId })

    TriggerClientEvent('QBCore:Notify', src, 'Propriedade vendida por $' .. prop.price .. '!', 'success')
    TriggerClientEvent('ugw_properties:client:propertyUpdated', -1, propId)
    TriggerClientEvent('ugw_properties:client:updateBlips', -1, PropertiesState)
end)

-- Callback do NUI
QBCore.Functions.CreateCallback('ugw_properties:server:getPropertyData', function(source, cb, propId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not Player then
        cb(nil)
        return
    end

    local prop = Config.Properties[propId]

    if not prop then
        cb(nil)
        return
    end

    local state = PropertiesState[propId]
    local citizenId = Player.PlayerData.citizenid

    local ownerName = 'Disponível'

    if state then
        ownerName = GetOwnerDisplayName(state.owner, state.gang)
    end

    local isOwner = state and state.owner == citizenId or false

    local earnings = {}

    if isOwner and SessionEarnings[citizenId] and SessionEarnings[citizenId][propId] then
        earnings = SessionEarnings[citizenId][propId]
    end

    local sessionTotal = 0

    for _, value in ipairs(earnings) do
        sessionTotal = sessionTotal + value.amount
    end

    local payout = prop.payoutAmount or math.floor(
        prop.price * (prop.payoutPercent or 0.02)
    )

    cb({
        id = propId,
        label = prop.name,
        name = prop.name,
        price = prop.price,
        owner = ownerName,
        hasOwner = state ~= nil and state.owner ~= nil,
        isOwner = isOwner,
        payout = payout,
        earnings = earnings,
        sessionTotal = sessionTotal
    })
end)

-- Pagamento de rendimento
CreateThread(function()
    while true do
        Wait(600000)

        for propId, data in pairs(PropertiesState) do
            if data.owner then
                local Player = QBCore.Functions.GetPlayerByCitizenId(data.owner)
                local propData = Config.Properties[propId]

                if Player and propData then
                    local payout = propData.payoutAmount or math.floor(
                        propData.price * (propData.payoutPercent or 0.02)
                    )

                    Player.Functions.AddMoney('cash', payout, 'property-yield')

                    local citizenId = Player.PlayerData.citizenid

                    SessionEarnings[citizenId] = SessionEarnings[citizenId] or {}
                    SessionEarnings[citizenId][propId] = SessionEarnings[citizenId][propId] or {}

                    table.insert(SessionEarnings[citizenId][propId], {
                        amount = payout,
                        time = os.date('%H:%M')
                    })

                    TriggerClientEvent('QBCore:Notify', Player.PlayerData.source, 'Rendimento recebido de ' .. propData.name .. ': $' .. payout, 'success')
                    TriggerClientEvent('ugw_properties:client:sessionEarning', Player.PlayerData.source, propId, payout, os.date('%H:%M'))
                end
            end
        end
    end
end)