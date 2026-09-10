fx_version 'cerulean'
game 'gta5'

description 'UGW Scoreboard - Placar e Estatísticas Permanentes'
author 'Gustavo Spankko & HanzoBR'
version '1.1.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

lua54 'yes'