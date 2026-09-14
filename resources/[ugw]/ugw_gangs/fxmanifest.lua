fx_version 'cerulean'
game 'gta5'

author 'Spankko & HanzoBR'
description 'Sistema Integrado de Territórios, Gangues e Interface - UGW'
version '1.2.1'

dependencies {
    'qb-core',
    'oxmysql',
    'PolyZone'
}

shared_scripts {
    'config.lua',
    '@ugw_turfs/turfs.lua'
}

client_scripts {
    '@PolyZone/client.lua',
    '@PolyZone/BoxZone.lua',
    '@PolyZone/EntityZone.lua',
    '@PolyZone/CircleZone.lua',
    '@PolyZone/ComboZone.lua',
    'client.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua'
}

files {
    'html/ui.html',
    'html/style.css',
    'html/script.js'
}

ui_page 'html/ui.html'