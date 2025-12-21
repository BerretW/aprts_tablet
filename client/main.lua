-- ====================================================================
-- FILE: client/main.lua
-- ====================================================================

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

RegisterCommand('fixtablet', function()
    isTabletOpen = false
    SetNuiFocus(false, false)
    StopTabletAnimation()
    print("[Tablet] Resetován příkazem /fixtablet")
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
        currentModel = model 

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

RegisterNetEvent('aprts_tablet:client:setBattery')
AddEventHandler('aprts_tablet:client:setBattery', function(val)
    currentBattery = val
end)

RegisterNetEvent('aprts_tablet:loadContent')
AddEventHandler('aprts_tablet:loadContent', function(htmlContent)
    if not isTabletOpen then return end
    SendNUIMessage({
        action = "setAppContent",
        html = htmlContent
    })
end)

RegisterNetEvent('aprts_tablet:sendNui')
AddEventHandler('aprts_tablet:sendNui', function(data)
    SendNUIMessage(data)
end)

-- ====================================================================
-- MAIN THREAD (Battery, Wifi, Time)
-- ====================================================================
CreateThread(function()
    while true do
        Wait(Config.BatteryTick) 

        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        
        -- Reset indikátorů
        hasInternet = false
        currentWifiName = "Žádný signál"
        currentWifiLevel = 0
        local isLockedWifi = false -- Nová proměnná pro UI (Zámek)

        -- 1. Logika připojení (Simkarta vs Wifi)
        
        -- Má tablet SIM kartu? (Priorita)
        local simCardSupport = false
        if currentModel and Config.Tablets[currentModel] and Config.Tablets[currentModel].hasSimCard then
            simCardSupport = true
        end

        if simCardSupport then
            -- SIM Karta = Vždy internet
            hasInternet = true
            currentWifiName = "4G LTE"
            currentWifiLevel = 4
            isLockedWifi = false
        else
            -- Používáme Wi-Fi
            -- Zde voláme funkci z client/wifi.lua
            if GetBestWifiSignal then
                local signal = GetBestWifiSignal(pos)
                
                hasInternet = signal.connected
                currentWifiName = signal.name
                currentWifiLevel = signal.level
                isLockedWifi = signal.isLocked -- Zjistíme, jestli je síť zamčená
            else
                -- Fallback pro případ, že wifi.lua chybí (pouze statické zóny z Configu)
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
        end

        -- 2. Kontrola kabelu nabíječky
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

        -- 4. Ukládání historie baterie
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
                wifiLocked = isLockedWifi, -- Posíláme info o zámku do JS
                battery = math.floor(currentBattery),
                isCharging = isConnectedToCharger
            })
        end

        -- Kritická baterie - Vypnutí tabletu
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