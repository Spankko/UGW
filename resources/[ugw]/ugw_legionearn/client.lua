local QBCore = exports['qb-core']:GetCoreObject()

-- Criação da PolyZone
local legionZone = PolyZone:Create({
    vector2(186.36, -847.46),
    vector2(260.23, -874.73),
    vector2(208.33, -1014.84),
    vector2(129.17, -987.95)
}, {
    name = "Legion Square",
    useGrid = true
})

local lastPosition = nil
local timeInZone = 0
local currentReward = 0
local currentMultiplier = 1.0
local isShowingText = false

-- Função auxiliar para desenhar o texto 2D na tela
local function DrawText2D(text, x, y)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextScale(0.40, 0.40) -- Reduzido levemente a escala para um visual mais limpo
    SetTextColour(0, 255, 120, 255)
    SetTextDropShadow(0, 0, 0, 0, 255)
    SetTextEdge(1, 0, 0, 0, 255)
    SetTextDropShadow()
    SetTextOutline()
    SetTextEntry("STRING")
    AddTextComponentString(text)
    DrawText(x, y)
end

-- Recebe as informações do servidor
RegisterNetEvent('ugw_legionearn:client:updateDisplay', function(reward, multiplier)
    currentReward = reward
    currentMultiplier = multiplier
    isShowingText = true
end)

-- Loop principal de movimentação e recompensa
CreateThread(function()
    while true do
        Wait(1000)
        
        local playerPed = PlayerPedId()
        
        if not IsPedDeadOrDying(playerPed, true) then
            local currentCoords = GetEntityCoords(playerPed)
            local isInside = legionZone:isPointInside(currentCoords)

            if isInside then
                if lastPosition then
                    local moveDistance = #(currentCoords - lastPosition)
                    
                    if moveDistance > 0.5 then
                        timeInZone = timeInZone + 1
                        TriggerServerEvent('ugw_legionearn:server:giveReward', timeInZone)
                    else
                        timeInZone = 0
                        isShowingText = false
                    end
                end
                lastPosition = currentCoords
            else
                timeInZone = 0
                lastPosition = nil
                isShowingText = false
            end
        else
            timeInZone = 0
            lastPosition = nil
            isShowingText = false
        end
    end
end)

-- Loop de renderização do texto na tela
CreateThread(function()
    while true do
        local sleep = 500

        if isShowingText and timeInZone > 0 then
            sleep = 0
            local displayText = string.format("LEGION SQUARE: +$%d/s (Mult: %.1fx)", currentReward, currentMultiplier)
            
            -- X = 0.82 (Canto superior direito)
            -- Y = 0.15 (Abaixo do local/bairro padrão da hud)
            DrawText2D(displayText, 0.82, 0.15)
        end

        Wait(sleep)
    end
end)