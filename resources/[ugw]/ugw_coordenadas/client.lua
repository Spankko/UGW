RegisterCommand('coords', function(source, args, rawCommand)
    local localNome = table.concat(args, " ")
    
    if localNome == "" then
        TriggerEvent('chat:addMessage', {
            color = {255, 0, 0},
            multiline = true,
            args = {"UGW", "Por favor, informe o nome do local. Ex: /coords Entrada Garagem"}
        })
        return
    end

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local zoneHash = GetNameOfZone(coords.x, coords.y, coords.z)
    local zoneName = GetLabelText(zoneHash)

    -- Formatação pronta para copiar ou salvar direto para DrawMarker
    local dataStruct = {
        nome = localNome,
        zona = zoneName,
        x = string.format("%.2f", coords.x),
        y = string.format("%.2f", coords.y),
        z = string.format("%.2f", coords.z),
        h = string.format("%.2f", heading)
    }

    -- Envia para o servidor salvar no arquivo
    TriggerServerEvent('ugw_coordenadas:salvar', dataStruct)

    TriggerEvent('chat:addMessage', {
        color = {0, 255, 0},
        multiline = true,
        args = {"UGW", string.format("Coordenadas de '%s' (%s) salvas com sucesso!", localNome, zoneName)}
    })
end, false)