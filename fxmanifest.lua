fx_version "cerulean"
lua54 'yes'

author 'SpoiledMouse'
version '1.0.1'
description 'aprts_tablet'

games {"gta5"}

ui_page 'html/index.html'

files {
    'html/index.html',
    
    -- Styly
    'html/css/core.css',
    'html/css/modern.css',
    'html/css/retro.css',
    
    -- Scripty (pozor na pořadí)
    'html/js/state.js',
    'html/js/ui.js',
    'html/js/system.js',
    'html/js/main.js',
    
    'html/images/*.png',
    'html/images/*.jpg'
}
shared_script 'config.lua'
client_script 'client.lua'
server_script 'server.lua'
exports {
    'RegisterApp'
}