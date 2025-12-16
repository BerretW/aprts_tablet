-- ====================================================================
-- FILE: client.lua
-- ====================================================================

local isTabletOpen = false
local tabletProp = nil
local currentSerial = nil
local currentModel = nil -- Uložíme si model pro přístup k OS a Configu
local currentBattery = 100
local lastHistoryUpdate = 0
local batteryHistory = {} 

-- Globální proměnné pro Wi-Fi
local hasInternet = false
local currentWifiName = "Žádný signál"
local currentWifiLevel = 0

-- Animace
local tabletModel = "prop_cs_tablet"
local tabletDict = "amb@world_human_seat_wall_tablet@female@base"
local tabletAnim = "base"

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
-- 1. POUŽITÍ PŘEDMĚTU
-- ====================================================================

exports('useTablet', function(data)
    if isTabletOpen then return end
    
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
AddEventHandler('aprts_tablet:client:loadTablet', function(serial, model, dbData, metaData)
    local tabletConfig = Config.Tablets[model]
    if not tabletConfig then
        print("^1[Tablet] Neznámý model tabletu: " .. tostring(model) .. "^0")
        StopTabletAnimation()
        return
    end

    if not isTabletOpen then
        isTabletOpen = true
        currentSerial = serial
        currentModel = model -- DŮLEŽITÉ: Uložení modelu pro pozdější použití

        -- Načtení historie z DB
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
            batteryHistory = batteryHistory,
            isLocked = metaData.isLocked,
            pin = metaData.pin
        }

        SendNUIMessage(payload)
    end
end)

-- Callbacks
RegisterNUICallback('setPin', function(data, cb)
    TriggerServerEvent('aprts_tablet:server:setPin', data.pin)
    cb('ok')
end)

RegisterNUICallback('setLockState', function(data, cb)
    TriggerServerEvent('aprts_tablet:server:setLockState', data.locked)
    cb('ok')
end)

RegisterNUICallback('unlockSuccess', function(data, cb)
    TriggerServerEvent('aprts_tablet:server:unlockSuccess')
    cb('ok')
end)

RegisterNetEvent('aprts_tablet:client:setBattery')
AddEventHandler('aprts_tablet:client:setBattery', function(val)
    currentBattery = val
end)

-- ====================================================================
-- 3. EXPORTY A REGISTRACE APLIKACÍ
-- ====================================================================

