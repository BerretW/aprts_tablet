local QBCore = exports['qb-core']:GetCoreObject()

-- Tabulky pro cache
local PlacedRouters = {}
local PlayerTablets = {}

-- ====================================================================
-- 1. NAČTENÍ ROUTERŮ PŘI STARTU SERVERU
-- ====================================================================
local dataLoaded = false
CreateThread(function()
    -- Počkáme chvilku na DB
    Wait(1000)
    local routers = exports.oxmysql:executeSync('SELECT * FROM placed_routers')
    if routers then
        for _, router in pairs(routers) do
            -- Dekódování souřadnic z JSONu
            router.coords = json.decode(router.coords)
            PlacedRouters[router.id] = router
            print('^2[Tablet] Načten router ID ' .. router.id .. ' (' .. router.ssid .. ') z databáze.^0')
        end
        print('^2[Tablet] Načteno ' .. #routers .. ' routerů z databáze.^0')
        dataLoaded = true
    end
    
end)

-- ====================================================================
-- 2. SYNCHRONIZACE S KLIENTY
-- ====================================================================
RegisterNetEvent('aprts_tablet:server:requestRouters', function()
    local src = source
    while not dataLoaded do Wait(100) end
    TriggerClientEvent('aprts_tablet:client:syncRouters', src, PlacedRouters)
end)

-- ====================================================================
-- 3. POUŽITÍ ITEMU (POKLÁDÁNÍ ROUTERU)
-- ====================================================================
local function UseRouterItem(source, item)
    local src = source
    local routerType = item.name -- 'router_basic' nebo 'router_advanced'
    local routerConfig = Config.RouterTypes[routerType]
    
    if not routerConfig then return end

    -- Dialog pro zadání SSID a hesla
    local input = lib.callback.await('aprts_tablet:client:openRouterDialog', src)
    if not input then return end 

    local ssid = input[1]
    local password = input[2] 

    if not ssid or #ssid < 3 then 
        TriggerClientEvent('ox_lib:notify', src, {type='error', description='Název sítě je příliš krátký!'})
        return 
    end
    if password and #password == 0 then password = nil end 

    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)
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

-- Registrace itemů pro OX Inventory / QBCore
for item, _ in pairs(Config.RouterTypes) do
    if QBCore then
        QBCore.Functions.CreateUseableItem(item, function(source, item)
            UseRouterItem(source, item)
        end)
    end
end

-- ====================================================================
-- 4. SBÍRÁNÍ ROUTERU
-- ====================================================================
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

-- ====================================================================
-- 5. NOVÉ: OVĚŘENÍ HESLA K WIFI (Routery + Config Zóny)
-- ====================================================================
lib.callback.register('aprts_tablet:server:verifyWifi', function(source, ignoreId, ssid, password)
    -- 1. Kontrola hráčských routerů (Dynamické)
    for _, router in pairs(PlacedRouters) do
        if router.ssid == ssid then
            if not router.password or router.password == "" then return true end -- Bez hesla
            if router.password == password then return true end -- Správné heslo
        end
    end

    -- 2. Kontrola statických zón (Config)
    for _, zone in pairs(Config.WifiZones) do
        if zone.label == ssid then
            if not zone.password then return true end -- Bez hesla
            if zone.password == password then return true end -- Správné heslo
            return false 
        end
    end

    return false 
end)

