# DOCUMENTO DE REQUISITOS DO PRODUTO (PRD)
## Sistema de Organizações Autônomo (ugw_gangs)

---

### 1. VISÃO GERAL DO PRODUTO
O ugw_gangs é um ecossistema completo e autônomo de gerenciamento de organizações para servidores QBCore, projetado para operar com zero dependência do sistema nativo de gangues do framework. O sistema introduz uma dinâmica híbrida baseada em duas organizações fixas do servidor (LEI e CRIME) e organizações dinâmicas criadas por jogadores, que possuem um mecanismo inteligente de exclusão por inatividade para evitar o acúmulo de dados obsoletos no banco de dados.

#### Objetivos Principais
* Isolamento do QBCore: Manter todos os jogadores com o status nativo de gangue como "none" no core, transferindo todo o controle de dados, cargos e acessos para tabelas exclusivas do ugw.
* Persistência Baseada em Banco de Dados: Registro de criação, membros, cargos e economia gerenciado puramente via MySQL.
* Ciclo de Vida Dinâmico: Automatizar o ciclo de vida das organizações criadas por jogadores através de um cronômetro atrelado estritamente à presença simultânea de membros online (Contador Online: 0).

---

### 2. ESTRUTURA DO BANCO DE DADOS (SQL)
O sistema utilizará duas modificações principais no banco de dados para operar de forma isolada.

#### 2.1. Alteração na Tabela Nativa 'players'
Devem ser adicionadas duas novas colunas para rastrear o vínculo do personagem sem interferir no metadado original do QBCore.
* ugw_gang (VARCHAR, padrão "none"): ID curto / TAG da organização à qual o jogador pertence.
* ugw_gang_grade (INT, padrão 0): Nível hierárquico do jogador dentro da organização (ex: 0 a 3).

#### 2.2. Nova Tabela 'ugw_gangs'
Armazena os dados mestre de todas as organizações ativas no servidor.

```sql
CREATE TABLE IF NOT EXISTS `ugw_gangs` (
  `gang_name` VARCHAR(50) NOT NULL,
  `label` VARCHAR(100) NOT NULL,
  `type` ENUM('fixed', 'player') NOT NULL DEFAULT 'player',
  `funds` INT(11) NOT NULL DEFAULT 0,
  `logo_url` LONGTEXT DEFAULT NULL,
  `created_by` VARCHAR(50) NOT NULL DEFAULT 'system',
  `last_active` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`gang_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

#### Registro Inicial Obrigatório (Seed)
O arquivo de instalação .sql deve obrigatoriamente pré-encher as organizações fixas:
```sql
INSERT INTO `ugw_gangs` (`gang_name`, `label`, `type`, `created_by`) VALUES 
('lei', 'Corporação da Lei', 'fixed', 'system'),
('crime', 'Sindicato do Crime', 'fixed', 'system');
```

---

### 3. CONFIGURAÇÕES GLOBAIS (config.lua)
O arquivo de configuração do servidor deve centralizar os parâmetros de custos, temporizadores e metadados das organizações fixas.

```lua
Config = {}

-- Parâmetros de Criação Dinâmica
Config.CreationCost = 50000          -- Custo em dólares para criar uma organização
Config.AccountType = "bank"          -- Tipo de conta para débito ("bank" ou "cash")
Config.MaxMembersPerGang = 30        -- Limite de membros para gangues do tipo 'player'

-- Regras de Inatividade (Auto-Delete)
Config.InactivityLimit = 72          -- Tempo limite em horas com 0 membros online para exclusão
Config.CronCheckInterval = 60        -- Intervalo em minutos para o servidor rodar a checagem de wipe

-- Definições Hierárquicas Padrão
Config.Grades = {
    [0] = { name = "Recruta", canWithdraw = false, canInvite = false, canPromote = false },
    [1] = { name = "Membro",  canWithdraw = false, canInvite = false, canPromote = false },
    [2] = { name = "Sub-Líder", canWithdraw = true,  canInvite = true,  canPromote = true },
    [3] = { name = "Líder",     canWithdraw = true,  canInvite = true,  canPromote = true }, -- Possui aba Admin NUI
}
```

---

### 4. ARQUITETURA DE RECURSOS E FUNCIONALIDADES

#### 4.1. Fluxo de Criação (/criargang)
* Validação de Estado: Ao executar o comando, o servidor checa se o jogador já possui uma organização atribuída na coluna ugw_gang. Se possuir, o comando bloqueia a abertura da interface de registro.
* Interface NUI (Registro): Apresenta uma tela limpa contendo os campos de input: Nome Curto (TAG / ID) (Ex: racing) e Nome de Exibição (Label) (Ex: Racing Club), além do marcador de custo baseado no Config.CreationCost.
* Processamento de Pagamento: O script consome o saldo bancário usando a função nativa do QBCore (Player.Functions.RemoveMoney('bank', ...)). O dinheiro em mãos (cash) deve ser explicitamente ignorado.
* Validação de Disponibilidade: O servidor realiza uma query rápida para garantir que o Nome Curto (ID/TAG) escolhido não esteja em uso na tabela ugw_gangs. Caso esteja disponível e o pagamento seja efetuado com sucesso, a linha é inserida na tabela e o jogador que a criou é automaticamente configurado como ugw_gang_grade = 3 (Líder).

