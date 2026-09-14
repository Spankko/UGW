fx_version 'cerulean'
game 'gta5'

author 'Gustavo Spankko & HanzoBR'
description 'Gerenciamento Exclusivo de Propriedades e Rendimento'
version '1.0.0'

shared_scripts {
    '@qb-core/shared/locale.lua',
    'properties.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}