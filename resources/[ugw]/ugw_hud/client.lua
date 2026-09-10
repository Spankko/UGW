-- Author: Gustavo Spankko
CreateThread(function()
    Wait(1000)
    SendNUIMessage({
        type = "showHud",
        status = true
    })
end)