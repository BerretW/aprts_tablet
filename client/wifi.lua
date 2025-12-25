-- client/wifi.lua
local LocalRouters = {}
local SpawnedProps = {}

-- STAV PŘIPOJENÍ
local WifiState = {
    enabled = true, -- Je WiFi modul v tabletu zapnutý?
    connected = false, -- Jsme aktuálně připojeni?
    currentSSID = nil, -- Název sítě
    currentLevel = 0, -- Síla signálu (1-4)
    savedNetworks = {} -- Cache uložených hesel { ['SSID'] = 'password' }
}
-- ====================================================================
-- INITIAL SYNC (Přidat na začátek client/wifi.lua)
-- ====================================================================
AddEventHandler("onClientResourceStart", function(resourceName)
    if GetCurrentResourceName() ~= resourceName then
        return
    end
    -- Požádáme server o načtení routerů, jakmile se script zapne
    TriggerServerEvent('aprts_tablet:server:requestRouters')
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    Wait(2000) -- Malá prodleva po načtení
    TriggerServerEvent('aprts_tablet:server:requestRouters')
end)
-- ====================================================================
-- SYNCHRONIZACE DAT
-- ====================================================================

RegisterNetEvent('aprts_tablet:client:syncRouters', function(data)
    LocalRouters = data
    print(json.encode(LocalRouters, { indent = true }))
    RefreshRouterProps()
end)

RegisterNetEvent('aprts_tablet:client:addRouter', function(router)
    LocalRouters[router.id] = router
    SpawnRouterProp(router)
end)

RegisterNetEvent('aprts_tablet:client:removeRouter', function(routerId)
    if SpawnedProps[routerId] then
        if DoesEntityExist(SpawnedProps[routerId]) then
            DeleteEntity(SpawnedProps[routerId])
        end
        SpawnedProps[routerId] = nil
    end
    LocalRouters[routerId] = nil
end)

-- ====================================================================
-- LOGIKA PŘIPOJENÍ A SKENOVÁNÍ
-- ====================================================================

-- Načtení uložených sítí při startu tabletu
RegisterNetEvent('aprts_tablet:client:loadSavedNetworks', function(networks)
    WifiState.savedNetworks = networks or {}
end)

-- Hlavní funkce pro získání aktuálního stavu (volá main.lua ve smyčce)
function GetWifiStatus(playerCoords)
    -- Pokud je WiFi vypnutá uživatelem
    if not WifiState.enabled then
        return {
            connected = false,
            name = "Wi-Fi vypnuta",
            level = 0,
            isLocked = false
        }
    end

    -- 1. Získání všech sítí v dosahu
    local networksInRage = GetNearbyNetworksRaw(playerCoords)

    -- 2. Logika aktuálního připojení
    if WifiState.connected and WifiState.currentSSID then
        -- Jsme připojeni, zkontrolujeme, zda jsme stále v dosahu
        local stillInRange = false
        local currentSignalLevel = 0

        for _, net in ipairs(networksInRage) do
            if net.ssid == WifiState.currentSSID then
                stillInRange = true
                currentSignalLevel = net.levelPct -- Převedeme na 1-4
                break
            end
        end

        if stillInRange then
            -- Aktualizujeme sílu signálu
            if currentSignalLevel > 80 then
                WifiState.currentLevel = 4
            elseif currentSignalLevel > 60 then
                WifiState.currentLevel = 3
            elseif currentSignalLevel > 40 then
                WifiState.currentLevel = 2
            else
                WifiState.currentLevel = 1
            end
        else
            -- Ztratili jsme signál
            DisconnectWifi("Ztráta signálu")
        end
    else
        -- Nejsme připojeni -> Zkusíme AUTO-CONNECT na uložené sítě
        for _, net in ipairs(networksInRage) do
            local savedPass = WifiState.savedNetworks[net.ssid]

            -- Pokud je síť uložená NEBO je veřejná (bez hesla)
            if savedPass or not net.auth then
                -- Simulace pokusu o připojení
                if ConnectToWifi(net.ssid, savedPass) then
                    break -- Připojeno, končíme cyklus
                end
            end
        end
    end

    return {
        connected = WifiState.connected,
        name = WifiState.connected and WifiState.currentSSID or "Nepřipojeno",
        level = WifiState.currentLevel,
        isLocked = (not WifiState.connected) -- Pro UI ikonu zámku
    }
end

-- Interní funkce pro sken okolí (vrací raw data)
function GetNearbyNetworksRaw(coords)
    local networks = {}
    local addedSSIDs = {}

    -- 1. Config Zóny
    for _, zone in pairs(Config.WifiZones) do
        local dist = #(coords - zone.coords)
        if dist < zone.radius then
            local signalPct = math.floor((1.0 - (dist / zone.radius)) * 100)
            if signalPct > 0 then
                table.insert(networks, {
                    ssid = zone.label,
                    levelPct = signalPct,
                    auth = (zone.password ~= nil and zone.password ~= ""),
                    password = zone.password
                })
                addedSSIDs[zone.label] = true
            end
        end
    end

    -- 2. Hráčské Routery
    for _, router in pairs(LocalRouters) do
        if not addedSSIDs[router.ssid] then
            local cfg = Config.RouterTypes[router.type]
            local radius = cfg and cfg.range or 15.0
            local dist = #(coords - vector3(router.coords.x, router.coords.y, router.coords.z))

            if dist < radius then
                local signalPct = math.floor((1.0 - (dist / radius)) * 100)
                if signalPct > 0 then
                    table.insert(networks, {
                        ssid = router.ssid,
                        levelPct = signalPct,
                        auth = (router.password ~= nil and router.password ~= ""),
                        password = router.password -- Pro lokální ověření, server to jistí
                    })
                    addedSSIDs[router.ssid] = true
                end
            end
        end
    end

    table.sort(networks, function(a, b)
        return a.levelPct > b.levelPct
    end)
    return networks
