Config = {}

Config.Tablets = {
    ['tablet_basic'] = {
        label = "Starý Tablet (v1.0)",
        os = "retro",          -- Typ vzhledu: 'retro' nebo 'modern'
        storage = 512,         -- Kapacita v MB (pro instalaci aplikací)
        bootTime = 4000,       -- Jak dlouho startuje (ms)
        wallpaper = "none"     -- Retro nemá tapety
    },
    ['tablet_pro'] = {
        label = "iFruit Pad Pro",
        os = "modern",
        storage = 10240,       -- 10 GB
        bootTime = 1000,       -- Rychlý start
        wallpaper = "https://files.catbox.moe/w8s1z6.jpg"
    }
}

-- Seznam aplikací, které jsou v OS "předinstalované" a nejdou smazat
Config.SystemApps = { 'settings', 'store', 'calendar' }