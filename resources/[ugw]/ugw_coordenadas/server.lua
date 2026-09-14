RegisterNetEvent('ugw_coordenadas:salvar')
AddEventHandler('ugw_coordenadas:salvar', function(data)
    local resourceName = GetCurrentResourceName()
    local conteudoExistente = LoadResourceFile(resourceName, "coordenadas.txt") or ""

    -- Formato pronto para usar no DrawMarker
    local novaLinha = string.format(
        "// Local: %s | Bairro/Zona: %s\nvector3(%s, %s, %s), -- Heading: %s\n\n",
        data.nome,
        data.zona,
        data.x,
        data.y,
        data.z,
        data.h
    )

    local novoConteudo = conteudoExistente .. novaLinha
    SaveResourceFile(resourceName, "coordenadas.txt", novoConteudo, -1)
end)