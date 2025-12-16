local isTabletOpen = false
local tabletProp = nil
local currentSerial = nil -- Zde si držíme sériové číslo aktuálně otevřeného tabletu
local currentBattery = 100
local lastHistoryUpdate = 0 -- Časovač
local batteryHistory = {} -- Tabulka pro historii
-- Animace
local tabletModel = "prop_cs_tablet"
local tabletDict = "amb@world_human_seat_wall_tablet@female@base"
local tabletAnim = "base"

-- Lokální registr aplikací
local RegisteredApps = {}

-- Načtení Configu (fallback)
if not Config then
    Config = {}
    Config.Tablets = {
        ['tablet_basic'] = {
            os = "retro",
            bootTime = 3000,
            wallpaper = "none"
        },
        ['tablet_pro'] = {
            os = "modern",
            bootTime = 1500,
            wallpaper = "https://files.catbox.moe/w8s1z6.jpg"
        }
    }
end

-- ====================================================================
-- 1. POUŽITÍ PŘEDMĚTU (ENTRY POINT)
-- ====================================================================

-- Export pro OX Inventory (v items.lua nastavit: export = 'aprts_tablet.useTablet')
exports('useTablet', function(data)
    -- data obsahuje: slot, name, count... ale metadata chybí.
    -- Proto pošleme na server jen číslo slotu.
    if data and data.slot then
        StartTabletAnimation()
        -- Pošleme serveru číslo slotu, ať si sériové číslo najde sám
        TriggerServerEvent('aprts_tablet:server:openBySlot', data.slot)
    else
        print('^1[Tablet] Chyba: Neplatná data z inventáře!^0')
    end
end)

-- Debug příkaz (pokud nemáš item v inventáři)
RegisterCommand('tabletdebug', function(source, args)
    local serial = "DEBUG-001"
    currentSerial = serial
    StartTabletAnimation()
    TriggerServerEvent('aprts_tablet:server:getTabletData', serial)
end)

-- ====================================================================
-- 2. NAČTENÍ DAT A OTEVŘENÍ NUI
-- ====================================================================

RegisterNetEvent('aprts_tablet:client:loadTablet')
AddEventHandler('aprts_tablet:client:loadTablet', function(serial, model, dbData)
        print('[Client Debug] Načítám tablet. Serial:', serial, 'Model:', model) -- DEBUG

    local tabletConfig = Config.Tablets[model]
    if not tabletConfig then 
        print("^1[Tablet] Neznámý model tabletu: "..tostring(model).."^0")
        StopTabletAnimation()
        return 
    end

    if not isTabletOpen then
        isTabletOpen = true
        currentSerial = serial

        -- NAČTENÍ BATERIE A HISTORIE Z DB
        -- Pokud v DB nic není, založíme prázdnou
        batteryHistory = dbData.batteryHistory or {}

        -- Pokud je item zrovna vygenerovaný, nastavíme baterii z metadat (kterou řešíme jinde) nebo 100
        -- (Zde předpokládáme, že logiku pro currentBattery už máš z předchozích kroků)

        SetNuiFocus(true, true)

        local payload = {
            action = "bootSystem",
            os = tabletConfig.os,
            storage = tabletConfig.storage or 1024,
            bootTime = tabletConfig.bootTime,
            serial = serial,
            installedApps = dbData.installedApps,
            wallpaper = dbData.background or tabletConfig.wallpaper,
            calendarEvents = dbData.calendarEvents or {},

            -- NOVÉ: Pošleme historii do JS
            batteryHistory = batteryHistory
        }

        SendNUIMessage(payload)
    end
end)

-- ====================================================================
-- 3. EXPORTY A REGISTRACE APLIKACÍ
-- ====================================================================

-- Export, který volají ostatní scripty (dt_news, dt_police...)
exports('RegisterApp', function(appName, label, iconClass, color, eventToTrigger)
    RegisteredApps[appName] = {
        event = eventToTrigger
    }

    SendNUIMessage({
        action = "registerApp",
        appName = appName,
        label = label,
        iconClass = iconClass,
        color = color
    })
end)

