Config = {}

Config.Tablets = {
    ['tablet_basic'] = {
        label = "Starý Tablet (v1.0)",
        os = "retro",
        storage = 512,
        bootTime = 3000,
        wallpaper = "none"
    },
    ['tablet_pro'] = {
        label = "iFruit Pad Pro",
        os = "modern",
        storage = 10240,
        bootTime = 1000,
        wallpaper = "https://files.catbox.moe/w8s1z6.jpg"
    }
}

Config.SystemApps = { 'settings', 'store', 'calendar' }

-- Wi-Fi Zóny
-- Pokud je hráč mimo tyto zóny, tablet nebude mít internet (Store nebude fungovat)
Config.WifiZones = {
    {
        label = "Public Library",
        coords = vector3(216.96, -238.15, 53.96), -- Příklad souřadnic
        radius = 50.0, -- Dosah v metrech
        strength = "strong" -- Pro budoucí využití
    },
    {
        label = "Police Station",
        coords = vector3(441.87, -981.93, 30.69),
        radius = 80.0,
        strength = "medium"
    },
    {
        label = "Mechanic Shop",
        coords = vector3(-347.26, -133.31, 39.01),
        radius = 40.0,
        strength = "weak"
    },
    {
        label = "Downtown Cafe",
        coords = vec3(-1136.22, -1964.65, 17.24),
        radius = 30.0,
        strength = "strong"
    }
    -- Zde si přidej další místa
}

-- Baterie
Config.BatteryDrainRate = 0.5  -- Kolik % ubude každých X sekund (když je otevřený)
Config.BatteryChargeRate = 2.0 -- Rychlost nabíjení
Config.BatteryTick = 5000     
Config.HistoryInterval = 30
-- Nabíjecí stanice (Souřadnice míst, kde se tablet nabíjí)
Config.ChargingStations = {
    vector3(441.25, -982.50, 30.69), -- Police Station (recepce)
    vector3(-1082.0, -247.5, 37.76), -- Lifeinvader
    vector3(228.6, -993.4, -99.5),   -- Příklad interiéru
    -- Přidej si další...
}

 -- Interval

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