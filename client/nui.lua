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