RegisterNetEvent('ugw_welcome:showWelcomeMessages', function()
    -- Lista de mensagens enviadas do servidor
    local messages = {
        { color = {255, 204, 0}, args = {"UGW - DM", "===================================================="} },
        { color = {255, 204, 0}, args = {"UGW - DM", "              UGW 1.0 FiveM - 2026"} },
        { color = {255, 255, 0}, args = {"UGW - DM", " » Idealização Spankko, HanzoBR, ErmacÇ, Sukita e Truta."} },
        { color = {0, 153, 255}, args = {"UGW - DM", " » Créditos e Agradecimentos a Equipe Classic GW."} },
        { color = {204, 0, 0}, args = {"UGW - DM", " » Créditos e Agradecimentos a Equipe GtO Games."} },
        { color = {255, 255, 255}, args = {"UGW - DM", " » Para Mais Informações, Digite o Comando /ajuda"} },
        { color = {255, 204, 0}, args = {"UGW - DM", "===================================================="} },
        { color = {0, 204, 102}, args = {"UGW - DM", "Sejam todos bem vindos ao CLASSIC GANGWAR!"} }
    }

    for _, msg in ipairs(messages) do
        TriggerEvent('chat:addMessage', msg)
    end

    -- Aguarda 8 segundos para o jogador ler e fecha a caixa de texto do chat
    SetTimeout(8000, function()
        ExecuteCommand('chatClose') -- Força o fechamento da UI do chat
    end)
end)