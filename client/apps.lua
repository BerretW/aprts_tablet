-- ====================================================================
-- CLIENT/APPS.LUA
-- ====================================================================

-- PŘIDÁNY ARGUMENTY: appSize (int), supportedOS (table/string/nil)
exports('RegisterApp', function(appName, label, iconClass, color, eventToTrigger, restrictedJobs, appSize, supportedOS)
    
    -- Defaultní hodnoty, pokud plugin nic nepošle
    local size = appSize or 50 -- Defaultně 50 MB
    local osSupport = supportedOS or "all" -- Defaultně funguje všude

    RegisteredApps[appName] = {
        event = eventToTrigger,
        jobs = restrictedJobs,
        size = size,
        os = osSupport
    }

    SendNUIMessage({
        action = "registerApp",
        appName = appName,
        label = label,
        iconClass = iconClass,
        color = color,
        size = size, -- Posíláme do JS
        supportedOS = osSupport, -- Posíláme do JS
        isRestricted = (restrictedJobs ~= nil)
    })
end)

-- Zbytek souboru zůstává stejný (GetTabletData, SetAppBadge atd.)
local function GetTabletData()
    return {
        isOpen = isTabletOpen,
        serial = currentSerial,
        model = currentModel,
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

-- Registrace výchozích aplikací s velikostmi
CreateThread(function()
    Wait(1000)
    -- Syntax: appName, label, icon, color, event, jobs, SIZE (MB), OS_SUPPORT
    exports['aprts_tablet']:RegisterApp('store', 'App Store', 'fas fa-store', '#0984e3', nil, nil, 10, 'all')
    exports['aprts_tablet']:RegisterApp('settings', 'Nastavení', 'fas fa-cog', '#636e72', nil, nil, 15, 'all')
    exports['aprts_tablet']:RegisterApp('calendar', 'Kalendář', 'fas fa-calendar-alt', '#e84393', nil, nil, 25, 'all')
    
    -- Příklad aplikace jen pro moderní tablet
    -- exports['aprts_tablet']:RegisterApp('crypto', 'Crypto', 'fas fa-coins', '#f1c40f', 'crypto:open', nil, 120, {'modern'})
    
    TriggerEvent('aprts_tablet:ready')
end)