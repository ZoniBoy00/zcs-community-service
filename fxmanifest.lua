fx_version 'cerulean'
game 'gta5'

name 'zcs_community_service'
description 'QBox Community Service Script'
author 'ZoniBoy00'
version '1.0.2'

shared_scripts {
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
    'qbx_core',
    'ox_lib',
    'ox_target',
    'ox_inventory',
    'oxmysql'
}

lua54 'yes'