-- Registrace systémových aplikací (běží v JS, ale musí být v seznamu ikon)
CreateThread(function()
    Wait(1000) -- Čekáme na NUI

    exports['aprts_tablet']:RegisterApp('store', 'App Store', 'fas fa-store', '#0984e3', nil)
    exports['aprts_tablet']:RegisterApp('settings', 'Nastavení', 'fas fa-cog', '#636e72', nil)
    exports['aprts_tablet']:RegisterApp('calendar', 'Kalendář', 'fas fa-calendar-alt', '#e84393', nil)

    -- Signál pro ostatní scripty, že tablet je ready
    TriggerEvent('aprts_tablet:ready')
end)

-- ====================================================================
-- 4. NUI CALLBACKS (KOMUNIKACE Z JS)
-- ====================================================================

-- Přidej tento event pro nastavení baterie ze serveru
RegisterNetEvent('aprts_tablet:client:setBattery')
AddEventHandler('aprts_tablet:client:setBattery', function(val)
    currentBattery = val
end)

-- UPRAV NUI Callback "closeTablet"
RegisterNUICallback('closeTablet', function(data, cb)
    isTabletOpen = false
    SetNuiFocus(false, false)
    StopTabletAnimation()

    -- Odeslat stav baterie na server k uložení
    if currentSerial then
        TriggerServerEvent('aprts_tablet:server:updateBattery', currentSerial, currentBattery)
    end

    cb('ok')
end)

-- Otevření externí aplikace
RegisterNUICallback('openAppRequest', function(data, cb)
    local appData = RegisteredApps[data.appId]
    if appData and appData.event then
        TriggerEvent(appData.event)
    end
    cb('ok')
end)

-- Synchronizace dat do cloudu (SQL)
RegisterNUICallback('syncData', function(data, cb)
    print('[Client Debug] Volán syncData z JS.') -- DEBUG

    if currentSerial then
        print('[Client Debug] Odesílám data na server pro serial:', currentSerial) -- DEBUG
        -- data obsahuje { installedApps, background, calendarEvents }
data.batteryHistory = batteryHistory -- Přidáme historii baterie

        TriggerServerEvent('aprts_tablet:server:saveTabletData', currentSerial, data)
    else
        print('^1[Client Error] Pokus o uložení dat, ale currentSerial je NIL!^0')
    end
    cb('ok')
end)

-- Bridge pro data z formulářů v aplikacích
RegisterNUICallback('appAction', function(data, cb)
    local appId = data.appId
    local action = data.action
    local payload = data.data
    TriggerEvent(appId .. ':handleAction', action, payload)
    cb('ok')
end)

-- Instalace (Client side check - volitelné)
RegisterNUICallback('installApp', function(data, cb)
    cb({
        success = true
    })
end)

-- Příjem obsahu (HTML) z pluginů
RegisterNetEvent('aprts_tablet:loadContent') -- Zachována zpětná kompatibilita názvu eventu
AddEventHandler('aprts_tablet:loadContent', function(htmlContent)
    -- Bezpečnostní kontrola
    if not isTabletOpen then
        return
    end

    SendNUIMessage({
        action = "setAppContent",
        html = htmlContent
    })
end)

-- ====================================================================
-- 5. ANIMACE
-- ====================================================================

function StartTabletAnimation()
    CreateThread(function()
        local ped = PlayerPedId()
        RequestAnimDict(tabletDict)
        while not HasAnimDictLoaded(tabletDict) do
            Wait(10)
        end

        RequestModel(tabletModel)
        while not HasModelLoaded(tabletModel) do
            Wait(10)
        end

        tabletProp = CreateObject(GetHashKey(tabletModel), 0, 0, 0, true, true, true)
        AttachEntityToEntity(tabletProp, ped, GetPedBoneIndex(ped, 28422), -0.05, 0.0, 0.0, 0.0, 0.0, 0.0, true, true,
            false, true, 1, true)

        TaskPlayAnim(ped, tabletDict, tabletAnim, 8.0, -8.0, -1, 50, 0, false, false, false)
    end)
