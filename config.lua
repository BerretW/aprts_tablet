Config = {}

-- config.lua
Config.Tablets = {
    -- 1. Starý "Basic" tablet (Retro vzhled)
    ['tablet_basic'] = {
        label = "Nokia Tab 3310",
        os = "retro", -- Unikátní ID systému
        storage = 512,
        bootTime = 3000,
        wallpaper = "none"
    },

    -- 2. Levný moderní tablet (Starší OS)
    ['tablet_air'] = {
        label = "iFruit Air (2020)",
        os = "Apparatus_1", -- Starší verze OS
        storage = 1024, -- Málo místa
        bootTime = 2000,
        wallpaper = "https://files.catbox.moe/w8s1z6.jpg"
    },

    -- 3. Nejnovější tablet (Nový OS + Hodně místa)
    ['tablet_pro'] = {
        label = "iFruit Pro X (2024)",
        os = "Apparatus_2", -- Nová verze OS (vyžadovaná pro nové appky)
        storage = 8192, -- Hodně místa
        bootTime = 1000,
        wallpaper = "https://files.catbox.moe/k9d8s1.jpg"
    },
    
    -- 4. Hacker Tablet (Speciální OS)
    ['tablet_hacker'] = {
        label = "DarkNet Pad",
        os = "kali_os",
        storage = 4096,
        bootTime = 500,
        wallpaper = "https://files.catbox.moe/hacker_bg.jpg"
    }
}

Config.SystemApps = { 'settings', 'store', 'calendar' }
Config.RouterTypes = {
    ['router_basic'] = {
        prop = 'hei_prop_server_piece_01',
        range = 15.0,
        label = "Základní Router"
    },
    ['router_advanced'] = {
        prop = 'hei_prop_server_piece_01', -- Příklad jiného modelu
        range = 40.0,
        label = "Profi Router"
    }
}
-- Wi-Fi Zóny
-- Pokud je hráč mimo tyto zóny, tablet nebude mít internet (Store nebude fungovat)
Config.WifiZones = {
    {
        label = "Public Library",
        coords = vector3(216.96, -238.15, 53.96),
        radius = 50.0,
        strength = "strong",
        password = "775695905" -- VEŘEJNÁ (připojí se sama)
    },
    {
        label = "Police Station",
        coords = vector3(441.87, -981.93, 30.69),
        radius = 80.0,
        strength = "medium",
        password = "pd_secure" -- ZAMČENÁ (bude chtít heslo)
    },
    {
        label = "Mechanic Shop",
        coords = vector3(-347.26, -133.31, 39.01),
        radius = 40.0,
        strength = "weak",
        password = "fix" -- ZAMČENÁ
    },
    {
        label = "Downtown Cafe",
        coords = vector3(-1136.22, -1964.65, 17.24),
        radius = 30.0,
        strength = "strong",
        password = nil -- VEŘEJNÁ
    }
}

-- Baterie
Config.BatteryDrainRate = 0.5  -- Kolik % ubude každých X sekund (když je otevřený)
Config.BatteryChargeRate = 2.0 -- Rychlost nabíjení
Config.BatteryTick = 5000     
Config.HistoryInterval = 30

-- Definice nabíjecích míst (statické souřadnice)
Config.ChargerLocations = {
    vector3(441.25, -982.50, 30.69), -- Police Station
    vector3(-1082.0, -247.5, 37.76), -- Lifeinvader
}

-- (Volitelné) Modely, na které lze kliknout přes Target
Config.ChargerModels = {
    'prop_pc_01a',      -- PC bedna
    'prop_wall_light_06a', -- Světlo/Zásuvka
    'v_res_tre_console', -- Herní konzole
    -- Přidej další modely dle libosti
}