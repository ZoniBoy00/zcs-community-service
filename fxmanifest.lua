fx_version 'cerulean'
game 'gta5'

name 'zcs_community_service'
description 'ESX Community Service Script with OX Framework Support'
author 'ZoniBoy00'
version '1.0.1'

shared_scripts {
'@es_extended/imports.lua',
'@ox_lib/init.lua',
'shared/locales.lua',
'shared/locations.lua',
'shared/config.lua'
}

client_scripts {
'client/menu.lua',
'client/main.lua'
}

server_scripts {
'@oxmysql/lib/MySQL.lua',
'server/version_checker.lua',
'server/security.lua',
'server/discord_logs.lua',
'server/zcs_belongings.lua',
'server/main.lua'
}

dependencies {
'es_extended',
'ox_lib',
'ox_target',
'ox_inventory',
'oxmysql'
}

lua54 'yes'

