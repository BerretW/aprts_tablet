local QBCore = exports['qb-core']:GetCoreObject()

-- Pomocná funkce pro načtení tabletu z DB a odeslání klientovi
local function LoadAndOpenTablet(source, serial, model)
    -- 1. Načteme data z SQL
    local result = exports.oxmysql:singleSync('SELECT * FROM player_tablets WHERE serial = ?', {serial})
    
    local tabletData = {}
    local tabletModel = model or 'tablet_basic'

    if result then
        -- Tablet existuje v DB
        tabletData = json.decode(result.tablet_data) or {}
        tabletModel = result.model -- Použijeme model uložený v DB (pokud se liší)
    else
        -- Tablet není v DB -> vytvoříme dummy data, aby se otevřel
        print('^3[Tablet] Varování: Tablet '..serial..' nebyl nalezen v DB. Načítám dočasná data.^0')
        tabletData = { installedApps = {'store', 'settings', 'calendar'}, background = 'none' }
    end

    -- 2. Pošleme data klientovi k otevření
    TriggerClientEvent('aprts_tablet:client:loadTablet', source, tabletModel, tabletData)
end

-- ====================================================================
-- EVENTY
-- ====================================================================

-- NOVÝ EVENT: Otevření podle slotu (řeší tvůj problém)
RegisterNetEvent('aprts_tablet:server:openBySlot', function(slot)
    local src = source
    -- Získáme item přímo ze server-side inventáře (tady metadata 100% jsou)
    local item = exports.ox_inventory:GetSlot(src, slot)

    if item and item.name == 'tablet' and item.metadata and item.metadata.serial then
        -- Máme sériové číslo! Můžeme načítat.
        LoadAndOpenTablet(src, item.metadata.serial, item.metadata.model)
    else
        print('^1[Tablet] Chyba: Na slotu '..tostring(slot)..' není platný tablet nebo chybí serial.^0')
    end
end)

-- Starý event pro debug nebo jiné použití (zachována kompatibilita)
RegisterNetEvent('aprts_tablet:server:getTabletData', function(serial)
    local src = source
    LoadAndOpenTablet(src, serial, 'tablet_pro')
end)

-- Uložení dat
RegisterNetEvent('aprts_tablet:server:saveTabletData', function(serial, newData)
    exports.oxmysql:update('UPDATE player_tablets SET tablet_data = ? WHERE serial = ?', {
        json.encode(newData), serial
    })
end)

-- ====================================================================
-- PŘÍKAZY
-- ====================================================================

RegisterCommand('givetablet', function(source, args)
    local model = args[1] or 'tablet_pro'
    local serial = "TAB-" .. math.random(100000, 999999)

    local defaultData = {
        background = (model == 'tablet_pro') and 'https://files.catbox.moe/w8s1z6.jpg' or 'none',
        installedApps = {'store', 'settings', 'calendar'},
        settings = {}
    }

    exports.oxmysql:insert('INSERT INTO player_tablets (serial, model, tablet_data) VALUES (?, ?, ?)', {
        serial, model, json.encode(defaultData)
    }, function(id)
        if id then
            exports.ox_inventory:AddItem(source, 'tablet', 1, {
                serial = serial,
                model = model,
                description = "Sériové číslo: " .. serial
            })
            print('Tablet vytvořen: ' .. serial)
        end
    end)
end, true)