end

-- Funkce pro pokus o připojení
function ConnectToWifi(ssid, password)
    -- Ověření přes server (nebo lokálně pro config zóny pro rychlost)
    local success = false

    -- Rychlý pre-check (jsme vůbec v dosahu?)
    local networks = GetNearbyNetworksRaw(GetEntityCoords(PlayerPedId()))
    local targetNet = nil
    for _, net in ipairs(networks) do
        if net.ssid == ssid then
            targetNet = net
            break
        end
    end

    if not targetNet then
        return false
    end

    -- Ověření
    if not targetNet.auth then
        success = true -- Veřejná síť
    elseif targetNet.password == password then
        success = true -- Heslo sedí (lokální check)
    else
        -- Fallback na server check (pro dynamické routery bezpečnější)
        success = lib.callback.await('aprts_tablet:server:verifyWifi', false, ssid, password)
    end

    if success then
        WifiState.connected = true
        WifiState.currentSSID = ssid
        WifiState.currentLevel = 4 -- Inicializace

        -- Uložit do cache, pokud bylo zadáno heslo
        if password then
            WifiState.savedNetworks[ssid] = password
            -- Trigger server save event (aktualizace DB)
            TriggerServerEvent('aprts_tablet:server:saveKnownNetwork', ssid, password)
        end
        return true
    end

    return false
end

function DisconnectWifi(reason)
    WifiState.connected = false
    WifiState.currentSSID = nil
    WifiState.currentLevel = 0
    if reason then
        print("[WiFi] Odpojeno: " .. reason)
    end
end

-- ====================================================================
-- NUI CALLBACKS
-- ====================================================================

-- Zapnutí/Vypnutí modulu
RegisterNUICallback('toggleWifiState', function(data, cb)
    WifiState.enabled = data.enabled
    if not data.enabled then
        DisconnectWifi("Uživatel vypnul WiFi")
    end
    cb('ok')
end)

-- Získání seznamu sítí pro UI
RegisterNUICallback('getWifiList', function(data, cb)
    if not WifiState.enabled then
        cb({})
        return
    end

    local raw = GetNearbyNetworksRaw(GetEntityCoords(PlayerPedId()))
    local uiList = {}

    for _, net in ipairs(raw) do
        table.insert(uiList, {
            ssid = net.ssid,
            level = net.levelPct,
            auth = net.auth,
            isSaved = (WifiState.savedNetworks[net.ssid] ~= nil),
            isConnected = (WifiState.currentSSID == net.ssid)
        })
    end
    cb(uiList)
end)

-- Ruční připojení z UI
RegisterNUICallback('connectToWifi', function(data, cb)
    local ssid = data.ssid
    local password = data.password

    -- Pokud máme uložené heslo a uživatel ho nezadal znovu
    if not password and WifiState.savedNetworks[ssid] then
        password = WifiState.savedNetworks[ssid]
    end

    local success = ConnectToWifi(ssid, password)

    if success then
        cb({
            status = 'ok'
        })
    else
        cb({
            status = 'error',
            message = 'Nesprávné heslo nebo chyba připojení'
        })
    end
end)

-- Odpojení / Zapomenutí sítě
RegisterNUICallback('forgetNetwork', function(data, cb)
    local ssid = data.ssid

    if WifiState.currentSSID == ssid then
        DisconnectWifi("Uživatel se odpojil")
    end

    if WifiState.savedNetworks[ssid] then
        WifiState.savedNetworks[ssid] = nil
        TriggerServerEvent('aprts_tablet:server:removeKnownNetwork', ssid)
    end
    cb('ok')
end)

-- ====================================================================
-- PROP HANDLING (Zůstává stejné)
-- ====================================================================
function SpawnRouterProp(router)
    print("Spawning router prop for ID: " .. router.id)
    local cfg = Config.RouterTypes[router.type]
    if not cfg then
        return
    end
    local model = GetHashKey(cfg.prop)
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(10)
    end
    local obj = CreateObject(model, router.coords.x, router.coords.y, router.coords.z, false, false, false)
    FreezeEntityPosition(obj, true)
    SetEntityHeading(obj, 0.0)
    PlaceObjectOnGroundProperly(obj)
    SpawnedProps[router.id] = obj
end

function RefreshRouterProps()
    print("Refreshing all router props...")
    for id, entity in pairs(SpawnedProps) do
        if DoesEntityExist(entity) then
            DeleteEntity(entity)
        end
    end
    SpawnedProps = {}
    for id, router in pairs(LocalRouters) do
        SpawnRouterProp(router)
    end
end

lib.callback.register('aprts_tablet:client:openRouterDialog', function()
    local input = lib.inputDialog('Nastavení Routeru', {
        {type = 'input', label = 'Název sítě (SSID)', description = 'Min. 3 znaky', required = true, min = 3, max = 20},
        {type = 'input', label = 'Heslo', description = 'Nechte prázdné pro veřejnou síť', password = true},
    })
    return input
end)