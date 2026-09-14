local QBCore = exports['qb-core']:GetCoreObject()

-- ==========================================
-- INICIALIZAÇÃO DO BANCO DE DADOS 
-- ==========================================
MySQL.ready(function()
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS `gang_funds` (
            `gang_name` VARCHAR(50) PRIMARY KEY,
            `amount` INT(11) DEFAULT 0
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS `dynamic_gangs` (
            `gang_name` VARCHAR(50) PRIMARY KEY,
            `level` INT(11) DEFAULT 1,
            `kills` INT(11) DEFAULT 0,
            `deaths` INT(11) DEFAULT 0
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS `gang_territories` (
            `id` INT(11) AUTO_INCREMENT PRIMARY KEY,
            `gang_name` VARCHAR(50) NOT NULL,
            `type` VARCHAR(20) NOT NULL,
            `location_name` VARCHAR(100) NOT NULL,
            `coords` LONGTEXT DEFAULT NULL
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS `gang_wars` (
            `id` INT(11) AUTO_INCREMENT PRIMARY KEY,
            `attacker` VARCHAR(50) NOT NULL,
            `defender` VARCHAR(50) NOT NULL,
            `territory_id` INT(11) NOT NULL,
            `attacker_kills` INT(11) DEFAULT 0,
            `defender_kills` INT(11) DEFAULT 0,
            `status` VARCHAR(20) DEFAULT 'active',
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
end)

local ActiveWars = {}

-- ==========================================
-- CALLBACK DE CRIAÇÃO DE GANGUE
-- ==========================================
QBCore.Functions.CreateCallback('ugw_gangs:server:createNewGang', function(source, cb, gangName, gangLabel)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb(false) end

    local creationCost = Config.CreationCost or 50000

    if Player.PlayerData.gang and Player.PlayerData.gang.name ~= "none" then
        TriggerClientEvent('QBCore:Notify', source, "Você já pertence a uma organização!", "error")
        return cb(false)
    end

    local playerCash = Player.PlayerData.money.cash
    local playerBank = Player.PlayerData.money.bank

    if playerCash < creationCost and playerBank < creationCost then
        TriggerClientEvent('QBCore:Notify', source, "Você não possui $" .. creationCost .. " para fundar a equipe.", "error")
        return cb(false)
    end

    -- Desconta o valor
    if playerCash >= creationCost then
        Player.Functions.RemoveMoney('cash', creationCost, "gang-creation")
    else
        Player.Functions.RemoveMoney('bank', creationCost, "gang-creation")
    end

    -- 1. REGISTRA A GANGUE DINAMICAMENTE NO QBCORE
    QBCore.Shared.Gangs[gangName] = {
        label = gangLabel,
        grades = {
            ['0'] = { name = 'Recruta' },
            ['1'] = { name = 'Membro' },
            ['2'] = { name = 'Sub-Líder' },
            ['3'] = { name = 'Líder', isboss = true }
        }
    }

    -- 2. SETA O JOGADOR COMO LÍDER E ATUALIZA O CLIENTE
    Player.Functions.SetGang(gangName, 3)
    TriggerClientEvent('QBCore:Client:OnGangUpdate', source, Player.PlayerData.gang)

    -- 3. SALVA NO BANCO DE DADOS
    local gangObject = {
        name = gangName,
        label = gangLabel,
        isboss = true,
        grade = { level = 3, name = "Líder" }
    }

    MySQL.Async.execute('UPDATE players SET gang = ? WHERE citizenid = ?', {json.encode(gangObject), Player.PlayerData.citizenid})
    MySQL.Async.execute('INSERT INTO dynamic_gangs (gang_name, level, kills, deaths) VALUES (?, 1, 0, 0) ON DUPLICATE KEY UPDATE gang_name = gang_name', {gangName})
    MySQL.Async.execute('INSERT INTO gang_funds (gang_name, amount) VALUES (?, 0) ON DUPLICATE KEY UPDATE gang_name = gang_name', {gangName})

    TriggerClientEvent('QBCore:Notify', source, "Organização '" .. gangLabel .. "' fundada com sucesso!", "success")

    local newGangData = {
        hasGang = true,
        name = gangName,
        label = gangLabel,
        money = 0,
        level = 1,
        kills = 0,
        deaths = 0,
        playerGrade = 3,
        baseId = "Nenhuma",
        turfs = 0,
        vilas = 0,
        gzs = 0,
        members = {
            {
                citizenid = Player.PlayerData.citizenid,
                name = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname,
                grade = 3,
                gradeName = "Líder",
                isOnline = true
            }
        },
        territories = {}
    }

    cb(true, newGangData)
end)

-- ==========================================
-- CALLBACK DE DADOS PARA O PAINEL (/painelgangue)
-- ==========================================
QBCore.Functions.CreateCallback('ugw_gangs:server:getGangData', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb({ hasGang = false }) end

    local gangName = Player.PlayerData.gang and Player.PlayerData.gang.name

    -- Fallback: Se na sessão do servidor constar "none", busca direto na tabela players do banco de dados
    if not gangName or gangName == "none" then
        local dbGang = MySQL.Sync.fetchScalar('SELECT JSON_EXTRACT(gang, "$.name") FROM players WHERE citizenid = ?', {Player.PlayerData.citizenid})
        if dbGang and dbGang ~= "none" then
            gangName = dbGang:gsub('"', '') -- Remove aspas da string retornada pelo JSON
        end
    end

    if not gangName or gangName == "none" then 
        return cb({ hasGang = false }) 
    end

    local gangLabel = (Player.PlayerData.gang and Player.PlayerData.gang.label) or gangName
    local playerGrade = (Player.PlayerData.gang and Player.PlayerData.gang.grade and Player.PlayerData.gang.grade.level) or 3

    local fundResult = MySQL.Sync.fetchScalar('SELECT amount FROM gang_funds WHERE gang_name = ?', {gangName})
    local bankBalance = fundResult or 0

    local members = {}
    local players = MySQL.Sync.fetchAll('SELECT citizenid, charinfo, gang FROM players WHERE JSON_EXTRACT(gang, "$.name") = ?', {gangName})

    for _, v in ipairs(players) do
        local charinfo = json.decode(v.charinfo or '{}')
        local gangData = json.decode(v.gang or '{}')
        local targetPlayer = QBCore.Functions.GetPlayerByCitizenId(v.citizenid)

        local mGrade = (gangData.grade and gangData.grade.level) or 0
        local mGradeName = (gangData.grade and gangData.grade.name) or "Membro"

        table.insert(members, {
            citizenid = v.citizenid,
            name = (charinfo.firstname or 'Membro') .. ' ' .. (charinfo.lastname or ''),
            grade = mGrade,
            gradeName = mGradeName,
            isOnline = targetPlayer ~= nil
        })
    end

    local territories = MySQL.Sync.fetchAll('SELECT id, type, location_name FROM gang_territories WHERE gang_name = ?', {gangName})
    local gangStats = MySQL.Sync.fetchSingle('SELECT level, kills, deaths FROM dynamic_gangs WHERE gang_name = ?', {gangName}) or { level = 1, kills = 0, deaths = 0 }

    local totalTurfs = #territories
    local totalVilas = 0
    local totalGzs = 0

    for _, t in ipairs(territories) do
        if t.type == 'Vila' or t.type == 'vila' then
            totalVilas = totalVilas + 1
        elseif t.type == 'GZ' or t.type == 'gz' then
            totalGzs = totalGzs + 1
        end
    end

    cb({
        hasGang = true,
        name = gangName,
        label = gangLabel,
        money = bankBalance,
        level = gangStats.level or 1,
        kills = gangStats.kills or 0,
        deaths = gangStats.deaths or 0,
        playerGrade = playerGrade,
        baseId = "Nenhuma",
        turfs = totalTurfs,
        vilas = totalVilas,
        gzs = totalGzs,
        members = members,
        territories = territories
    })
end)

-- ==========================================
-- SISTEMA FINANCEIRO E MEMBROS
-- ==========================================

RegisterNetEvent('ugw_gangs:server:depositMoney', function(amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local amount = tonumber(amount)

    if Player and amount and amount > 0 and Player.PlayerData.money.cash >= amount then
        local gangName = Player.PlayerData.gang.name
        if gangName ~= "none" then
            Player.Functions.RemoveMoney('cash', amount, "gang-deposit")
            MySQL.Async.execute('INSERT INTO gang_funds (gang_name, amount) VALUES (?, ?) ON DUPLICATE KEY UPDATE amount = amount + ?', {gangName, amount, amount})
            TriggerClientEvent('QBCore:Notify', src, "Depósito de $"..amount.." realizado!", "success")
            TriggerClientEvent('ugw_gangs:client:refreshPanel', src)
        end
    else
        TriggerClientEvent('QBCore:Notify', src, "Dinheiro em mãos insuficiente.", "error")
    end
end)

RegisterNetEvent('ugw_gangs:server:withdrawMoney', function(amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local amount = tonumber(amount)

    if Player and amount and amount > 0 then
        local gangName = Player.PlayerData.gang.name
        local isBoss = Player.PlayerData.gang.isboss or (Player.PlayerData.gang.grade and Player.PlayerData.gang.grade.level >= 3)
        if gangName ~= "none" and isBoss then
            local currentBank = MySQL.Sync.fetchScalar('SELECT amount FROM gang_funds WHERE gang_name = ?', {gangName}) or 0
            if currentBank >= amount then
                MySQL.Async.execute('UPDATE gang_funds SET amount = amount - ? WHERE gang_name = ?', {amount, gangName})
                Player.Functions.AddMoney('cash', amount, "gang-withdraw")
                TriggerClientEvent('QBCore:Notify', src, "Saque de $"..amount.." realizado!", "success")
                TriggerClientEvent('ugw_gangs:client:refreshPanel', src)
            else
                TriggerClientEvent('QBCore:Notify', src, "Saldo do cofre insuficiente.", "error")
            end
        else
            TriggerClientEvent('QBCore:Notify', src, "Apenas o líder pode sacar recursos.", "error")
        end
    end
end)

RegisterNetEvent('ugw_gangs:server:promoteMemberByCitizenId', function(citizenId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if Player and (Player.PlayerData.gang.isboss or Player.PlayerData.gang.grade.level >= 3) then
        local target = QBCore.Functions.GetPlayerByCitizenId(citizenId)
        local gangName = Player.PlayerData.gang.name

        if target then
            local currentGrade = target.PlayerData.gang.grade.level
            if currentGrade < 3 then
                target.Functions.SetGang(gangName, currentGrade + 1)
                TriggerClientEvent('QBCore:Notify', target.PlayerData.source, "Você foi promovido!", "success")
                TriggerClientEvent('QBCore:Notify', src, "Membro promovido.", "success")
            end
        else
            local targetData = MySQL.Sync.fetchSingle('SELECT gang FROM players WHERE citizenid = ?', {citizenId})
            if targetData then
                local gData = json.decode(targetData.gang or '{}')
                if gData.grade and gData.grade.level < 3 then
                    gData.grade.level = gData.grade.level + 1
                    MySQL.Async.execute('UPDATE players SET gang = ? WHERE citizenid = ?', {json.encode(gData), citizenId})
                    TriggerClientEvent('QBCore:Notify', src, "Membro offline promovido.", "success")
                end
            end
        end
        TriggerClientEvent('ugw_gangs:client:refreshPanel', src)
    end
end)

RegisterNetEvent('ugw_gangs:server:demoteMemberByCitizenId', function(citizenId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if Player and (Player.PlayerData.gang.isboss or Player.PlayerData.gang.grade.level >= 3) then
        local target = QBCore.Functions.GetPlayerByCitizenId(citizenId)
        local gangName = Player.PlayerData.gang.name

        if target then
            local currentGrade = target.PlayerData.gang.grade.level
            if currentGrade > 0 then
                target.Functions.SetGang(gangName, currentGrade - 1)
                TriggerClientEvent('QBCore:Notify', target.PlayerData.source, "Você foi rebaixado.", "error")
                TriggerClientEvent('QBCore:Notify', src, "Membro rebaixado.", "success")
            end
        else
            local targetData = MySQL.Sync.fetchSingle('SELECT gang FROM players WHERE citizenid = ?', {citizenId})
            if targetData then
                local gData = json.decode(targetData.gang or '{}')
                if gData.grade and gData.grade.level > 0 then
                    gData.grade.level = gData.grade.level - 1
                    MySQL.Async.execute('UPDATE players SET gang = ? WHERE citizenid = ?', {json.encode(gData), citizenId})
                    TriggerClientEvent('QBCore:Notify', src, "Membro offline rebaixado.", "success")
                end
            end
        end
        TriggerClientEvent('ugw_gangs:client:refreshPanel', src)
    end
end)

RegisterNetEvent('ugw_gangs:server:kickMemberByCitizenId', function(citizenId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if Player and (Player.PlayerData.gang.isboss or Player.PlayerData.gang.grade.level >= 3) then
        local target = QBCore.Functions.GetPlayerByCitizenId(citizenId)

        if target then
            target.Functions.SetGang("none", 0)
            TriggerClientEvent('QBCore:Notify', target.PlayerData.source, "Você foi removido da organização.", "error")
        else
            MySQL.Async.execute('UPDATE players SET gang = ? WHERE citizenid = ?', {json.encode({name = "none", label = "No Gang", isboss = false, grade = {level = 0, name = "None"}}), citizenId})
        end
        TriggerClientEvent('QBCore:Notify', src, "Membro removido com sucesso.", "success")
        TriggerClientEvent('ugw_gangs:client:refreshPanel', src)
    end
end)

RegisterNetEvent('ugw_gangs:server:openStash', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if Player and Player.PlayerData.gang.name ~= "none" then
        local gangName = Player.PlayerData.gang.name
        local stashName = 'gangstash_' .. gangName

        TriggerClientEvent('inventory:client:SetCurrentStash', src, stashName)
        TriggerClientEvent('server-inventory-open', src, "1", stashName)
    end
end)