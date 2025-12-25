-- ====================================================================
-- NUI CALLBACKS
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
        -- Zde případná kontrola Jobu
        
        if appData.event then
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
    TriggerEvent(data.appId .. ':handleAction', data.action, data.data)
    cb('ok')
end)

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

exports('SendNui', function(data)
    SendNUIMessage(data)
end)

RegisterNUICallback('addCalendarEvent', function(data, cb)
    if currentSerial then
        TriggerServerEvent('aprts_tablet:server:addCalendarEvent', currentSerial, data.date, data.time, data.title)
    end
    cb('ok')
end)

RegisterNUICallback('deleteCalendarEvent', function(data, cb)
    if currentSerial then
        TriggerServerEvent('aprts_tablet:server:deleteCalendarEvent', currentSerial, data.id)
    end
    cb('ok')
end)

exports("loadContent", function(htmlContent)
    if not isTabletOpen then return end
    print("Loading content into tablet NUI...")
    SendNUIMessage({
        action = "setAppContent",
        html = htmlContent
    })
end)

-- ====================================================================
-- EXPORT & EVENT: ZAVŘENÍ APLIKACE (NÁVRAT NA PLOCHU)
-- ====================================================================

local function CloseActiveApp()
    if isTabletOpen then
        SendNUIMessage({
            action = "closeApp"
        })
    end
end

-- 1. Export
exports('CloseApp', CloseActiveApp)

-- 2. Event (pro volání z jiných scriptů přes TriggerEvent)
RegisterNetEvent('aprts_tablet:client:closeApp', function()
    CloseActiveApp()
end)

RegisterNetEvent('aprts_tablet:forceClose', function()
    CloseActiveApp()
end)