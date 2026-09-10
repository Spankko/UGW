fx_version 'cerulean'
game 'gta5'
dependency 'qb-core'
dependency 'oxmysql'
author 'Gustavo Spankko & HanzoBR'
description 'Sistema Integrado de Territórios, Gangues e Interface - UGW'
version '1.1.0'

shared_script 'turfs.lua'

client_script 'client.lua'

server_script '@oxmysql/lib/MySQL.lua'
server_script 'server.lua'

ui_page 'html/index.html'

files {
    'html/index.html'
}