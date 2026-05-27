fx_version 'cerulean'
game 'gta5'

author 'Realplay Scripts'
description 'Advanced Admin Logging — Auto-Detection, Website API, In-Game Report UI'
version '3.0.0'

lua54 'yes'

shared_scripts {
    'shared/config.lua',
}

server_scripts {
    'server/api.lua',       -- Website API (loads first — exports used by others)
    'server/main.lua',      -- Core pipeline, player snapshots, heartbeat
    'server/hooks.lua',     -- Tracked command interception
    'server/scanner.lua',   -- Auto-detection engine (txAdmin, vMenu, ESX, QBCore, etc.)
}

client_scripts {
    'client/main.lua',
    'client/ui.lua',
}

ui_page 'ui/html/index.html'

files {
    'ui/html/index.html',
}

dependencies {
    '/server:5702',
    '/onesync',
}