exports('RegisterApp', function(appName, label, iconClass, color, eventToTrigger, restrictedJobs)
    RegisteredApps[appName] = {
        event = eventToTrigger,
        jobs = restrictedJobs
    }
    SendNUIMessage({
        action = "registerApp",
        appName = appName,
        label = label,
        iconClass = iconClass,
        color = color,
        isRestricted = (restrictedJobs ~= nil)
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

    -- Animace telefonu při zavření, pokud nabíjíme
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
        -- KONTROLA JOBU (Příklad pro QBCore)
        -- local PlayerData = QBCore.Functions.GetPlayerData()
        -- local myJob = PlayerData.job.name
        -- if appData.jobs and not appData.jobs[myJob] then ... return cb('error') end

        if appData.event then
            -- DŮLEŽITÁ ÚPRAVA PRO PLUGINY:
            -- Posíláme Serial a OS, aby plugin věděl, s jakým tabletem pracuje
            local osType = "retro"
            if currentModel and Config.Tablets[currentModel] then
                osType = Config.Tablets[currentModel].os
            end

            TriggerEvent(appData.event, currentSerial, osType)
        end
    end
    cb('ok')
end)

RegisterNUICallback('syncData', function(data, cb)
    if currentSerial then
        data.batteryHistory = batteryHistory
        TriggerServerEvent('aprts_tablet:server:saveTabletData', currentSerial, data)
    end
    cb('ok')
end)

RegisterNUICallback('appAction', function(data, cb)
    -- Bridge pro posílání dat z JS do Lua pluginů
    TriggerEvent(data.appId .. ':handleAction', data.action, data.data)
    cb('ok')
end)

RegisterNetEvent('aprts_tablet:loadContent')
AddEventHandler('aprts_tablet:loadContent', function(htmlContent)
    if not isTabletOpen then return end
    SendNUIMessage({
        action = "setAppContent",
        html = htmlContent
    })
end)

-- ====================================================================
-- 5. ANIMACE (S OPRAVOU ANTI-CRASH)
-- ====================================================================

function StartTabletAnimation()
    CreateThread(function()
        local ped = PlayerPedId()
        
        RequestAnimDict(tabletDict)
        local timeout = 0
        while not HasAnimDictLoaded(tabletDict) and timeout < 50 do
            Wait(10)
            timeout = timeout + 1
        end

        RequestModel(tabletModel)
        timeout = 0
        while not HasModelLoaded(tabletModel) and timeout < 50 do
            Wait(10)
            timeout = timeout + 1
        end

        if HasAnimDictLoaded(tabletDict) and HasModelLoaded(tabletModel) then
            tabletProp = CreateObject(GetHashKey(tabletModel), 0, 0, 0, true, true, true)
            AttachEntityToEntity(tabletProp, ped, GetPedBoneIndex(ped, 28422), -0.05, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
            TaskPlayAnim(ped, tabletDict, tabletAnim, 8.0, -8.0, -1, 50, 0, false, false, false)
        else
            print("^1[Tablet] Chyba: Nepodařilo se načíst animaci nebo model.^0")
        end
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
-- 6. NABÍJENÍ A LOGIKA
-- ====================================================================

local chargerCoords = nil
local isConnectedToCharger = false
local chargingSlot = nil 
local chargingSerial = nil 

function ConnectCharger(coords, slot, currentBat, serial)
    if isConnectedToCharger then return end

    local ped = PlayerPedId()
    chargerCoords = coords or GetEntityCoords(ped)
    isConnectedToCharger = true
    
    if slot then
        chargingSlot = slot
        chargingSerial = serial
        currentBattery = currentBat or 0
    else
        chargingSlot = nil 
    end

    TriggerEvent('chat:addMessage', {
        args = {'^2[Tablet]', 'Tablet ('..(serial or "?")..') připojen. Stav: '..math.floor(currentBattery)..'%'}
    })

    if not isTabletOpen then
        RequestAnimDict("cellphone@")
        local timeout = 0
        while not HasAnimDictLoaded("cellphone@") and timeout < 50 do Wait(10); timeout = timeout + 1 end
        TaskPlayAnim(ped, "cellphone@", "cellphone_text_in", 8.0, -8.0, -1, 50, 0, false, false, false)
    end
end

function DisconnectCharger()
    if not isConnectedToCharger then return end
    
    if chargingSlot and chargingSerial then
        TriggerServerEvent('aprts_tablet:server:updateBatteryBySlot', chargingSlot, chargingSerial, math.floor(currentBattery))
    end

    isConnectedToCharger = false
    chargerCoords = nil
    chargingSlot = nil
    chargingSerial = nil

    TriggerEvent('chat:addMessage', {
        args = {'^1[Tablet]', 'Tablet odpojen. Stav: '..math.floor(currentBattery)..'%'}
    })

    if not isTabletOpen then ClearPedTasks(PlayerPedId()) end
end

local function OpenChargerMenu(entityCoords)
    local items = exports.ox_inventory:Search('slots', 'tablet')

    if not items or #items == 0 then
        TriggerEvent('chat:addMessage', { args = {'^1[Tablet]', 'Nemáš u sebe žádný tablet!'} })
        return
    end

    local options = {}

    for _, item in pairs(items) do
        local meta = item.metadata or {}
        local serial = meta.serial or "Neznámý"
        local battery = meta.battery or 100
        local isLocked = meta.locked and "Zamčený" or "Odemčený"
        
        local batColor = "green"
        if battery < 30 then batColor = "red" elseif battery < 60 then batColor = "orange" end

        table.insert(options, {
            title = 'Tablet: ' .. serial,
            description = string.format("Baterie: %s%% | %s", battery, isLocked),
            icon = 'fas fa-tablet-alt',
            iconColor = batColor,
            progress = battery,
            colorScheme = batColor,
            onSelect = function()
                ConnectCharger(entityCoords, item.slot, battery, serial)
            end
        })
    end

    lib.registerContext({
        id = 'tablet_charge_menu',
        title = 'Vyber tablet k nabíjení',
        options = options
    })
    lib.showContext('tablet_charge_menu')
end

exports('ConnectCharger', ConnectCharger)
exports('DisconnectCharger', DisconnectCharger)

-- HLAVNÍ LOOP
CreateThread(function()
    while true do
        Wait(Config.BatteryTick) 

        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        
        -- Reset indikátorů
        hasInternet = false
        currentWifiName = "Žádný signál"
        currentWifiLevel = 0

        -- 1. Wi-Fi Logic (Vylepšená)
        local simCardSupport = false
        if currentModel and Config.Tablets[currentModel] and Config.Tablets[currentModel].hasSimCard then
            simCardSupport = true
        end

        if simCardSupport then
            hasInternet = true
            currentWifiName = "4G LTE"
            currentWifiLevel = 4
        else
            -- Klasické zóny
            for _, zone in pairs(Config.WifiZones) do
                local dist = #(pos - zone.coords)
                if dist < zone.radius then
                    hasInternet = true
                    currentWifiName = zone.label
                    local signalPct = 1.0 - (dist / zone.radius)
                    if signalPct > 0.8 then currentWifiLevel = 4
                    elseif signalPct > 0.6 then currentWifiLevel = 3
                    elseif signalPct > 0.4 then currentWifiLevel = 2
                    else currentWifiLevel = 1 end
                    break
                end
            end
        end

        -- 2. Kontrola kabelu
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
            if currentBattery > 100 then currentBattery = 100 end

            if chargingSlot and chargingSerial then
                 TriggerServerEvent('aprts_tablet:server:updateBatteryBySlot', chargingSlot, chargingSerial, math.floor(currentBattery))
            end
        elseif isTabletOpen then
            if currentBattery > 0 then
                currentBattery = currentBattery - Config.BatteryDrainRate
            end
            if currentBattery < 0 then currentBattery = 0 end
        end

        -- 4. Ukládání historie
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

        -- Kritická baterie
        if currentBattery <= 0 and isTabletOpen and not isConnectedToCharger then
            SetNuiFocus(false, false)
            StopTabletAnimation()
            isTabletOpen = false
            TriggerEvent('chat:addMessage', {
                args = {'^1[Tablet]', 'Baterie kritická!'}
            })
        end
    end
end)

-- ====================================================================
-- 7. EXPORT PRO PLUGINY (API)
-- ====================================================================

local function GetTabletData()
    return {
        isOpen = isTabletOpen,
        serial = currentSerial, -- Přidáno pro pluginy
        model = currentModel,   -- Přidáno pro pluginy
        battery = currentBattery,
        wifi = {
            isConnected = hasInternet,
            name = currentWifiName,
            level = currentWifiLevel,
            strengthPct = (currentWifiLevel / 4) * 100
        },
        time = {
            hours = GetClockHours(),
            minutes = GetClockMinutes()
        }
    }
end

exports('GetTabletData', GetTabletData)

RegisterCommand('fixtablet', function()
    isTabletOpen = false
    SetNuiFocus(false, false)
    StopTabletAnimation()
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
-- 8. OX TARGET INTEGRACE
-- ====================================================================

CreateThread(function()
    if GetResourceState('ox_target') == 'started' then
        exports.ox_target:addModel(Config.ChargerModels, {{
            name = 'tablet_charge_prop',
            icon = 'fas fa-bolt',
            label = 'Připojit tablet k nabíječce',
            onSelect = function(data)
                 OpenChargerMenu(GetEntityCoords(data.entity))
            end,
            canInteract = function(entity)
                return not isConnectedToCharger
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
                        OpenChargerMenu(coords)
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

-- ====================================================================
-- 9. CLEANUP (RESOURCE STOP FIX)
-- ====================================================================
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        if tabletProp then
            DeleteEntity(tabletProp)
        end
        if isTabletOpen then
            SetNuiFocus(false, false)
        end
        ClearPedTasks(PlayerPedId())
    end
end)