#### 4.2. Painel de Gerenciamento Geral (/menugang)
Renderiza o dashboard principal do jogador. A interface deve ser alimentada de maneira dinâmica pelas tabelas do ugw_gangs e apresentar os seguintes blocos:
* Cabeçalho: Nome da Gangue, Nível da Gangue (padrão estático LVL 1) e o Logotipo Dinâmico (caso cadastrado).
* Grid de Status: 
  * Cofre: Exibe o saldo atual da coluna funds.
  * Base / Territórios / Vilas / GZs: Exibição de dados estáticos zerados ou placeholders textuais nesta fase de implementação.
* Lista de Membros: 
  * Listagem contendo Nome do Personagem, Cargo (Config.Grades) e Status (Online/Offline).
  * O indicador de Status calcula na memória do servidor quais IDs de personagens vinculados àquela organização estão ativos na sessão de jogo, exibindo "Online" ou "Offline".
  * Botões de Ação na Lista (Promover, Rebaixar, Expulsar) ficam visíveis ou clicáveis apenas para cargos autorizados no config.lua (Grades 2 e 3).
* Painel Lateral de Ações:
  * Inputs de texto e botões para Depositar (retira do banco do jogador -> adiciona ao cofre) e Sacar (retira do cofre -> adiciona ao banco do jogador, restrito a cargos autorizados).
  * Seção de Convites: O input de ID de jogador deve ser assistido por uma listagem de usuários da sessão atual que estejam com o status de organização definido estritamente como "none".

#### 4.3. Aba de Administração de Liderança (Exclusiva Grade 3)
Um painel interno oculto para membros comuns, liberado unicamente para o dono/líder da organização no menu.
* Input de Logotipo: Campo de texto aberto para inserção de links diretos de imagens (HTTP/HTTPS). O endereço deve ser armazenado na coluna logo_url do banco de dados e repassado para a interface NUI processar a renderização visual do escudo.
* Alterar Identificadores: Permite a redefinição do Nome de Exibição (Label). O Nome Curto (ID / TAG) permanece bloqueado por ser a chave primária relacional do sistema.
* Transferência de Propriedade: Passa a posse da organização para outro membro da lista, alterando o cargo do novo dono para Grade 3 e rebaixando o antigo dono para Grade 2.

#### 4.4. Mecanismo de Sobrevivência e Exclusão Automática (Contador Online: 0)
Esta mecânica desvincula completamente a dependência de colunas de histórico de login dos jogadores, operando diretamente na atividade coletiva da organização através do servidor.
* Funcionamento do Cronjob: O servidor roda um loop a cada x minutos (Config.CronCheckInterval).
* Se Membros Online > 0: O servidor atualiza o campo last_active da gangue para o timestamp atual do sistema, resetando a contagem de inatividade.
* Se Membros Online == 0: O campo last_active permanece congelado. O servidor calcula a diferença de tempo entre o horário atual e o last_active. Se a diferença passar de x horas (Config.InactivityLimit), o processo de Wipe é disparado.
* Processamento de Wipe:
  1. Deleta a linha da organização correspondente na tabela ugw_gangs.
  2. Executa um comando SQL em lote para definir as colunas ugw_gang = "none" e ugw_gang_grade = 0 para todos os personagens vinculados àquela TAG na tabela players.

#### 4.5. Painel de Administração Geral (/admingang)
Comando restrito para a equipe de staff do servidor, validado pela infraestrutura nativa do QBCore (HasPermission). O menu disponibiliza uma interface de gerenciamento global:
* Controle das Gangues Fixas (LEI e CRIME): Permitir que os administradores definam capitães, diretores e comandantes para as facções fixas, além de reabastecer ou auditar os fundos contidos em seus cofres.
* Monitoramento das Gangues Criadas: Apresenta uma tabela unificada com todas as organizações dinâmicas do servidor, listando a quantidade atual de membros e exibindo um contador regressivo do tempo restante de inatividade antes do auto-delete.
* Intervenção Manual (Force Wipe): Botão administrativo para forçar a exclusão imediata de qualquer organização em tempo real, disparando instantaneamente o processo de limpeza de registros no banco de dados e liberando os jogadores afetados.

---
This is for informational purposes only. For medical advice or diagnosis, consult a professional. AI responses may include mistakes.