end

function StopTabletAnimation()
    local ped = PlayerPedId()
    ClearPedTasks(ped)
    if tabletProp then
        DeleteEntity(tabletProp)
        tabletProp = nil
    end
end

-- ====================================================================
-- 6. SYNC LOOP (ČAS + WIFI)
-- ====================================================================

-- Stavové proměnné
local currentBattery = 100 -- (Tohle se přepíše při otevření z metadat)
local currentWifiLevel = 0
local currentWifiName = "Žádný signál"
local hasInternet = false
local isCharging = false

-- Funkce: Je hráč u nabíječky?
local function IsNearCharger(pos)
    for _, chargerPos in pairs(Config.ChargingStations) do
        if #(pos - chargerPos) < 2.0 then -- Dosah 2 metry
            return true
        end
    end
    return false
end

-- Funkce: Aktualizace stavu
local function UpdateSystemStatus()
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)

    -- 1. Wi-Fi Logic
    hasInternet = false
    currentWifiName = "Žádný signál"
    currentWifiLevel = 0

    for _, zone in pairs(Config.WifiZones) do
        local dist = #(pos - zone.coords)
        if dist < zone.radius then
            hasInternet = true
            currentWifiName = zone.label

            -- Výpočet síly signálu (0 až 4)
            local signalPct = 1.0 - (dist / zone.radius)
            if signalPct > 0.8 then
                currentWifiLevel = 4
            elseif signalPct > 0.6 then
                currentWifiLevel = 3
            elseif signalPct > 0.4 then
                currentWifiLevel = 2
            else
                currentWifiLevel = 1
            end

            break
        end
    end

    -- 2. Charging Logic
    isCharging = IsNearCharger(pos)

    -- 3. Battery Logic (běží v loopu níže, zde jen kontrola limitů)
    if currentBattery > 100 then
        currentBattery = 100
    end
    if currentBattery < 0 then
        currentBattery = 0
    end

    -- Pokud dojde baterie, zavřeme tablet
    if currentBattery <= 0 and isTabletOpen and not isCharging then
        SetNuiFocus(false, false)
        StopTabletAnimation()
        isTabletOpen = false
        TriggerEvent('chat:addMessage', {
            args = {'^1[Tablet]', 'Baterie je vybitá!'}
        })
    end
end
-- ====================================================================
-- NOVÁ LOGIKA NABÍJENÍ (client.lua)
-- ====================================================================

-- Stavové proměnné
local currentBattery = 100
local currentWifiLevel = 0
local currentWifiName = "Žádný signál"
local hasInternet = false

-- !!! NOVÁ PROMĚNNÁ: Je tablet fyzicky připojen v síti?
local isConnectedToCharger = false
local chargerCoords = nil -- Uložíme si pozici, kde jsme se připojili

-- Funkce pro připojení (volaná přes Target nebo E)
function ConnectCharger(coords)
    if isConnectedToCharger then
        return
    end

    local ped = PlayerPedId()
    chargerCoords = coords or GetEntityCoords(ped)
    isConnectedToCharger = true

    -- Notifikace
    TriggerEvent('chat:addMessage', {
        args = {'^2[Tablet]', 'Tablet připojen k nabíječce.'}
    })

    -- Spustíme animaci, pokud tablet zrovna nedrží v ruce (otevřený)
    if not isTabletOpen then
        RequestAnimDict("cellphone@")
        while not HasAnimDictLoaded("cellphone@") do
            Wait(10)
        end
        TaskPlayAnim(ped, "cellphone@", "cellphone_text_in", 8.0, -8.0, -1, 50, 0, false, false, false)
    end
end

