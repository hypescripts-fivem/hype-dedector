fx_version 'cerulean'
game { 'gta5' }

author 'vezironi'
description 'Walk-through metal detectors with an admin menu'

scriptname 'hype-dedector'
version '1.0.0'

dependencies {
    'ox_lib',
    'oxmysql',
}

shared_scripts {
    '@ox_lib/init.lua',
    'shared/utils.lua',
    'shared/detection.lua',
    'shared/main.lua',
    'frameworks/main.lua',
    'modules/main.lua',
}

client_scripts {
    'frameworks/**/cl-*.lua',
    'modules/**/cl-*.lua',
    'client/*.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'frameworks/**/sv-*.lua',
    'modules/**/sv-*.lua',
    'server/*.lua',
}

escrow_ignore {
    'config/*.lua',
    'frameworks/**/*.lua',
    'modules/**/*.lua',
    'locales/*.json',
    'INSTALL/*.sql',
}

-- config/sv-config.lua is left out on purpose: it holds the webhook and must stay on the server
files {
    'config/config.lua',
    'shared/*.lua',
    'locales/*.json',
    'web/dist/*.*',
    'web/dist/**/*.*',
}

ui_page 'web/dist/index.html'

lua54 'yes'
use_experimental_fxv2_oal 'yes'

-- Hand detector prop
data_file 'DLC_ITYP_REQUEST' 'stream/props/hype_hand_dedector.ytyp'
