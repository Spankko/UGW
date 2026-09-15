local QBCore = exports['qb-core']:GetCoreObject()
local GangsCache = {} -- Cache em memória RAM para otimização de performance e consultas rápidas

-- =========================================================================
-- [1. INICIALIZAÇÃO DO SERVIDOR & CARREGAMENTO DE CACHE]
-- =========================================================================

AddEventHandler('onResourceStart', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then return end
    
    MySQL.Async.fetchAll('SELECT * FROM ugw_gangs', {}, function(results)
        if results then
            for _, gang in ipairs(results) do
                GangsCache[gang.gang_name] = {
                    label = gang.label,
                    type = gang.type,
                    funds = gang.funds,
                    logo_url = gang.logo_url,
                    last_active = gang.last_active
                }
            end
            print("^2[ugw_gangs] Inicializado com sucesso. " .. #results .. " organizacoes indexadas em cache.^7")
        end
    end)
end)

-- =========================================================================
-- [2. GERENCIAMENTO DE LOGINS E SESSÕES (HOOKS QBCORE)]
-- =========================================================================

-- CORREÇÃO: Utilizando consulta Síncrona para blindar o carregamento de metadados do QBCore
RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid

    -- CORREÇÃO: Puxando o primeiro índice [1] do retorno da tabela do banco
    local result = MySQL.Sync.fetchAll('SELECT ugw_gang, ugw_gang_grade FROM players WHERE citizenid = ?', {citizenid})
    if result and result[1] then
        Player.PlayerData.ugw_gang = result[1].ugw_gang or "none"
        Player.PlayerData.ugw_gang_grade = result[1].ugw_gang_grade or 0
        
        local gang = Player.PlayerData.ugw_gang
        if gang ~= "none" and GangsCache[gang] and GangsCache[gang].type == "player" then
            local currentTimestamp = os.date('%Y-%m-%d %H:%M:%S')
            MySQL.Async.execute('UPDATE ugw_gangs SET last_active = ? WHERE gang_name = ?', {currentTimestamp, gang})
            GangsCache[gang].last_active = currentTimestamp
        end
    else
        Player.PlayerData.ugw_gang = "none"
        Player.PlayerData.ugw_gang_grade = 0
    end
end)