-- Funkce pro odpojení
function DisconnectCharger()
    if not isConnectedToCharger then
        return
    end

    isConnectedToCharger = false
    chargerCoords = nil

    TriggerEvent('chat:addMessage', {
        args = {'^1[Tablet]', 'Tablet odpojen.'}
    })

    -- Zrušíme animaci pouze pokud tablet není otevřený (abychom nerozbili animaci používání)
    if not isTabletOpen then
        ClearPedTasks(PlayerPedId())
    end
end

-- Export pro Target (abys to mohl volat z jiných scriptů nebo Targetu)
exports('ConnectCharger', ConnectCharger)
exports('DisconnectCharger', DisconnectCharger)

-- HLAVNÍ LOOP
CreateThread(function()
    while true do
        Wait(Config.BatteryTick) -- 5 sekund

        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)

        -- 1. Wi-Fi Logic (Zůstává stejná)
        hasInternet = false
        currentWifiName = "Žádný signál"
        currentWifiLevel = 0

        for _, zone in pairs(Config.WifiZones) do
            local dist = #(pos - zone.coords)
            if dist < zone.radius then
                hasInternet = true
                currentWifiName = zone.label
                local signalPct = 1.0 - (dist / zone.radius)
                if signalPct > 0.8 then
                    currentWifiLevel = 4
                elseif signalPct > 0.6 then
                    currentWifiLevel = 3
                elseif signalPct > 0.4 then
                    currentWifiLevel = 2
                else
                    currentWifiLevel = 1
                end
                break
            end
        end

        -- 2. KONTROLA ODPOJENÍ POHYBEM
        if isConnectedToCharger and chargerCoords then
            -- Pokud se hráč vzdálí více než 1.5 metru od zásuvky, kabel se "vytrhne"
            if #(pos - chargerCoords) > 1.5 then
                DisconnectCharger()
            end
        end

        -- 3. BATTERY LOGIC
        if isTabletOpen then
            -- Pokud je připojen k síti, tak se NEVYBÍJÍ, ale NABÍJÍ
            if isConnectedToCharger then
                if currentBattery < 100 then
                    currentBattery = currentBattery + Config.BatteryChargeRate
                end
            else
                -- Není připojen -> Vybíjí se
                if currentBattery > 0 then
                    currentBattery = currentBattery - Config.BatteryDrainRate
                end
            end
        elseif isConnectedToCharger then
            -- Tablet je zavřený v kapse/ruce, ale hráč stojí u nabíječky a je připojen
            if currentBattery < 100 then
                currentBattery = currentBattery + Config.BatteryChargeRate
            end
        end

        -- Limit 0-100
        if currentBattery > 100 then
            currentBattery = 100
        end
        if currentBattery < 0 then
            currentBattery = 0
        end

        -- === LOGIKA HISTORIE (24H GRAF) ===
        -- Získáme aktuální čas hry (v milisekundách)
        local gameTimer = GetGameTimer()

        -- Pokud uběhl interval (např. 30 minut = 1800000 ms)
        if (gameTimer - lastHistoryUpdate) > (Config.HistoryInterval * 60000) then
            lastHistoryUpdate = gameTimer

            -- Získáme aktuální herní nebo reálný čas pro popisek osy X
            local hours = GetClockHours()
            local minutes = GetClockMinutes()
            local timeLabel = string.format("%02d:%02d", hours, minutes)

            -- Přidáme nový bod
            table.insert(batteryHistory, {
                time = timeLabel,
                value = math.floor(currentBattery)
            })

            -- Udržujeme max 48 bodů (24 hodin po 30 min)
            if #batteryHistory > 48 then
                table.remove(batteryHistory, 1) -- Smažeme nejstarší
            end

            -- Pokud je tablet otevřený, pošleme aktualizaci grafu hned (volitelné)
            -- Ale stačí, že se to uloží při zavření.
        end

        -- Odeslání dat do UI (jen když je otevřeno)
        if isTabletOpen then
            local hours = GetClockHours()
            local minutes = GetClockMinutes()
            if hours < 10 then
                hours = "0" .. hours
            end
            if minutes < 10 then
                minutes = "0" .. minutes
            end

            SendNUIMessage({
                action = "updateInfobar",
                time = hours .. ":" .. minutes,
                wifi = hasInternet,
                wifiName = currentWifiName,
                wifiLevel = currentWifiLevel,
                battery = math.floor(currentBattery),
                isCharging = isConnectedToCharger -- !!! ZDE POSÍLÁME STAV PŘIPOJENÍ
            })
        end

        -- Vypnutí při vybití
        if currentBattery <= 0 and isTabletOpen and not isConnectedToCharger then
            SetNuiFocus(false, false)
            StopTabletAnimation()
            isTabletOpen = false
            TriggerEvent('chat:addMessage', {
                args = {'^1[Tablet]', 'Baterie kritická! Připoj nabíječku.'}
            })
        end
    end
