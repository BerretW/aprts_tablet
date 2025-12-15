local QBCore = exports['qb-core']:GetCoreObject() -- Pokud QBox jede na QB jádru
-- Pokud je to čistý QBox/Ox, importy mohou být jiné, ale SQL query je univerzální.

-- 1. Příkaz pro admina: Dej mi tablet
RegisterCommand('givetablet', function(source, args)
    local model = args[1] or 'tablet_pro' -- 'tablet_basic' nebo 'tablet_pro'
    local serial = "TAB-" .. math.random(100000, 999999)

    -- Vytvoříme záznam v DB s defaultními daty
    local defaultData = {
        background = (model == 'tablet_pro') and 'https://files.catbox.moe/w8s1z6.jpg' or 'none',
        installedApps = {'store', 'settings', 'calendar'}, -- Základní appky
        settings = {}
    }

    exports.oxmysql:insert('INSERT INTO player_tablets (serial, model, tablet_data) VALUES (?, ?, ?)', {
        serial, model, json.encode(defaultData)
    }, function(id)
        if id then
            -- Přidání do inventáře (OX Inventory syntax)
            exports.ox_inventory:AddItem(source, 'tablet', 1, {
                serial = serial,
                model = model,
                description = "Sériové číslo: " .. serial
            })
            print('Tablet vytvořen: ' .. serial)
        end
    end)
end, true)

-- 2. Callback: Získání dat tabletu při otevření
RegisterNetEvent('aprts_tablet:server:getTabletData', function(serial)
    local src = source
    local result = exports.oxmysql:singleSync('SELECT * FROM player_tablets WHERE serial = ?', {serial})
    
    if result then
        local data = json.decode(result.tablet_data) or {}
        -- Pošleme data zpět klientovi
        TriggerClientEvent('aprts_tablet:client:loadTablet', src, result.model, data)
    else
        -- Tablet není v DB (cheated item?), vytvoříme dummy data
        TriggerClientEvent('aprts_tablet:client:loadTablet', src, 'tablet_basic', {installedApps = {}})
    end
end)

-- 3. Event: Uložení dat (když se něco změní - install app, změna tapety)
RegisterNetEvent('aprts_tablet:server:saveTabletData', function(serial, newData)
    -- newData je JSON objekt z JS
    exports.oxmysql:update('UPDATE player_tablets SET tablet_data = ? WHERE serial = ?', {
        json.encode(newData), serial
    })
end)