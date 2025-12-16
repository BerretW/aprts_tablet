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

    if item and item.name == 'tablet' then
        -- Načteme metadata, pokud neexistují, nastavíme default
        local meta = item.metadata or {}
        local pin = meta.pin or "0000"
        local isLocked = meta.locked or false -- Defaultně odemčeno
        local serial = meta.serial

        -- Pokud serial chybí, vygenerujeme (fix pro nové itemy)
        if not serial then
            serial = "TAB-" .. math.random(100000, 999999)
            meta.serial = serial
            exports.ox_inventory:SetMetadata(src, slot, meta)
        end
        
        -- Důležité: Uložíme si aktuální slot tabletu pro tohoto hráče
        -- abychom věděli, kam zapisovat změny PINu
        if not PlayerTablets then PlayerTablets = {} end
        PlayerTablets[src] = { serial = serial, slot = slot }

        -- Načteme DB data (aplikace, pozadí...)
        local dbData = {}
        local result = exports.oxmysql:singleSync('SELECT * FROM player_tablets WHERE serial = ?', {serial})
        
        if result then
            dbData = json.decode(result.tablet_data) or {}
        else
            -- Vytvoření v DB
            dbData = { installedApps = {'store', 'settings', 'calendar'}, background = 'none' }
            exports.oxmysql:insert('INSERT INTO player_tablets (serial, model, tablet_data) VALUES (?, ?, ?)', {
                serial, 'tablet_basic', json.encode(dbData)
            })
        end

        -- Odeslání klientovi vč. stavu zámku a PINu z metadat
        TriggerClientEvent('aprts_tablet:client:loadTablet', src, serial, 'tablet_pro', dbData, {
            isLocked = isLocked,
            pin = pin,
            battery = meta.battery or 100
        })
    end
end)

-- 2. Event pro změnu PINu
RegisterNetEvent('aprts_tablet:server:setPin', function(newPin)
    local src = source
    local tabletInfo = PlayerTablets and PlayerTablets[src]
    
    if tabletInfo then
        -- Upravíme metadata na konkrétním slotu
        local item = exports.ox_inventory:GetSlot(src, tabletInfo.slot)
        if item and item.metadata.serial == tabletInfo.serial then
            local meta = item.metadata
            meta.pin = newPin
            exports.ox_inventory:SetMetadata(src, tabletInfo.slot, meta)
        end
    end
end)
RegisterNetEvent('aprts_tablet:server:setLockState', function(state)
    local src = source
    local tabletInfo = PlayerTablets and PlayerTablets[src]
    
    if tabletInfo then
        local item = exports.ox_inventory:GetSlot(src, tabletInfo.slot)
        if item and item.metadata.serial == tabletInfo.serial then
            local meta = item.metadata
            meta.locked = state
            exports.ox_inventory:SetMetadata(src, tabletInfo.slot, meta)
        end
    end
end)

-- 4. Event při úspěšném odemčení PINem (Aby zůstal odemčený, když ho někomu dám)
RegisterNetEvent('aprts_tablet:server:unlockSuccess', function()
    local src = source
    local tabletInfo = PlayerTablets and PlayerTablets[src]
    
    if tabletInfo then
        local item = exports.ox_inventory:GetSlot(src, tabletInfo.slot)
        if item and item.metadata.serial == tabletInfo.serial then
            local meta = item.metadata
            meta.locked = false -- Odemkneme v metadatech
            exports.ox_inventory:SetMetadata(src, tabletInfo.slot, meta)
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