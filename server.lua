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
        -- 1. Načtení metadat
        local meta = item.metadata or {}
        local serial = meta.serial
        -- ZDE JE OPRAVA: Bereme model z metadat, pokud není, tak default 'tablet_basic'
        local model = meta.model or 'tablet_basic' 
        
        local isLocked = meta.locked or false
        local pin = meta.pin or "0000"

        -- 2. Pokud tablet nemá sériové číslo (nový item), vygenerujeme ho
        if not serial then
            serial = "TAB-" .. math.random(100000, 999999)
            
            -- Aktualizujeme metadata v inventáři
            local newMeta = {
                serial = serial,
                model = model, -- Uložíme model
                battery = 100,
                locked = false,
                pin = "0000",
                description = "Sériové číslo: " .. serial
            }
            exports.ox_inventory:SetMetadata(src, slot, newMeta)
            
            -- Aktualizujeme lokální proměnné pro další běh kódu
            meta = newMeta
        end
        
        -- Uložení aktivního slotu pro pozdější update
        if not PlayerTablets then PlayerTablets = {} end
        PlayerTablets[src] = { serial = serial, slot = slot }

        -- 3. Načtení dat z Databáze (obsah tabletu)
        local dbData = {}
        local result = exports.oxmysql:singleSync('SELECT * FROM player_tablets WHERE serial = ?', {serial})
        
        if result then
            dbData = json.decode(result.tablet_data) or {}
            
            -- Volitelné: Pokud je v DB uložen jiný model než v itemu, můžeme aktualizovat DB
            if result.model ~= model then
                exports.oxmysql:update('UPDATE player_tablets SET model = ? WHERE serial = ?', {model, serial})
            end
        else
            -- Vytvoření záznamu v DB, pokud neexistuje
            -- Pokud je to 'tablet_pro', dáme mu defaultně hezčí pozadí
            local defaultBg = (model == 'tablet_pro') and 'https://files.catbox.moe/w8s1z6.jpg' or 'none'
            
            dbData = { 
                installedApps = {'store', 'settings', 'calendar'}, 
                background = defaultBg,
                calendarEvents = {} 
            }
            
            exports.oxmysql:insert('INSERT INTO player_tablets (serial, model, tablet_data) VALUES (?, ?, ?)', {
                serial, model, json.encode(dbData)
            })
        end

        -- 4. Odeslání klientovi
        -- OPRAVA: Místo 'tablet_pro' posíláme proměnnou 'model'
        TriggerClientEvent('aprts_tablet:client:loadTablet', src, serial, model, dbData, {
            isLocked = meta.locked,
            pin = meta.pin,
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
    local src = source
    -- Argument 1: model (tablet_basic nebo tablet_pro), defaultně basic
    local modelType = args[1] or 'tablet_basic' 
    
    local serial = "TAB-" .. math.random(100000, 999999)
    
    exports.ox_inventory:AddItem(src, 'tablet', 1, {
        serial = serial,
        model = modelType, -- Tady se určuje typ
        battery = 100,
        pin = "0000",
        locked = false,
        description = "Model: " .. modelType .. " | S/N: " .. serial
    })
    
    print('^2[Tablet] Hráči '..src..' dán tablet typu: '..modelType..'^0')
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

RegisterNetEvent('aprts_tablet:server:updateBatteryBySlot', function(slot, serial, battery)
    local src = source
    local item = exports.ox_inventory:GetSlot(src, slot)
    
    -- Kontrola, zda je na slotu stále ten samý tablet (zda ho hráč nepřesunul/nezahodil během nabíjení)
    if item and item.name == 'tablet' and item.metadata.serial == serial then
        local meta = item.metadata
        meta.battery = battery
        exports.ox_inventory:SetMetadata(src, slot, meta)
    end
end)