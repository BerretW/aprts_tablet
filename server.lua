local QBCore = exports['qb-core']:GetCoreObject()

-- ====================================================================
-- OTEVŘENÍ TABLETU (Načtení dat)
-- ====================================================================
RegisterNetEvent('aprts_tablet:server:openBySlot', function(slot)
    local src = source
    local item = exports.ox_inventory:GetSlot(src, slot)

    if item and item.name == 'tablet' then
        local meta = item.metadata or {}
        local serial = meta.serial
        local model = meta.model or 'tablet_basic'
        
        -- Pokud serial neexistuje, vytvoříme nový
        if not serial then
            serial = "TAB-" .. math.random(100000, 999999)
            local newMeta = {
                serial = serial,
                model = model,
                battery = 100,
                locked = false,
                pin = "0000",
                description = "Sériové číslo: " .. serial
            }
            exports.ox_inventory:SetMetadata(src, slot, newMeta)
            meta = newMeta
        end
        
        if not PlayerTablets then PlayerTablets = {} end
        PlayerTablets[src] = { serial = serial, slot = slot }

        -- 1. Načtení/Vytvoření hlavních dat tabletu
        local result = exports.oxmysql:singleSync('SELECT * FROM player_tablets WHERE serial = ?', {serial})
        local dbData = {}
        local batteryLevel = 100

        if result then
            dbData = json.decode(result.tablet_data) or {}
            -- Načteme baterii z DB sloupce, pokud je NULL, použijeme 100
            batteryLevel = result.battery or 100
        else
            -- Vytvoření nového záznamu
            local defaultBg = (model == 'tablet_pro') and 'https://files.catbox.moe/w8s1z6.jpg' or 'none'
            dbData = { 
                installedApps = {'store', 'settings', 'calendar'}, 
                background = defaultBg
            }
            -- Vložíme s defaultní baterií 100
            exports.oxmysql:insert('INSERT INTO player_tablets (serial, model, tablet_data, battery) VALUES (?, ?, ?, ?)', {
                serial, model, json.encode(dbData), 100
            })
            batteryLevel = 100
        end

        -- 2. Načtení Kalendáře z NOVÉ TABULKY
        local calendarRows = exports.oxmysql:executeSync('SELECT * FROM player_tablets_calendar WHERE serial = ?', {serial})
        local formattedCalendar = {}

        -- Převedeme SQL řádky na formát, který očekává JS (Object s klíči "D-M-YYYY")
        for _, row in ipairs(calendarRows) do
            local key = row.event_date -- "16-12-2025"
            if not formattedCalendar[key] then formattedCalendar[key] = {} end
            
            table.insert(formattedCalendar[key], {
                id = row.id, -- Potřebujeme ID pro mazání
                time = row.event_time,
                title = row.title
            })
        end
        
        -- Přidáme kalendář do dat pro klienta
        dbData.calendarEvents = formattedCalendar

        -- 3. Odeslání klientovi
        TriggerClientEvent('aprts_tablet:client:loadTablet', src, serial, model, dbData, {
            isLocked = meta.locked,
            pin = meta.pin,
            battery = batteryLevel -- Posíláme baterii z SQL
        })
    end
end)

-- ====================================================================
-- UKLÁDÁNÍ BATERIE (SQL + Metadata)
-- ====================================================================
RegisterNetEvent('aprts_tablet:server:updateBattery', function(serial, batteryLevel)
    local src = source
    
    -- 1. Update SQL Sloupce
    exports.oxmysql:update('UPDATE player_tablets SET battery = ? WHERE serial = ?', {
        batteryLevel, serial
    })

    -- 2. Update Metadat v inventáři (aby to bylo vidět v tooltipu)
    local tabletInfo = PlayerTablets and PlayerTablets[src]
    if tabletInfo and tabletInfo.serial == serial then
        local item = exports.ox_inventory:GetSlot(src, tabletInfo.slot)
        if item and item.name == 'tablet' and item.metadata.serial == serial then
            local meta = item.metadata
            meta.battery = batteryLevel
            exports.ox_inventory:SetMetadata(src, tabletInfo.slot, meta)
        end
    end
end)

-- Update baterie při nabíjení (podle slotu)
RegisterNetEvent('aprts_tablet:server:updateBatteryBySlot', function(slot, serial, batteryLevel)
    local src = source
    
    -- SQL Update
    exports.oxmysql:update('UPDATE player_tablets SET battery = ? WHERE serial = ?', {
        batteryLevel, serial
    })

    -- Inventory Update
    local item = exports.ox_inventory:GetSlot(src, slot)
    if item and item.name == 'tablet' and item.metadata.serial == serial then
        local meta = item.metadata
        meta.battery = batteryLevel
        exports.ox_inventory:SetMetadata(src, slot, meta)
    end
end)

-- ====================================================================
-- KALENDÁŘ - NOVÉ EVENTY PRO SQL
-- ====================================================================

-- Přidání události
RegisterNetEvent('aprts_tablet:server:addCalendarEvent', function(serial, date, time, title)
    exports.oxmysql:insert('INSERT INTO player_tablets_calendar (serial, event_date, event_time, title) VALUES (?, ?, ?, ?)', {
        serial, date, time, title
    })
end)

-- Smazání události
RegisterNetEvent('aprts_tablet:server:deleteCalendarEvent', function(serial, eventId)
    exports.oxmysql:execute('DELETE FROM player_tablets_calendar WHERE serial = ? AND id = ?', {
        serial, eventId
    })
end)

