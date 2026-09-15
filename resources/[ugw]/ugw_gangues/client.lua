local QBCore = exports['qb-core']:GetCoreObject()
local isUiOpen = false

-- =========================================================================
-- [1. GATILHOS DE COMANDO E RECEBIMENTO DE EVENTOS]
-- =========================================================================

-- Evento disparado pelo Server para abrir a tela de criação (/criargang)
RegisterNetEvent('ugw_gangs:client:openCreationMenu', function(creationCost)
    if isUiOpen then return end
    isUiOpen = true
    
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "openCreation", -- CORREÇÃO: Alinhado com a linha 10 do script.js
        cost = creationCost
    })
end)

-- Evento disparado pelo Server para abrir o Dashboard Geral (/menugang)
RegisterNetEvent('ugw_gangs:client:openDashboard', function(data)
    -- CORREÇÃO: Envia sempre 'openDashboard' para o javascript fazer o re-render
    -- Isso garante compatibilidade com a linha 14 do seu script.js
    isUiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "openDashboard", 
        data = data
    })
end)

-- Evento disparado pelo Server para abrir a Administração Master da Staff (/admingang)
RegisterNetEvent('ugw_gangs:client:openAdminDashboard', function(adminData)
    isUiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "openAdmin", -- CORREÇÃO: Alinhado com a linha 74 do script.js
        data = adminData
    })
end)

-- Evento universal forçado pelo servidor para fechar a UI (ex: jogador expulso ou gangue deletada)
RegisterNetEvent('ugw_gangs:client:forceCloseUi', function()
    if not isUiOpen then return end
    isUiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = "closeAll" -- CORREÇÃO: Alinhado com a linha 110 do script.js
    })
end)

-- =========================================================================
-- [2. SISTEMA ADAPTATIVO DE CONVITES POP-UP]
-- =========================================================================

RegisterNetEvent('ugw_gangs:client:receiveInvite', function(gangName, gangLabel, leaderSource)
    -- Envia para a interface NUI processar o pop-up de escolha do jogador na tela dele
    SendNUIMessage({
        action = "receiveInvite", -- CORREÇÃO: Alinhado com a linha 98 do script.js
        gangName = gangName,
        gangLabel = gangLabel, -- CORREÇÃO: Alinhado com a propriedade esperada na linha 101 do script.js
        leaderSource = leaderSource -- CORREÇÃO: Alinhado com a linha 99 do script.js
    })
end)

-- Callback que a NUI aciona quando o jogador clica em "Aceitar" ou "Recusar" no pop-up de convite
RegisterNUICallback('respondToInvite', function(data, cb)
    TriggerServerEvent('ugw_gangs:server:respondToInvite', data.gangName, data.leaderSource, data.accepted)
    cb('ok')
end)

-- =========================================================================
-- [3. CALLBACKS DE INTERAÇÃO DA NUI (INTERFACE -> SERVIDOR)]
-- =========================================================================

-- Acionado quando o formulário de criação de nova gangue é enviado
RegisterNUICallback('registerNewGang', function(data, cb)
    if not data.gangId or not data.gangLabel then return cb('error') end -- CORREÇÃO: Alinhado com os objetos da linha 131 do script.js
    TriggerServerEvent('ugw_gangs:server:registerNewGang', data.gangId, data.gangLabel)
    cb('ok')
end)

-- Acionado nas movimentações de Depósito ou Saque de dinheiro do cofre
RegisterNUICallback('manageFunds', function(data, cb)
    if not data.action or not data.amount then return cb('error') end
    TriggerServerEvent('ugw_gangs:server:manageFunds', data.action, data.amount)
    cb('ok')
end)

-- Acionado ao clicar nos botões de ação na lista de membros (Promover, Rebaixar, Expulsar)
RegisterNUICallback('executeMemberAction', function(data, cb)
    if not data.action then return cb('error') end
    TriggerServerEvent('ugw_gangs:server:executeMemberAction', data.action, data.targetId, data.targetCitizenId)
    cb('ok')
end)

-- Acionado ao escolher um jogador da lista de candidatos e enviar um convite
RegisterNUICallback('invitePlayer', function(data, cb)
    if not data.targetId then return cb('error') end
    TriggerServerEvent('ugw_gangs:server:invitePlayer', data.targetId)
    cb('ok')
end)

-- Acionado na aba administrativa do líder para salvar link de logo e redefinir nome
RegisterNUICallback('saveLeaderSettings', function(data, cb)
    TriggerServerEvent('ugw_gangs:server:saveLeaderSettings', data.label, data.logoUrl)
    cb('ok')
end)

-- Acionado na aba administrativa do líder ao transferir a propriedade da organização
RegisterNUICallback('transferOwnership', function(data, cb)
    if not data.targetCitizenId then return cb('error') end
    TriggerServerEvent('ugw_gangs:server:transferOwnership', data.targetCitizenId)
    cb('ok')
end)

-- Callbacks exclusivas do painel master de staff (/admingang)
RegisterNUICallback('adminForceAction', function(data, cb)
    if not data.action or not data.gangName then return cb('error') end
    TriggerServerEvent('ugw_gangs:server:adminForceAction', data.action, data.gangName, data.extraData)
    cb('ok')
end)

-- =========================================================================
-- [4. FECHAMENTO SEGURO DA INTERFACE]
-- =========================================================================

-- Acionado universalmente quando o jogador fecha o painel via botão ou tecla ESC na interface
RegisterNUICallback('closeUi', function(_, cb)
    isUiOpen = false
    SetNuiFocus(false, false)
    cb('ok')
end)

-- Garante que se o recurso for reiniciado no servidor, a tela do jogador não trave com foco
AddEventHandler('onResourceStop', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then return end
    if isUiOpen then
        SetNuiFocus(false, false)
    end
end)
