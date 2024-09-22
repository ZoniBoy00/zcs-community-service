fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'ZoniBoy00'
description 'Z_CommunityService'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/*.lua'
}

client_scripts {
    'client/*.lua'
}

server_scripts {
    'server/*.lua'
}

dependencies {
    'ox_lib'
}