-- ====================================================================
-- 6. OTEVŘENÍ TABLETU & DATA
-- ====================================================================
RegisterNetEvent('aprts_tablet:server:openBySlot', function(slot)
    local src = source
    local item = exports.ox_inventory:GetSlot(src, slot)

    if item and item.name == 'tablet' then
        local meta = item.metadata or {}
        local serial = meta.serial
        local model = meta.model or 'tablet_basic'
        
        if not serial then
            serial = "TAB-" .. math.random(100000, 999999)
            local newMeta = { serial = serial, model = model, battery = 100, locked = false, pin = "0000" }
            exports.ox_inventory:SetMetadata(src, slot, newMeta)
            meta = newMeta
        end
        
        if not PlayerTablets then PlayerTablets = {} end
        PlayerTablets[src] = { serial = serial, slot = slot }

        local result = exports.oxmysql:singleSync('SELECT * FROM player_tablets WHERE serial = ?', {serial})
        local dbData = {}
        local batteryLevel = 100

        if result then
            dbData = json.decode(result.tablet_data) or {}
            batteryLevel = result.battery or 100
        else
            local defaultBg = (model == 'tablet_pro') and 'https://files.catbox.moe/w8s1z6.jpg' or 'none'
            dbData = { installedApps = {'store', 'settings', 'calendar'}, background = defaultBg }
            exports.oxmysql:insert('INSERT INTO player_tablets (serial, model, tablet_data, battery) VALUES (?, ?, ?, ?)', {
                serial, model, json.encode(dbData), 100
            })
        end

        -- Načtení Kalendáře
        local calendarRows = exports.oxmysql:executeSync('SELECT * FROM player_tablets_calendar WHERE serial = ?', {serial})
        local formattedCalendar = {}
        for _, row in ipairs(calendarRows) do
            local key = row.event_date
            if not formattedCalendar[key] then formattedCalendar[key] = {} end
            table.insert(formattedCalendar[key], { id = row.id, time = row.event_time, title = row.title })
        end
        dbData.calendarEvents = formattedCalendar

        TriggerClientEvent('aprts_tablet:client:loadTablet', src, serial, model, dbData, {
            isLocked = meta.locked,
            pin = meta.pin,
            battery = batteryLevel
        })
    end
end)

-- ====================================================================
-- 7. UKLÁDÁNÍ DAT (Baterie, Appky, Sítě)
-- ====================================================================

-- Uložení známé sítě (když se úspěšně připojíš)
RegisterNetEvent('aprts_tablet:server:saveKnownNetwork', function(ssid, password)
    local src = source
    local tabletInfo = PlayerTablets[src]
    if not tabletInfo then return end

    local result = exports.oxmysql:singleSync('SELECT tablet_data FROM player_tablets WHERE serial = ?', {tabletInfo.serial})
    if result and result.tablet_data then
        local data = json.decode(result.tablet_data)
        if not data.savedNetworks then data.savedNetworks = {} end
        
        data.savedNetworks[ssid] = password
        
        exports.oxmysql:update('UPDATE player_tablets SET tablet_data = ? WHERE serial = ?', {
            json.encode(data), tabletInfo.serial
        })
    end
end)

-- Smazání známé sítě
RegisterNetEvent('aprts_tablet:server:removeKnownNetwork', function(ssid)
    local src = source
    local tabletInfo = PlayerTablets[src]
    if not tabletInfo then return end

    local result = exports.oxmysql:singleSync('SELECT tablet_data FROM player_tablets WHERE serial = ?', {tabletInfo.serial})
    if result and result.tablet_data then
        local data = json.decode(result.tablet_data)
        if data.savedNetworks and data.savedNetworks[ssid] then
            data.savedNetworks[ssid] = nil
            exports.oxmysql:update('UPDATE player_tablets SET tablet_data = ? WHERE serial = ?', {
                json.encode(data), tabletInfo.serial
            })
        end
    end
end)

-- Update baterie a dat
RegisterNetEvent('aprts_tablet:server:saveTabletData', function(serial, newData)
    newData.calendarEvents = nil 
    exports.oxmysql:update('UPDATE player_tablets SET tablet_data = ? WHERE serial = ?', { json.encode(newData), serial })
end)

RegisterNetEvent('aprts_tablet:server:updateBattery', function(serial, batteryLevel)
    exports.oxmysql:update('UPDATE player_tablets SET battery = ? WHERE serial = ?', { batteryLevel, serial })
    -- Metadata update skipped for brevity, but should be here
end)

-- Kalendář eventy
RegisterNetEvent('aprts_tablet:server:addCalendarEvent', function(serial, date, time, title)
    exports.oxmysql:insert('INSERT INTO player_tablets_calendar (serial, event_date, event_time, title) VALUES (?, ?, ?, ?)', { serial, date, time, title })
end)

RegisterNetEvent('aprts_tablet:server:deleteCalendarEvent', function(serial, eventId)
    exports.oxmysql:execute('DELETE FROM player_tablets_calendar WHERE serial = ? AND id = ?', { serial, eventId })
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