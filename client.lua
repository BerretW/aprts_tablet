local isTabletOpen = false
local tabletProp = nil
local currentSerial = nil
local currentBattery = 100
local lastHistoryUpdate = 0 
local batteryHistory = {} -- Tabulka pro historii
local isConnectedToCharger = false
local chargerCoords = nil 

-- Animace
local tabletModel = "prop_cs_tablet"
local tabletDict = "amb@world_human_seat_wall_tablet@female@base"
local tabletAnim = "base"

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
-- 1. POUŽITÍ PŘEDMĚTU
-- ====================================================================

exports('useTablet', function(data)
    if isTabletOpen then return end -- Zamezení spamu
    if data and data.slot then
        StartTabletAnimation()
        TriggerServerEvent('aprts_tablet:server:openBySlot', data.slot)
    else
        print('^1[Tablet] Chyba: Neplatná data z inventáře!^0')
    end
end)

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
    local tabletConfig = Config.Tablets[model]
    if not tabletConfig then 
        print("^1[Tablet] Neznámý model tabletu: "..tostring(model).."^0")
        StopTabletAnimation()
        return 
    end

    if not isTabletOpen then
        isTabletOpen = true
        currentSerial = serial

        -- Načtení historie z DB, pokud existuje
        batteryHistory = dbData.batteryHistory or {}

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
            batteryHistory = batteryHistory -- Posíláme historii grafu
        }

        SendNUIMessage(payload)
    end
end)

RegisterNetEvent('aprts_tablet:client:setBattery')
AddEventHandler('aprts_tablet:client:setBattery', function(val)
    currentBattery = val
end)

-- ====================================================================
-- 3. EXPORTY A REGISTRACE APLIKACÍ
-- ====================================================================

exports('RegisterApp', function(appName, label, iconClass, color, eventToTrigger,restrictedJobs)
    RegisteredApps[appName] = {
        event = eventToTrigger,
        jobs = restrictedJobs -- Např. {['police'] = true, ['ambulance'] = true}
    }
    SendNUIMessage({
        action = "registerApp",
        appName = appName,
        label = label,
        iconClass = iconClass,
        color = color,
        isRestricted = (restrictedJobs ~= nil) -- Info pro JS (např. přidat zámek na ikonu)
    })
end)

CreateThread(function()
    Wait(1000)
    exports['aprts_tablet']:RegisterApp('store', 'App Store', 'fas fa-store', '#0984e3', nil)
    exports['aprts_tablet']:RegisterApp('settings', 'Nastavení', 'fas fa-cog', '#636e72', nil)
    exports['aprts_tablet']:RegisterApp('calendar', 'Kalendář', 'fas fa-calendar-alt', '#e84393', nil)
    TriggerEvent('aprts_tablet:ready')
end)

-- ====================================================================
-- 4. NUI CALLBACKS
-- ====================================================================

RegisterNUICallback('closeTablet', function(data, cb)
    isTabletOpen = false
    SetNuiFocus(false, false)
    StopTabletAnimation()
    
    -- Pokud je připojen k nabíječce a zavře se, necháme animaci nabíjení (pokud chceme), 
    -- nebo ho necháme jen stát. Zde rušíme animaci tabletu.
    if isConnectedToCharger then
        local ped = PlayerPedId()
        RequestAnimDict("cellphone@")
        while not HasAnimDictLoaded("cellphone@") do Wait(10) end
        TaskPlayAnim(ped, "cellphone@", "cellphone_text_in", 8.0, -8.0, -1, 50, 0, false, false, false)
    end

    if currentSerial then
        TriggerServerEvent('aprts_tablet:server:updateBattery', currentSerial, currentBattery)
    end
    cb('ok')
end)

RegisterNUICallback('openAppRequest', function(data, cb)
    local appData = RegisteredApps[data.appId]
    if appData then
        -- KONTROLA JOBU (QBCore příklad)
        local PlayerData = QBCore.Functions.GetPlayerData()
        local myJob = PlayerData.job.name
        
        if appData.jobs and not appData.jobs[myJob] then
            -- Hráč nemá správný job
            TriggerEvent('chat:addMessage', { args = {'^1[Tablet]', 'Nemáš oprávnění pro tuto aplikaci!'} })
            return cb('error')
        end

        if appData.event then
            TriggerEvent(appData.event)
        end
    end
    cb('ok')
end)

RegisterNUICallback('syncData', function(data, cb)
    if currentSerial then
        -- Důležité: Přidáme aktuální serverovou historii do dat k uložení
        data.batteryHistory = batteryHistory 
        TriggerServerEvent('aprts_tablet:server:saveTabletData', currentSerial, data)
    end
    cb('ok')
end)

RegisterNUICallback('appAction', function(data, cb)
    TriggerEvent(data.appId .. ':handleAction', data.action, data.data)
    cb('ok')
end)

