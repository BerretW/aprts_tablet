-- ====================================================================
-- FILE: client/main.lua
-- Popis: Hlavní smyčka, otevírání tabletu a správa stavu
-- ====================================================================

-- ====================================================================
-- 1. POUŽITÍ PŘEDMĚTU (EXPORT)
-- ====================================================================
exports('useTablet', function(data)
    if isTabletOpen then return end
    
    if data and data.slot then
        StartTabletAnimation()
        -- Požádáme server o data tabletu na tomto slotu
        TriggerServerEvent('aprts_tablet:server:openBySlot', data.slot)
    else
        print('^1[Tablet] Chyba: Neplatná data z inventáře!^0')
    end
end)

-- Debug příkazy
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
        
        -- ============================================================
        -- NOVÉ: Předání uložených sítí do WiFi modulu
        -- ============================================================
        if dbData.savedNetworks then
            -- Odesíláme data do client/wifi.lua
            TriggerEvent('aprts_tablet:client:loadSavedNetworks', dbData.savedNetworks)
        else
            TriggerEvent('aprts_tablet:client:loadSavedNetworks', {})
        end
        -- ============================================================

        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        
        -- Inicializace hodnot pro UI
        local initialWifiState = false
        local initialWifiName = "Žádný signál"
        local initialWifiLevel = 0
        local initialWifiLocked = false

        -- 1. Logika SIM Karty (Má absolutní přednost)
        if Config.Tablets[currentModel] and Config.Tablets[currentModel].hasSimCard then
            initialWifiState = true
            initialWifiName = "4G LTE"
            initialWifiLevel = 4
        else
            -- 2. Logika Wi-Fi (Voláme novou funkci z wifi.lua)
            if GetWifiStatus then
                local status = GetWifiStatus(pos)
                
                initialWifiState = status.connected
                initialWifiName = status.name
                initialWifiLevel = status.level
                initialWifiLocked = status.isLocked
                
                -- Aktualizace globálních proměnných
                hasInternet = initialWifiState
                currentWifiName = initialWifiName
                currentWifiLevel = initialWifiLevel
            end
        end

        -- Načtení historie baterie
        batteryHistory = dbData.batteryHistory or {}

        -- Nastavení NUI Focusu
        SetNuiFocus(true, true)

        -- Sestavení dat pro JS
        local payload = {
            action = "bootSystem",
            os = tabletConfig.os,
            storage = tabletConfig.storage or 1024,
            bootTime = tabletConfig.bootTime,
            serial = serial,
            installedApps = dbData.installedApps,
            savedNetworks = dbData.savedNetworks, -- Posíláme i do UI (pro Settings appku)
            wallpaper = dbData.background or tabletConfig.wallpaper,
            calendarEvents = dbData.calendarEvents or {},
            batteryHistory = batteryHistory,
            isLocked = metaData.isLocked,
            pin = metaData.pin,
            
            -- Data o připojení
            wifi = initialWifiState,
            wifiName = initialWifiName,
            wifiLevel = initialWifiLevel,
            wifiLocked = initialWifiLocked,
            
            -- Baterie
            battery = metaData.battery or 100
        }
        
        -- Nastavíme lokální baterii podle serveru
        currentBattery = metaData.battery or 100

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
        -- Interval kontroly (např. 5 sekund, nastaveno v Configu)
        Wait(Config.BatteryTick) 

        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        
        -- Reset indikátorů
        hasInternet = false
        currentWifiName = "Žádný signál"
        currentWifiLevel = 0
        local isLockedWifi = false 

        -- -----------------------------------------------------------
        -- 1. LOGIKA PŘIPOJENÍ (SIM vs WIFI)
        -- -----------------------------------------------------------
        
        -- Má tablet SIM kartu?
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
            -- Používáme Wi-Fi Modul
            if GetWifiStatus then
                -- Tato funkce (v client/wifi.lua) řeší:
                -- 1. Jestli jsme stále připojeni k aktuální síti (vzdálenost)
                -- 2. Jestli se máme automaticky připojit k uložené síti
                local status = GetWifiStatus(pos)
                
                hasInternet = status.connected
                currentWifiName = status.name
                currentWifiLevel = status.level
                isLockedWifi = status.isLocked -- True, pokud nejsme připojeni, ale je v dosahu zamčená síť
            else
                -- Fallback (Pokud by chyběl wifi.lua)
                currentWifiName = "Chyba modulu"
            end
        end

        -- -----------------------------------------------------------
        -- 2. KONTROLA KABELU NABÍJEČKY
        -- -----------------------------------------------------------
        if isConnectedToCharger and chargerCoords then
            -- Pokud se hráč vzdálí od nabíječky, odpojíme ho
            if #(pos - chargerCoords) > 1.5 then
                DisconnectCharger()
            end
        end

        -- -----------------------------------------------------------
        -- 3. LOGIKA BATERIE
        -- -----------------------------------------------------------
        if isConnectedToCharger then
            -- Nabíjení
            if currentBattery < 100 then
                currentBattery = currentBattery + Config.BatteryChargeRate
            end
            if currentBattery > 100 then currentBattery = 100 end

            -- Průběžný update do DB (při nabíjení)
            if chargingSlot and chargingSerial then
                 TriggerServerEvent('aprts_tablet:server:updateBatteryBySlot', chargingSlot, chargingSerial, math.floor(currentBattery))
            end
        elseif isTabletOpen then
            -- Vybíjení (jen když je otevřený)
            if currentBattery > 0 then
                currentBattery = currentBattery - Config.BatteryDrainRate
            end
            if currentBattery < 0 then currentBattery = 0 end
        end

        -- -----------------------------------------------------------
        -- 4. HISTORIE BATERIE (Pro graf)
        -- -----------------------------------------------------------
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

            -- Držíme jen posledních X záznamů
            if #batteryHistory > 48 then
                table.remove(batteryHistory, 1)
            end
        end

        -- -----------------------------------------------------------
        -- 5. ODESLÁNÍ STAVU DO TABLETU (NUI)
        -- -----------------------------------------------------------
        if isTabletOpen then
            local hours = GetClockHours()
            local minutes = GetClockMinutes()
            
            SendNUIMessage({
                action = "updateInfobar",
                time = string.format("%02d:%02d", hours, minutes),
                wifi = hasInternet,
                wifiName = currentWifiName,
                wifiLevel = currentWifiLevel,
                wifiLocked = isLockedWifi, -- Zobrazí zámeček v liště, pokud je signál ale nemáme heslo
                battery = math.floor(currentBattery),
                isCharging = isConnectedToCharger
            })
        end

        -- -----------------------------------------------------------
        -- 6. KRITICKÁ BATERIE (VYPNUTÍ)
        -- -----------------------------------------------------------
        if currentBattery <= 0 and isTabletOpen and not isConnectedToCharger then
            SetNuiFocus(false, false)
            StopTabletAnimation()
            isTabletOpen = false
            TriggerEvent('chat:addMessage', {
                args = {'^1[Tablet]', 'Baterie kritická! Zařízení se vypnulo.'}
            })
            -- Uložení vybitého stavu
            if currentSerial then
                TriggerServerEvent('aprts_tablet:server:updateBattery', currentSerial, 0)
            end
        end
    end
end)