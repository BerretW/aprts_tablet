local isTabletOpen = false
local tabletProp = nil
local currentSerial = nil -- Zde si držíme sériové číslo aktuálně otevřeného tabletu

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
        ['tablet_basic'] = { os = "retro", bootTime = 3000, wallpaper = "none" },
        ['tablet_pro'] = { os = "modern", bootTime = 1500, wallpaper = "https://files.catbox.moe/w8s1z6.jpg" }
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
        currentSerial = serial -- !!! DŮLEŽITÉ: Uložíme serial do globální proměnné !!!
        SetNuiFocus(true, true)

        local payload = {
            action = "bootSystem",
            os = tabletConfig.os,
            storage = tabletConfig.storage or 1024,
            bootTime = tabletConfig.bootTime,
            
            serial = serial,
            installedApps = dbData.installedApps, 
            wallpaper = dbData.background or tabletConfig.wallpaper,
            calendarEvents = dbData.calendarEvents or {} -- Ujištění, že posíláme kalendář
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

-- Zavření tabletu
RegisterNUICallback('closeTablet', function(data, cb)
    isTabletOpen = false
    SetNuiFocus(false, false)
    StopTabletAnimation()
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
    cb({ success = true })
end)

-- Příjem obsahu (HTML) z pluginů
RegisterNetEvent('aprts_tablet:loadContent') -- Zachována zpětná kompatibilita názvu eventu
AddEventHandler('aprts_tablet:loadContent', function(htmlContent)
    -- Bezpečnostní kontrola
    if not isTabletOpen then return end 

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
        while not HasAnimDictLoaded(tabletDict) do Wait(10) end
        
        RequestModel(tabletModel)
        while not HasModelLoaded(tabletModel) do Wait(10) end

        tabletProp = CreateObject(GetHashKey(tabletModel), 0, 0, 0, true, true, true)
        AttachEntityToEntity(tabletProp, ped, GetPedBoneIndex(ped, 28422), -0.05, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
        
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
local currentBattery = 100
local currentWifiLevel = 0 -- 0 až 4 čárky
local currentWifiName = "Žádný signál"
local hasInternet = false

-- Funkce pro výpočet stavu (Interní)
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
            
            -- Výpočet síly signálu podle vzdálenosti (jednoduchá matematika)
            local signalPct = 1.0 - (dist / zone.radius)
            if signalPct > 0.8 then currentWifiLevel = 4
            elseif signalPct > 0.6 then currentWifiLevel = 3
            elseif signalPct > 0.4 then currentWifiLevel = 2
            else currentWifiLevel = 1 end
            
            break -- Jsme v dosahu jedné, stačí
        end
    end

    -- 2. Baterie Logic (vybíjí se jen když je tablet otevřený)
    if isTabletOpen and currentBattery > 0 then
        -- Vybíjení: Náhodně odečte 1% každých cca 20-30 sekund loopu
        if math.random(1, 100) < 5 then 
            currentBattery = currentBattery - 1
        end
    elseif not isTabletOpen and currentBattery < 100 then
        -- Nabíjení v kapse (pomalé)
        if math.random(1, 100) < 2 then
            currentBattery = currentBattery + 1
        end
    end
end

-- Hlavní loop
CreateThread(function()
    while true do
        UpdateSystemStatus() -- Aktualizovat data

        if isTabletOpen then
            local hours = GetClockHours()
            local minutes = GetClockMinutes()
            if hours < 10 then hours = "0" .. hours end
            if minutes < 10 then minutes = "0" .. minutes end
            local timeString = hours .. ":" .. minutes

            -- Odeslání do UI
            SendNUIMessage({
                action = "updateInfobar",
                time = timeString,
                wifi = hasInternet,
                wifiName = currentWifiName,
                wifiLevel = currentWifiLevel, -- Posíláme i level
                battery = currentBattery      -- Posíláme i baterii
            })

            Wait(2000)
        else
            Wait(5000) -- Když je zavřený, kontrolujeme méně často
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