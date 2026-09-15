Config = {}

-- =========================================================================
-- [CONFIGURAÇÕES DE CRIAÇÃO DINÂMICA]
-- =========================================================================

-- Custo financeiro para registrar uma nova organização através do /criargang
Config.CreationCost = 50000          

-- Tipo de conta onde o valor da criação e movimentações bancárias serão retirados
-- Opções comuns do QBCore: 'bank' (banco) ou 'cash' (dinheiro na mão)
Config.AccountType = "bank"          

-- Limite máximo de jogadores permitidos em uma organização criada por players
Config.MaxMembersPerGang = 30        


-- =========================================================================
-- [CICLO DE VIDA E INATIVIDADE (AUTO-DELETE)]
-- =========================================================================

-- Tempo limite (em horas) em que uma organização 'player' pode ficar com 0 membros online
-- Se estourar este prazo sem ninguém logar simultaneamente, a gangue sofre WIPE automático
Config.InactivityLimit = 72          

-- Intervalo (em minutos) em que o servidor executará a verificação de inatividade no banco
Config.CronCheckInterval = 60        


-- =========================================================================
-- [ORGANIZAÇÕES FIXAS DO SERVIDOR]
-- =========================================================================

-- Estas organizações são inseridas por padrão e protegidas contra o sistema de wipe
Config.FixedGangs = {
    ["lei"] = {
        label = "Corporação da Lei",
        -- Placeholder para coordenadas futuras (Entrada da base, cofre, etc.)
        baseCoords = vec3(425.12, -979.54, 30.71) 
    },
    ["crime"] = {
        label = "Sindicato do Crime",
        baseCoords = vec3(-112.43, 982.11, 25.43)
    }
}


-- =========================================================================
-- [HIERARQUIA E PERMISSÕES INTERNAS]
-- =========================================================================

-- Níveis hierárquicos (ugw_gang_grade) que serão lidos pelo painel de gerenciamento
Config.Grades = {
    [0] = { 
        name = "Recruta", 
        canWithdraw = false, -- Pode sacar dinheiro do cofre?
        canInvite = false,    -- Pode convidar novos jogadores?
        canPromote = false,   -- Pode gerenciar cargos/expulsar?
    },
    [1] = { 
        name = "Membro",  
        canWithdraw = false, 
        canInvite = false,  
        canPromote = false, 
    },
    [2] = { 
        name = "Sub-Líder", 
        canWithdraw = true,  
        canInvite = true,   
        canPromote = true,  
    },
    [3] = { 
        name = "Líder",     
        canWithdraw = true,  
        canInvite = true,   
        canPromote = true,  
        -- Nota: Apenas a Grade 3 (Líder) terá acesso visual à Aba de Administração NUI
    },
}
