fx_version "cerulean"
lua54 'yes'

author 'SpoiledMouse'
version '1.0.3'
description 'aprts_tablet'

games {"gta5"}

ui_page 'html/index.html'
shared_script '@ox_lib/init.lua'
files {
    'html/libs/chart.min.js',
    'html/libs/sweetalert2.all.min.js',
    'html/libs/animate.min.css',
    'html/libs/all.min.css',
    'html/webfonts/*', 
    'html/index.html',
    
    -- Styly
    'html/css/core.css',
    'html/css/modern.css',
    'html/css/retro.css',
    'html/css/kali.css',
    
    -- Scripty (pozor na pořadí)
    'html/js/state.js',
    'html/js/ui.js',
    'html/js/system.js',
    'html/js/modules/*.js',       -- Načteme všechny moduly
    'html/js/main.js',

    -- Zvuky
    'html/sounds/*.mp3',
    'html/images/*.png',
    'html/images/*.jpg'
}
shared_script 'config.lua'
client_scripts {
    'client/globals.lua',   -- 1. Proměnné
    'client/animation.lua', -- 2. Funkce animací
    'client/battery.lua',   -- 3. Logika nabíjení
    'client/apps.lua',      -- 4. Registrace aplikací
    'client/nui.lua',       -- 5. NUI Callbacky
    'client/wifi.lua',      -- 7. Wi-Fi Logika
    'client/main.lua'       -- 6. Hlavní smyčka a eventy

}
server_script 'server.lua'

exports {
    'RegisterApp',
    'GetTabletData',
    'SetAppBadge',
    'SaveAppData',
    'ConnectCharger',
    'DisconnectCharger',
    'useTablet',
    'SendNui',
    'loadContent'
}