-- ====================================================================
-- FILE: server.lua
-- ====================================================================
local QBCore = exports['qb-core']:GetCoreObject()

-- Pomocná funkce pro načtení tabletu z DB a odeslání klientovi
local function LoadAndOpenTablet(source, serial, model)
    -- 1. Zkusíme najít tablet
    local result = exports.oxmysql:singleSync('SELECT * FROM player_tablets WHERE serial = ?', {serial})
    
    local tabletData = {}
    local tabletModel = model or 'tablet_basic'

    if result then
        tabletData = json.decode(result.tablet_data) or {}
        -- Pokud je v DB jiný model než v itemu, můžeme to ignorovat nebo aktualizovat
    else
        -- 2. Pokud neexistuje, VYTVOŘÍME HO HNED TEĎ
        print('^3[Tablet] Vytvářím nový záznam v DB pro serial: '..serial..'^0')
        tabletData = { 
            installedApps = {'store', 'settings', 'calendar'}, 
            background = (tabletModel == 'tablet_pro') and 'https://files.catbox.moe/w8s1z6.jpg' or 'none',
            calendarEvents = {} 
        }
        
        exports.oxmysql:insert('INSERT INTO player_tablets (serial, model, tablet_data) VALUES (?, ?, ?)', {
            serial, tabletModel, json.encode(tabletData)
        })
    end

    TriggerClientEvent('aprts_tablet:client:loadTablet', source, serial, tabletModel, tabletData)
end

-- EVENTY

RegisterNetEvent('aprts_tablet:server:openBySlot', function(slot)
    local src = source
    local item = exports.ox_inventory:GetSlot(src, slot)

    if item and item.name == 'tablet' and item.metadata and item.metadata.serial then
        -- Pokud má item uložený stav baterie v metadatech, pošleme ho klientovi
        -- (To vyžaduje malou úpravu v klientovi, viz níže)
        local battery = item.metadata.battery or 100
        TriggerClientEvent('aprts_tablet:client:setBattery', src, battery)

        LoadAndOpenTablet(src, item.metadata.serial, item.metadata.model)
    else
        -- Pokud item nemá serial, vygenerujeme ho a uložíme do metadat (fix pro "čisté" itemy)
        if item and item.name == 'tablet' and (not item.metadata or not item.metadata.serial) then
            local newSerial = "TAB-" .. math.random(100000, 999999)
            local newModel = 'tablet_basic' -- Default
            
            -- Update metadat v inventáři
            local newMetadata = item.metadata or {}
            newMetadata.serial = newSerial
            newMetadata.model = newModel
            newMetadata.battery = 100
            newMetadata.description = "Sériové číslo: " .. newSerial

            exports.ox_inventory:SetMetadata(src, slot, newMetadata)
            
            -- Otevřeme s novým serialem
            LoadAndOpenTablet(src, newSerial, newModel)
        else
            print('^1[Tablet] Chyba: Neplatná data slotu.^0')
        end
    end
end)

-- Uložení dat aplikací (Sync)
RegisterNetEvent('aprts_tablet:server:saveTabletData', function(serial, newData)
    exports.oxmysql:update('UPDATE player_tablets SET tablet_data = ? WHERE serial = ?', {
        json.encode(newData), serial
    })
end)

-- NOVÉ: Uložení baterie při zavření
RegisterNetEvent('aprts_tablet:server:updateBattery', function(serial, batteryLevel)
    local src = source
    -- Musíme najít item v inventáři podle serialu a aktualizovat metadata
    -- OX Inventory nemá přímý "GetItemByMetadata", takže musíme iterovat nebo si poslat slot
    -- Pro jednoduchost zde aktualizujeme DB, pokud bychom chtěli perzistenci i přes zahození itemu,
    -- ale správně pro OX Inventory je update metadat:
    
    local items = exports.ox_inventory:GetInventoryItems(src)
    for slot, item in pairs(items) do
        if item.name == 'tablet' and item.metadata and item.metadata.serial == serial then
            local meta = item.metadata
            meta.battery = batteryLevel
            exports.ox_inventory:SetMetadata(src, slot, meta)
            break
        end
    end
end)

-- Příkaz pro adminy
RegisterCommand('givetablet', function(source, args)
    local model = args[1] or 'tablet_pro'
    local serial = "TAB-" .. math.random(100000, 999999)
    -- V DB záznam vytvoříme až při prvním otevření (viz LoadAndOpenTablet logiku),
    -- nebo ho můžeme vytvořit zde. Díky mé úpravě LoadAndOpenTablet to není nutné zde hrotit.
    
    exports.ox_inventory:AddItem(source, 'tablet', 1, {
        serial = serial,
        model = model,
        battery = 100,
        description = "Sériové číslo: " .. serial
    })
end, true)

RegisterNetEvent('aprts_tablet:server:saveAppData', function(serial, appName, key, value)
    -- 1. Načíst data z DB
    local result = exports.oxmysql:singleSync('SELECT tablet_data FROM player_tablets WHERE serial = ?', {serial})
    if result and result.tablet_data then
        local data = json.decode(result.tablet_data)
        
        -- 2. Vytvořit strukturu, pokud neexistuje
        if not data.appData then data.appData = {} end
        if not data.appData[appName] then data.appData[appName] = {} end
        
        -- 3. Uložit hodnotu
        data.appData[appName][key] = value
        
        -- 4. Update DB
        exports.oxmysql:update('UPDATE player_tablets SET tablet_data = ? WHERE serial = ?', {
            json.encode(data), serial
        })
    end
end)