-- FUNÇÃO AUXILIAR: Atualiza o painel NUI de um jogador específico sem quebrar a source originária
local function RefreshPlayerDashboard(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local gangName = Player.PlayerData.ugw_gang
    if not gangName or gangName == "none" or not GangsCache[gangName] then return end

    local gangData = GangsCache[gangName]

    MySQL.Async.fetchAll('SELECT charinfo, citizenid, ugw_gang_grade FROM players WHERE ugw_gang = ?', {gangName}, function(dbMembers)
        local formattedMembers = {}
        local activePlayers = {}
        local qbPlayers = QBCore.Functions.GetQBPlayers()
        for _, p in pairs(qbPlayers) do
            if p and p.PlayerData then
                activePlayers[p.PlayerData.citizenid] = p.PlayerData.source
            end
        end

        for _, member in ipairs(dbMembers) do
            local charinfo = json.decode(member.charinfo or "{}")
            local fullName = (charinfo.firstname or "Sem") .. " " .. (charinfo.lastname or "Nome")
            local isOnline = activePlayers[member.citizenid] ~= nil

            table.insert(formattedMembers, {
                citizenid = member.citizenid,
                name = fullName,
                grade = member.ugw_gang_grade,
                gradeLabel = Config.Grades[member.ugw_gang_grade] and Config.Grades[member.ugw_gang_grade].name or "Recruta",
                isOnline = isOnline,
                sourceId = activePlayers[member.citizenid] or nil
            })
        end

        local candidatesList = {}
        for _, p in pairs(qbPlayers) do
            if p and p.PlayerData and p.PlayerData.ugw_gang == "none" then
                local char = p.PlayerData.charinfo
                table.insert(candidatesList, {
                    id = p.PlayerData.source,
                    name = (char.firstname or "") .. " " .. (char.lastname or "") .. " (" .. p.PlayerData.source .. ")"
                })
            end
        end

        TriggerClientEvent('ugw_gangs:client:openDashboard', src, {
            gangName = gangName,
            label = gangData.label,
            type = gangData.type,
            funds = gangData.funds,
            logoUrl = gangData.logo_url,
            myGrade = Player.PlayerData.ugw_gang_grade,
            membersOnlineCount = GetOnlineMembersCount(gangName),
            membersList = formattedMembers,
            candidates = candidatesList
        })
    end)
end

function GetOnlineMembersCount(gangName)
    local count = 0
    local players = QBCore.Functions.GetQBPlayers()
    for _, v in pairs(players) do
        if v and v.PlayerData and v.PlayerData.ugw_gang == gangName then
            count = count + 1
        end
    end
    return count
end

-- =========================================================================
-- [3. MECANISMO DE CRONJOB E SISTEMA DE SOBREVIVÊNCIA (AUTO-DELETE)]
-- =========================================================================

local function TimestampToSeconds(dateString)
    if not dateString then return os.time() end
    
    -- CORREÇÃO: Se o banco já entregar como número (Unix Timestamp), valida e retorna direto
    if type(dateString) == "number" then
        -- Se o número for muito grande (milissegundos do JavaScript/MySQL de 13 dígitos), converte para segundos (10 dígitos)
        if dateString > 9999999999 then
            return math.floor(dateString / 1000)
        end
        return dateString
    end
    
    -- Se o banco de dados entregar como String ("AAAA-MM-DD HH:MM:SS"), processa o padrão de texto original
    local pattern = "(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)"
    local runYear, runMonth, runDay, runHour, runMinute, runSeconds = tostring(dateString):match(pattern)
    if not runYear then return os.time() end
    return os.time({year = runYear, month = runMonth, day = runDay, hour = runHour, min = runMinute, sec = runSeconds})
end

local function ProcessGangWipe(gangName)
    print("^1[ugw_gangs] CRONJOB: A organizacao '" .. gangName .. "' atingiu o limite de " .. Config.InactivityLimit .. " horas inativa e foi deletada.^7")
    
    MySQL.Async.execute('DELETE FROM ugw_gangs WHERE gang_name = ?', {gangName})
    MySQL.Async.execute('UPDATE players SET ugw_gang = "none", ugw_gang_grade = 0 WHERE ugw_gang = ?', {gangName})
    
    local players = QBCore.Functions.GetQBPlayers()
    for _, v in pairs(players) do
        if v and v.PlayerData and v.PlayerData.ugw_gang == gangName then
            v.PlayerData.ugw_gang = "none"
            v.PlayerData.ugw_gang_grade = 0
            TriggerClientEvent('QBCore:Notify', v.PlayerData.source, "Sua organizacao foi desfeita automaticamente por inatividade.", "error")
            TriggerClientEvent('ugw_gangs:client:forceCloseUi', v.PlayerData.source)
        end
    end
    GangsCache[gangName] = nil
end

local function StartInactivityCronjob()
    SetTimeout(Config.CronCheckInterval * 60000, function()
        local currentTime = os.time()
        
        for gangName, data in pairs(GangsCache) do
            if data.type == "player" then
                local onlineCount = GetOnlineMembersCount(gangName)
                
                if onlineCount > 0 then
                    local currentTimestamp = os.date('%Y-%m-%d %H:%M:%S')
                    MySQL.Async.execute('UPDATE ugw_gangs SET last_active = ? WHERE gang_name = ?', {currentTimestamp, gangName})
                    data.last_active = currentTimestamp
                else
                    local lastActiveSeconds = TimestampToSeconds(data.last_active)
                    local differenceInHours = (currentTime - lastActiveSeconds) / 3600
                    
                    if differenceInHours >= Config.InactivityLimit then
                        ProcessGangWipe(gangName)
                    end
                end
            end
        end
        StartInactivityCronjob()
    end)
end
StartInactivityCronjob()

-- =========================================================================
-- [4. FLUXO DE CRIAÇÃO DINÂMICA DE GANGUES]
-- =========================================================================

QBCore.Commands.Add('criargang', 'Abrir o menu de registro de uma nova organizacao', {}, false, function(source)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    if Player.PlayerData.ugw_gang and Player.PlayerData.ugw_gang ~= "none" then
        TriggerClientEvent('QBCore:Notify', src, "Voce ja pertence a uma organizacao!", "error")
        return
    end

    TriggerClientEvent('ugw_gangs:client:openCreationMenu', src, Config.CreationCost)
end, 'user')

RegisterNetEvent('ugw_gangs:server:registerNewGang', function(gangId, gangLabel)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    if Player.PlayerData.ugw_gang and Player.PlayerData.ugw_gang ~= "none" then return end

    -- Sanitização Otimizada: Remove espaços do ID e limpa bordas da label usando Lua Puro
    gangId = tostring(gangId):gsub("%s+", ""):lower()
    gangLabel = tostring(gangLabel):gsub("^%s*(.-)%s*$", "%1") -- CORREÇÃO: Substituição nativa para o .trim()

    if gangId == "" or gangLabel == "" or gangId == "none" then
        TriggerClientEvent('QBCore:Notify', src, "Nome Curto (TAG) ou de Exibicao invalidos.", "error")
        return
    end

    if GangsCache[gangId] then
        TriggerClientEvent('QBCore:Notify', src, "Este ID/TAG de gangue ja esta em uso no servidor.", "error")
        return
    end

    local currentBankBalance = Player.Functions.GetMoney(Config.AccountType)
    if currentBankBalance < Config.CreationCost then
        TriggerClientEvent('QBCore:Notify', src, "Saldo insuficiente na sua conta bancaria pessoal.", "error")
        return
    end

    if Player.Functions.RemoveMoney(Config.AccountType, Config.CreationCost, "ugw-gang-creation") then
        local currentTimestamp = os.date('%Y-%m-%d %H:%M:%S')
        
        -- CORREÇÃO: Usando MySQL.update para tabelas com chave primária baseada em TEXTO (Retorna contagem de linhas aficadas)
        MySQL.update('INSERT INTO ugw_gangs (gang_name, label, type, created_by, last_active) VALUES (?, ?, ?, ?, ?)', {
            gangId, gangLabel, 'player', Player.PlayerData.citizenid, currentTimestamp
        }, function(rowsChanged)
            if rowsChanged and rowsChanged > 0 then
                -- Atualiza a tabela players vinculando a nova facção
                MySQL.update('UPDATE players SET ugw_gang = ?, ugw_gang_grade = 3 WHERE citizenid = ?', {
                    gangId, Player.PlayerData.citizenid
                })
                
                -- Atualização local do player e inclusão no Cache global do servidor
                Player.PlayerData.ugw_gang = gangId
                Player.PlayerData.ugw_gang_grade = 3
                
                GangsCache[gangId] = {
                    label = gangLabel,
                    type = 'player',
                    funds = 0,
                    logo_url = nil,
                    last_active = currentTimestamp
                }
                
                TriggerClientEvent('QBCore:Notify', src, "Organizacao '" .. gangLabel .. "' registrada com sucesso!", "success")
                TriggerClientEvent('ugw_gangs:client:forceCloseUi', src)
            else
                -- Reembolsa o jogador caso a inserção falhe por motivos externos
                Player.Functions.AddMoney(Config.AccountType, Config.CreationCost, "ugw-gang-creation-refund")
                TriggerClientEvent('QBCore:Notify', src, "Erro interno ao processar a criacao. Valor reembolsado.", "error")
            end
        end)
    end
end)

-- =========================================================================
-- [5. CORE DO DASHBOARD GERAL (/MENUGANG)]
-- =========================================================================
QBCore.Commands.Add('menugang', 'Abrir o painel da sua organizacao', {}, false, function(source)
    local src = source
    RefreshPlayerDashboard(src)
end, 'user')

-- =========================================================================
-- [6. MOVIMENTAÇÃO FINANCEIRA DO COFRE]
-- =========================================================================
RegisterNetEvent('ugw_gangs:server:manageFunds', function(action, amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local gangName = Player.PlayerData.ugw_gang
    local myGrade = Player.PlayerData.ugw_gang_grade
    if gangName == "none" or not GangsCache[gangName] then return end
    
    amount = tonumber(amount)
    if not amount or amount <= 0 then return end
    
    if action == "deposit" then
        if Player.Functions.GetMoney(Config.AccountType) >= amount then
            if Player.Functions.RemoveMoney(Config.AccountType, amount, "ugw-gang-deposit") then
                GangsCache[gangName].funds = GangsCache[gangName].funds + amount
                MySQL.update('UPDATE ugw_gangs SET funds = funds + ? WHERE gang_name = ?', {amount, gangName}, function()
                    TriggerClientEvent('QBCore:Notify', src, "Depositou $" .. amount .. " no cofre da organizacao.", "success")
                    RefreshPlayerDashboard(src)
                end)
            end
        else
            TriggerClientEvent('QBCore:Notify', src, "Saldo bancario pessoal insuficiente.", "error")
        end
    elseif action == "withdraw" then
        local permissions = Config.Grades[myGrade]
        if not permissions or not permissions.canWithdraw then
            TriggerClientEvent('QBCore:Notify', src, "Seu cargo nao tem permissao para realizar saques.", "error")
            return
        end
        
        if GangsCache[gangName].funds >= amount then
            GangsCache[gangName].funds = GangsCache[gangName].funds - amount
            MySQL.update('UPDATE ugw_gangs SET funds = funds - ? WHERE gang_name = ?', {amount, gangName}, function()
                Player.Functions.AddMoney(Config.AccountType, amount, "ugw-gang-withdraw")
                TriggerClientEvent('QBCore:Notify', src, "Retirou $" .. amount .. " do cofre da organizacao.", "success")
                RefreshPlayerDashboard(src)
            end)
        else
            TriggerClientEvent('QBCore:Notify', src, "O cofre da organizacao nao possui fundos suficientes.", "error")
        end
    end
end)

-- =========================================================================
-- [7. GERENCIAMENTO E MODERAÇÃO DE MEMBROS]
-- =========================================================================
RegisterNetEvent('ugw_gangs:server:executeMemberAction', function(action, targetId, targetCitizenId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not Config.Grades[Player.PlayerData.ugw_gang_grade].canPromote then return end
    
    local gangName = Player.PlayerData.ugw_gang
    local myGrade = Player.PlayerData.ugw_gang_grade
    
    if targetId and tonumber(targetId) > 0 then
        local TargetPlayer = QBCore.Functions.GetPlayer(tonumber(targetId))
        if TargetPlayer and TargetPlayer.PlayerData.ugw_gang == gangName then
            local targetGrade = TargetPlayer.PlayerData.ugw_gang_grade
            
            if action == "promote" and targetGrade < 3 and (myGrade > targetGrade + 1 or myGrade == 3) then
                TargetPlayer.PlayerData.ugw_gang_grade = targetGrade + 1
                MySQL.update('UPDATE players SET ugw_gang_grade = ugw_gang_grade + 1 WHERE citizenid = ?', {TargetPlayer.PlayerData.citizenid})
                TriggerClientEvent('QBCore:Notify', TargetPlayer.PlayerData.source, "Voce foi promovido dentro da sua organizacao.", "success")
            elseif action == "demote" and targetGrade > 0 and myGrade > targetGrade then
                TargetPlayer.PlayerData.ugw_gang_grade = targetGrade - 1
                MySQL.update('UPDATE players SET ugw_gang_grade = ugw_gang_grade - 1 WHERE citizenid = ?', {TargetPlayer.PlayerData.citizenid})
                TriggerClientEvent('QBCore:Notify', TargetPlayer.PlayerData.source, "Voce foi rebaixado dentro da sua organizacao.", "error")
            elseif action == "kick" and myGrade > targetGrade then
                TargetPlayer.PlayerData.ugw_gang = "none"
                TargetPlayer.PlayerData.ugw_gang_grade = 0
                MySQL.update('UPDATE players SET ugw_gang = "none", ugw_gang_grade = 0 WHERE citizenid = ?', {TargetPlayer.PlayerData.citizenid})
                TriggerClientEvent('QBCore:Notify', TargetPlayer.PlayerData.source, "Voce foi expulso da organizacao.", "error")
                TriggerClientEvent('ugw_gangs:client:forceCloseUi', TargetPlayer.PlayerData.source)
            end
        end
    elseif targetCitizenId then
        MySQL.prepare('SELECT ugw_gang, ugw_gang_grade FROM players WHERE citizenid = ?', {targetCitizenId}, function(res)
            if res and res.ugw_gang == gangName then
                local currentTargetGrade = res.ugw_gang_grade
                if action == "promote" and currentTargetGrade < 3 and (myGrade > currentTargetGrade + 1 or myGrade == 3) then
                    MySQL.update('UPDATE players SET ugw_gang_grade = ugw_gang_grade + 1 WHERE citizenid = ?', {targetCitizenId})
                elseif action == "demote" and currentTargetGrade > 0 and myGrade > currentTargetGrade then
                    MySQL.update('UPDATE players SET ugw_gang_grade = ugw_gang_grade - 1 WHERE citizenid = ?', {targetCitizenId})
                elseif action == "kick" and myGrade > currentTargetGrade then
                    MySQL.update('UPDATE players SET ugw_gang = "none", ugw_gang_grade = 0 WHERE citizenid = ?', {targetCitizenId})
                end
            end
        end)
    end
    SetTimeout(200, function() RefreshPlayerDashboard(src) end)
end)

RegisterNetEvent('ugw_gangs:server:invitePlayer', function(targetId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not Config.Grades[Player.PlayerData.ugw_gang_grade].canInvite then return end
    
    local gangName = Player.PlayerData.ugw_gang
    local gangLabel = GangsCache[gangName].label
    local TargetPlayer = QBCore.Functions.GetPlayer(tonumber(targetId))
    
    if TargetPlayer and TargetPlayer.PlayerData.ugw_gang == "none" then
        TriggerClientEvent('QBCore:Notify', src, "Convite enviado com sucesso.", "success")
        TriggerClientEvent('ugw_gangs:client:receiveInvite', TargetPlayer.PlayerData.source, gangName, gangLabel, src)
    else
        TriggerClientEvent('QBCore:Notify', src, "Jogador indisponivel ou ja possui organizacao.", "error")
    end
end)

RegisterNetEvent('ugw_gangs:server:respondToInvite', function(gangName, leaderSource, accepted)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or Player.PlayerData.ugw_gang ~= "none" then return end
    
    if accepted then
        if GangsCache[gangName] then
            MySQL.scalar('SELECT COUNT(*) FROM players WHERE ugw_gang = ?', {gangName}, function(membersCount)
                if GangsCache[gangName].type == "player" and membersCount >= Config.MaxMembersPerGang then
                    TriggerClientEvent('QBCore:Notify', src, "Esta organizacao ja atingiu o limite de membros permitido.", "error")
                    if QBCore.Functions.GetPlayer(leaderSource) then
                        TriggerClientEvent('QBCore:Notify', leaderSource, "O candidato nao pôde entrar porque a gangue está lotada.", "error")
                    end
                    return
                end
                
                Player.PlayerData.ugw_gang = gangName
                Player.PlayerData.ugw_gang_grade = 0
                MySQL.update('UPDATE players SET ugw_gang = ?, ugw_gang_grade = 0 WHERE citizenid = ?', {gangName, Player.PlayerData.citizenid})
                TriggerClientEvent('QBCore:Notify', src, "Voce agora faz parte de: " .. GangsCache[gangName].label, "success")
                
                if QBCore.Functions.GetPlayer(leaderSource) then
                    TriggerClientEvent('QBCore:Notify', leaderSource, Player.PlayerData.charinfo.firstname .. " aceitou o seu convite.", "success")
                    RefreshPlayerDashboard(leaderSource)
                end
            end)
        end
    elseif QBCore.Functions.GetPlayer(leaderSource) then
        TriggerClientEvent('QBCore:Notify', leaderSource, "O jogador recusou o convite de entrada.", "error")
    end
end)

-- =========================================================================
-- [8. ABA DE ADMINISTRAÇÃO DE LIDERANÇA (GRADE 3)]
-- =========================================================================
RegisterNetEvent('ugw_gangs:server:saveLeaderSettings', function(newLabel, newLogoUrl)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or Player.PlayerData.ugw_gang_grade < 3 then return end
    
    local gangName = Player.PlayerData.ugw_gang
    if gangName == "none" or not GangsCache[gangName] then return end
    
    newLabel = tostring(newLabel)
    newLogoUrl = tostring(newLogoUrl)
    
    -- Atualiza no cache do servidor
    GangsCache[gangName].label = newLabel
    GangsCache[gangName].logo = newLogoUrl
    
    -- Salva as novas configurações na database (padrão oxmysql moderno)
    MySQL.update('UPDATE ugw_gangs SET label = ?, logo_url = ? WHERE gang_name = ?', {newLabel, newLogoUrl, gangName}, function(rowsChanged)
        if rowsChanged > 0 then
            TriggerClientEvent('QBCore:Notify', src, "Configuracoes da organizacao salvas com sucesso.", "success")
            RefreshPlayerDashboard(src)
        else
            TriggerClientEvent('QBCore:Notify', src, "Nenhuma alteracao foi feita ou erro ao salvar.", "error")
        end
    end)
end)