RegisterNetEvent('aprts_tablet:loadContent')
AddEventHandler('aprts_tablet:loadContent', function(htmlContent)
    if not isTabletOpen then return end
    SendNUIMessage({ action = "setAppContent", html = htmlContent })
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
    ClearPedTasks(ped) -- Pozor, toto zruší i animaci nabíjení, pokud běží
    if tabletProp then
        DeleteEntity(tabletProp)
        tabletProp = nil
    end
end

-- ====================================================================
-- 6. NABÍJENÍ A LOGIKA
-- ====================================================================

function ConnectCharger(coords)
    if isConnectedToCharger then return end
    local ped = PlayerPedId()
    chargerCoords = coords or GetEntityCoords(ped)
    isConnectedToCharger = true

    TriggerEvent('chat:addMessage', { args = {'^2[Tablet]', 'Tablet připojen k nabíječce.'} })

    if not isTabletOpen then
        RequestAnimDict("cellphone@")
        while not HasAnimDictLoaded("cellphone@") do Wait(10) end
        TaskPlayAnim(ped, "cellphone@", "cellphone_text_in", 8.0, -8.0, -1, 50, 0, false, false, false)
    end
end

function DisconnectCharger()
    if not isConnectedToCharger then return end
    isConnectedToCharger = false
    chargerCoords = nil
    TriggerEvent('chat:addMessage', { args = {'^1[Tablet]', 'Tablet odpojen.'} })
    if not isTabletOpen then ClearPedTasks(PlayerPedId()) end
end

exports('ConnectCharger', ConnectCharger)
exports('DisconnectCharger', DisconnectCharger)

-- HLAVNÍ SYNC LOOP
CreateThread(function()
    while true do
        Wait(Config.BatteryTick) -- Interval 5 sekund

        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        local hasInternet = false
        local currentWifiName = "Žádný signál"
        local currentWifiLevel = 0

        -- 1. Wi-Fi Logic
        for _, zone in pairs(Config.WifiZones) do
            local dist = #(pos - zone.coords)
            if dist < zone.radius then
                hasInternet = true
                currentWifiName = zone.label
                local signalPct = 1.0 - (dist / zone.radius)
                if signalPct > 0.8 then currentWifiLevel = 4
                elseif signalPct > 0.6 then currentWifiLevel = 3
                elseif signalPct > 0.4 then currentWifiLevel = 2
                else currentWifiLevel = 1
                end
                break
            end
        end

        -- 2. Kontrola odpojení kabelem
        if isConnectedToCharger and chargerCoords then
            if #(pos - chargerCoords) > 1.5 then
                DisconnectCharger()
            end
        end

        -- 3. Battery Logic
        if isConnectedToCharger then
            if currentBattery < 100 then
                currentBattery = currentBattery + Config.BatteryChargeRate
            end
        elseif isTabletOpen then
            if currentBattery > 0 then
                currentBattery = currentBattery - Config.BatteryDrainRate
            end
        end

        -- Limity
        if currentBattery > 100 then currentBattery = 100 end
        if currentBattery < 0 then currentBattery = 0 end

        -- 4. Ukládání historie (Interval 30 minut)
        local gameTimer = GetGameTimer()
        if (gameTimer - lastHistoryUpdate) > (Config.HistoryInterval * 60000) then
            lastHistoryUpdate = gameTimer
            local hours = GetClockHours()
            local minutes = GetClockMinutes()
            local timeLabel = string.format("%02d:%02d", hours, minutes)

            table.insert(batteryHistory, {
                time = timeLabel,
                value = math.floor(currentBattery)
            })

            -- Limit historie (48 záznamů = 24 hodin)
            if #batteryHistory > 48 then
                table.remove(batteryHistory, 1)
            end
        end

        -- 5. Odeslání dat do UI
        if isTabletOpen then
            local hours = GetClockHours()
            local minutes = GetClockMinutes()
            SendNUIMessage({
                action = "updateInfobar",
                time = string.format("%02d:%02d", hours, minutes),
                wifi = hasInternet,
                wifiName = currentWifiName,
                wifiLevel = currentWifiLevel,
                battery = math.floor(currentBattery),
                isCharging = isConnectedToCharger
            })
        end

        -- Vybití
        if currentBattery <= 0 and isTabletOpen and not isConnectedToCharger then
            SetNuiFocus(false, false)
            StopTabletAnimation()
            isTabletOpen = false
            TriggerEvent('chat:addMessage', { args = {'^1[Tablet]', 'Baterie kritická!'} })
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

exports('SetAppBadge', function(appName, count)
    SendNUIMessage({
        action = "setAppBadge",
        appName = appName,
        count = count
    })
end)

exports('SaveAppData', function(appName, key, value)
    if currentSerial then
        TriggerServerEvent('aprts_tablet:server:saveAppData', currentSerial, appName, key, value)
    end
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
