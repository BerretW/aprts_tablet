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
    -- data obsahuje informace o itemu (slot, metadata, name...)
    if data and data.metadata and data.metadata.serial then
        local serial = data.metadata.serial
        currentSerial = serial
        
        -- Animace
        StartTabletAnimation()

        -- Požádáme server o data k tomuto sériovému číslu
        -- Server vrátí event 'aprts_tablet:client:loadTablet'
        TriggerServerEvent('aprts_tablet:server:getTabletData', serial)
    else
        -- Fallback pro itemy bez metadat (např. admin spawnuté bez sériovky)
        print('^1[Tablet] Chyba: Tablet nemá sériové číslo!^0')
        -- Můžeme vygenerovat dočasné číslo nebo odmítnout otevření
        currentSerial = "TEMP-"..math.random(1000,9999)
        StartTabletAnimation()
        TriggerServerEvent('aprts_tablet:server:getTabletData', currentSerial)
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
AddEventHandler('aprts_tablet:client:loadTablet', function(model, dbData)
    -- model = 'tablet_basic' nebo 'tablet_pro'
    -- dbData = { installedApps = {...}, background = "url", ... }

    local tabletConfig = Config.Tablets[model]
    if not tabletConfig then 
        print("^1[Tablet] Neznámý model tabletu: "..tostring(model).."^0")
        StopTabletAnimation()
        return 
    end

    if not isTabletOpen then
        isTabletOpen = true
        SetNuiFocus(true, true)

        -- Sloučíme Config data (hardware) s DB daty (software)
        local payload = {
            action = "bootSystem",
            -- Hardware stats (z Configu)
            os = tabletConfig.os,
            storage = tabletConfig.storage or 1024,
            bootTime = tabletConfig.bootTime,
            
            -- User data (z SQL)
            serial = currentSerial,
            installedApps = dbData.installedApps, 
            wallpaper = dbData.background or tabletConfig.wallpaper -- Priorita DB, pak Config
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
    if currentSerial then
        -- data obsahuje { installedApps: [...], background: ... }
        TriggerServerEvent('aprts_tablet:server:saveTabletData', currentSerial, data)
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
RegisterNetEvent('dt_tablet:loadContent') -- Zachována zpětná kompatibilita názvu eventu
AddEventHandler('dt_tablet:loadContent', function(htmlContent)
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