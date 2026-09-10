local QBCore = exports['qb-core']:GetCoreObject()

-- Força o FiveM a fechar qualquer loading travado
AddEventHandler('playerSpawned', function()
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
end)

-- Intercepta o momento em que o personagem é selecionado no multicharacter
RegisterNetEvent('qb-multicharacter:client:spawnCharacter', function(spawnData)
    DoScreenFadeOut(500)
    Wait(500)
    
    -- Abre a nossa NUI de regras clássica
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "openIntro"
    })
    
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
    DoScreenFadeIn(500)
end)

-- Gatilho alternativo de suporte
RegisterNetEvent('ugw_intro:client:openIntro', function()
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "openIntro"
    })
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
end)

-- Callback acionado quando o jogador clica em "Concordo"
RegisterNUICallback('closeIntro', function(data, cb)
    SetNuiFocus(false, false)
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    
    DoScreenFadeIn(500)
    NetworkSetFriendlyFireOption(true)

    -- Teleporta e spawna o player na Legion Square com proteção
    TriggerServerEvent('ugw_intro:server:spawnPlayer')
    cb('ok')
end)