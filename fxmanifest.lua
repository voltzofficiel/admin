fx_version 'cerulean'
game 'gta5'

lua54 'yes'

shared_scripts {
    'config.lua'
}

client_scripts {
    '@RageUI/src/RMenu.lua',
    '@RageUI/src/Menu.lua',
    '@RageUI/src/MenuController.lua',
    '@RageUI/src/components/*.lua',
    '@RageUI/src/menus/*.lua',
    '@RageUI/src/items/*.lua',
    'client/main.lua'
}

server_scripts {
    'server/main.lua'
}