-- ====================================================================
-- OSTATNÍ (PIN, Lock, AppData) - Původní kód
-- ====================================================================
RegisterNetEvent('aprts_tablet:server:setPin', function(newPin)
    local src = source
    local tabletInfo = PlayerTablets and PlayerTablets[src]
    if tabletInfo then
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

RegisterNetEvent('aprts_tablet:server:unlockSuccess', function()
    local src = source
    local tabletInfo = PlayerTablets and PlayerTablets[src]
    if tabletInfo then
        local item = exports.ox_inventory:GetSlot(src, tabletInfo.slot)
        if item and item.metadata.serial == tabletInfo.serial then
            local meta = item.metadata
            meta.locked = false
            exports.ox_inventory:SetMetadata(src, tabletInfo.slot, meta)
        end
    end
end)

RegisterNetEvent('aprts_tablet:server:saveTabletData', function(serial, newData)
    -- Zde ukládáme jen obecná data (appky, pozadí), kalendář už ne
    -- Musíme vyčistit calendarEvents z newData, aby se neukládal do JSONu duplicitně
    newData.calendarEvents = nil 
    
    exports.oxmysql:update('UPDATE player_tablets SET tablet_data = ? WHERE serial = ?', {
        json.encode(newData), serial
    })
end)

RegisterNetEvent('aprts_tablet:server:saveAppData', function(serial, appName, key, value)
    local result = exports.oxmysql:singleSync('SELECT tablet_data FROM player_tablets WHERE serial = ?', {serial})
    if result and result.tablet_data then
        local data = json.decode(result.tablet_data)
        if not data.appData then data.appData = {} end
        if not data.appData[appName] then data.appData[appName] = {} end
        data.appData[appName][key] = value
        exports.oxmysql:update('UPDATE player_tablets SET tablet_data = ? WHERE serial = ?', {
            json.encode(data), serial
        })
    end
end)

-- ====================================================================
-- WIFI ROUTER SYSTÉM
-- ====================================================================

local PlacedRouters = {}

-- Načtení routerů při startu
CreateThread(function()
    local routers = exports.oxmysql:executeSync('SELECT * FROM placed_routers')
    for _, router in ipairs(routers) do
        router.coords = json.decode(router.coords)
        PlacedRouters[router.id] = router
    end
end)

-- Synchronizace s klienty (při připojení)
RegisterNetEvent('aprts_tablet:server:requestRouters', function()
    TriggerClientEvent('aprts_tablet:client:syncRouters', source, PlacedRouters)
end)

-- Použití itemu (Router)
local function UseRouterItem(event, item, inventory, slot, data)
    print("Použití routeru: " .. item.name)
    local src = inventory.id
    local routerType = item.name -- 'router_basic' nebo 'router_advanced'
    local routerConfig = Config.RouterTypes[routerType]
    
    if not routerConfig then 
        print('^1[Tablet] Chyba: Neznámý typ routeru: ' .. routerType .. '^0')
        return 
    end

    -- Dialog pro zadání SSID a hesla
    local input = lib.callback.await('aprts_tablet:client:openRouterDialog', src)
    if not input then return end -- Zrušil dialog

    local ssid = input[1]
    local password = input[2] -- Může být prázdné

    if not ssid or #ssid < 3 then 
        TriggerClientEvent('ox_lib:notify', src, {type='error', description='Název sítě je příliš krátký!'})
        return 
    end
    if password and #password == 0 then password = nil end -- Prázdné heslo = nil

    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)
    -- Položíme ho na zem
    local placeCoords = vector3(coords.x, coords.y, coords.z - 0.98)

    -- Uložit do DB
    local id = exports.oxmysql:insertSync('INSERT INTO placed_routers (coords, ssid, password, type) VALUES (?, ?, ?, ?)', {
        json.encode(placeCoords), ssid, password, routerType
    })

    if id then
        -- Odebrat item
        exports.ox_inventory:RemoveItem(src, routerType, 1)

        -- Přidat do cache a syncnout všem
        local newRouter = {
            id = id,
            coords = placeCoords,
            ssid = ssid,
            password = password,
            type = routerType
        }
        PlacedRouters[id] = newRouter
        TriggerClientEvent('aprts_tablet:client:addRouter', -1, newRouter)
    end
end

-- Registrace itemů (musí odpovídat klíčům v Config.RouterTypes)
for item, _ in pairs(Config.RouterTypes) do
    exports.ox_inventory:registerHook('createItem', function(payload)
        return payload
    end, {
        print = false,
        itemFilter = { [item] = true }
    })
    
    -- OX Inventory použití itemu se dělá přes export, ale jednodušší je
    -- použít QBCore UseItem event pokud používáš QB, nebo ESX.
    -- Pro univerzálnost zde předpokládáme QBCore, pokud máš ESX, uprav si registraci.
    if QBCore then
        QBCore.Functions.CreateUseableItem(item, function(source, item)
            -- print("Použití routeru: " .. item.name)
            UseRouterItem(nil, item, {id=source}, nil, nil)
        end)
    end
end

-- Sbírání routeru
RegisterNetEvent('aprts_tablet:server:pickupRouter', function(routerId)
    local src = source
    local router = PlacedRouters[routerId]
    
    if router then
        -- Smazat z DB
        exports.oxmysql:execute('DELETE FROM placed_routers WHERE id = ?', {routerId})
        
        -- Vrátit item
        exports.ox_inventory:AddItem(src, router.type, 1)
        
        -- Sync smazání
        PlacedRouters[routerId] = nil
        TriggerClientEvent('aprts_tablet:client:removeRouter', -1, routerId)
    end
end)

-- Ověření hesla (Callback)
lib.callback.register('aprts_tablet:server:verifyWifi', function(source, routerId, inputPassword)
    local router = PlacedRouters[routerId]
    if not router then return false end
    
    if not router.password then return true end -- Nemá heslo
    return router.password == inputPassword
end)