local QBCore = exports['qb-core']:GetCoreObject()
local isScoreboardOpen = false

-- Abertura e fechamento do Scoreboard pela tecla TAB (237)
CreateThread(function()
    while true do
        Wait(0)
        if IsControlJustPressed(0, 37) then -- Tecla TAB
            if not isScoreboardOpen then
                QBCore.Functions.TriggerCallback('ugw_scoreboard:getPlayers', function(players)
                    SendNUIMessage({
                        action = "open",
                        players = players
                    })
                    isScoreboardOpen = true
                end)
            end
        elseif IsControlJustReleased(0, 37) then
            if isScoreboardOpen then
                SendNUIMessage({ action = "close" })
                isScoreboardOpen = false
            end
        end
    end
end)