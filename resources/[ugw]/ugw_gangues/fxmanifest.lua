fx_version 'cerulean'
game 'gta5'

author 'HanzoBR'
description 'Sistema exclusivo e autonomo de gerenciamento de gangs'
version '1.0.0'

-- Compartilha as configuracoes globais entre Cliente e Servidor simultaneamente
shared_script 'config.lua'

-- Define o arquivo de execucao no lado do Cliente
client_script 'client.lua'

-- Define o arquivo de execucao no lado do Servidor
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua'
}

-- Aponta a pagina principal da interface visual (NUI)
ui_page 'html/index.html'

-- Declara todos os arquivos da interface que o FiveM precisa carregar na memoria
files {
    'html/index.html',
    'html/css.css',
    'html/script.js'
}