end)

-- ====================================================================
-- 7. EXPORT PRO PLUGINY (API)
-- ====================================================================

-- Tuto funkci budou volat pluginy
local function GetTabletData()
    return {
        isOpen = isTabletOpen,
        battery = currentBattery,
        wifi = {
            isConnected = hasInternet,
            name = currentWifiName,
            level = currentWifiLevel, -- 0-4
            strengthPct = (currentWifiLevel / 4) * 100
        },
        time = {
            hours = GetClockHours(),
            minutes = GetClockMinutes()
        }
    }
end

-- Registrace exportu
exports('GetTabletData', GetTabletData)

RegisterCommand('fixtablet', function()
    isTabletOpen = false
    SetNuiFocus(false, false)
    StopTabletAnimation()
    if tabletProp then
        DeleteEntity(tabletProp)
        tabletProp = nil
    end
    print("[Tablet] Resetován příkazem /fixtablet")
end)

RegisterNetEvent('aprts_tablet:sendNui')
AddEventHandler('aprts_tablet:sendNui', function(data)
    SendNUIMessage(data)
end)
-- ====================================================================
-- 8. OX TARGET INTEGRACE (NABÍJEČKY

-- Registrace Targetu na modely a lokace
CreateThread(function()
    if GetResourceState('ox_target') == 'started' then

        -- 1. Možnost: Kliknutí na předměty (PC, lampičky...)
        exports.ox_target:addModel(Config.ChargerModels, {{
            name = 'tablet_charge_prop',
            icon = 'fas fa-bolt',
            label = 'Připojit tablet k nabíječce',
            onSelect = function(data)
                ConnectCharger(GetEntityCoords(data.entity))
            end,
            canInteract = function(entity)
                return not isConnectedToCharger and currentBattery < 100
            end
        }, {
            name = 'tablet_disconnect_prop',
            icon = 'fas fa-unlink',
            label = 'Odpojit tablet',
            onSelect = function()
                DisconnectCharger()
            end,
            canInteract = function()
                return isConnectedToCharger
            end
        }})

        -- 2. Možnost: Kliknutí na konkrétní lokace (ze souřadnic v Configu)
        for i, coords in ipairs(Config.ChargerLocations) do
            exports.ox_target:addSphereZone({
                coords = coords,
                radius = 1.0,
                debug = false,
                options = {{
                    name = 'tablet_charge_loc_' .. i,
                    icon = 'fas fa-bolt',
                    label = 'Zapojit nabíječku',
                    onSelect = function()
                        ConnectCharger(coords)
                    end,
                    canInteract = function()
                        return not isConnectedToCharger
                    end
                }, {
                    name = 'tablet_disconnect_loc_' .. i,
                    icon = 'fas fa-unlink',
                    label = 'Odpojit nabíječku',
                    onSelect = function()
                        DisconnectCharger()
                    end,
                    canInteract = function()
                        return isConnectedToCharger
                    end
                }}
            })
        end
    end
end)
