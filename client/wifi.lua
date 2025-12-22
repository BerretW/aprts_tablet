-- client/wifi.lua
local LocalRouters = {}
local SpawnedProps = {}
-- Cache pro přihlášené sítě (ID routerů i statických zón)
local AuthenticatedRouters = {} 

-- ====================================================================
-- SYNCHRONIZACE DAT
-- ====================================================================

AddEventHandler("onClientResourceStart", function(resourceName)
    if GetCurrentResourceName() ~= resourceName then
        return
    end
    TriggerServerEvent('aprts_tablet:server:requestRouters')
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    TriggerServerEvent('aprts_tablet:server:requestRouters')
end)

RegisterNetEvent('aprts_tablet:client:syncRouters', function(data)
    LocalRouters = data
    RefreshRouterProps()
end)

RegisterNetEvent('aprts_tablet:client:addRouter', function(router)
    LocalRouters[router.id] = router
    SpawnRouterProp(router)
end)

RegisterNetEvent('aprts_tablet:client:removeRouter', function(routerId)
    if SpawnedProps[routerId] then
        if DoesEntityExist(SpawnedProps[routerId]) then DeleteEntity(SpawnedProps[routerId]) end
        SpawnedProps[routerId] = nil
    end
    LocalRouters[routerId] = nil
end)

lib.callback.register('aprts_tablet:client:openRouterDialog', function()
    local input = lib.inputDialog('Nastavení Routeru', {
        {type = 'input', label = 'Název sítě (SSID)', required = true},
        {type = 'input', label = 'Heslo (Nepovinné)', password = true},
    })
    return input
end)

-- ====================================================================
-- PROPS & TARGETING
-- ====================================================================
function SpawnRouterProp(router)
    local cfg = Config.RouterTypes[router.type]
    if not cfg then return end
    
    local model = GetHashKey(cfg.prop)
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(10) end
    
    local obj = CreateObject(model, router.coords.x, router.coords.y, router.coords.z, false, false, false)
    FreezeEntityPosition(obj, true)
    SetEntityHeading(obj, 0.0)
    PlaceObjectOnGroundProperly(obj)
    
    SpawnedProps[router.id] = obj
    
    if exports.ox_target then
        exports.ox_target:addLocalEntity(obj, {
            {
                name = 'pickup_router',
                icon = 'fas fa-hand-holding',
                label = 'Sebrat router ('..router.ssid..')',
                onSelect = function()
                    TriggerServerEvent('aprts_tablet:server:pickupRouter', router.id)
                end
            }
        })
    end
end

function RefreshRouterProps()
    for id, entity in pairs(SpawnedProps) do
        if DoesEntityExist(entity) then DeleteEntity(entity) end
    end
    SpawnedProps = {}
    for id, router in pairs(LocalRouters) do
        SpawnRouterProp(router)
    end
end

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then
        for _, entity in pairs(SpawnedProps) do DeleteEntity(entity) end
    end
end)

-- ====================================================================
-- LOGIKA SIGNÁLU (UPRAVENO PRO STATICKÁ HESLA)
-- ====================================================================

function GetBestWifiSignal(playerCoords)
    local bestSignal = {
        connected = false,
        name = "Žádný signál",
        level = 0,
        isLocked = false,
        routerId = nil,
        isStatic = false -- Flag pro rozlišení v callbacku
    }
    
    -- 1. Kontrola Config Zón
    for _, zone in pairs(Config.WifiZones) do
        local dist = #(playerCoords - zone.coords)
        if dist < zone.radius then
            local lvl = 1
            local signalPct = 1.0 - (dist / zone.radius)
            if signalPct > 0.8 then lvl = 4
            elseif signalPct > 0.6 then lvl = 3
            elseif signalPct > 0.4 then lvl = 2 end
            
            if lvl > bestSignal.level then
                -- ID pro statickou zónu (např: "static_Police Station")
                local zoneId = "static_" .. zone.label 
                
                bestSignal.name = zone.label
                bestSignal.level = lvl
                bestSignal.routerId = zoneId
                bestSignal.isStatic = true
                
                -- Kontrola hesla u statické zóny
                if zone.password and zone.password ~= "" then
                    -- Je zamčená, pokud nejsme v session cache
                    if not AuthenticatedRouters[zoneId] then
                        bestSignal.isLocked = true
                        bestSignal.connected = false 
                    else
                        bestSignal.isLocked = false
                        bestSignal.connected = true
                    end
                else
                    -- Nemá heslo = je veřejná
                    bestSignal.isLocked = false
                    bestSignal.connected = true
                end
            end
        end
    end
    
    -- 2. Kontrola Hráčských Routerů
    for id, router in pairs(LocalRouters) do
        local cfg = Config.RouterTypes[router.type]
        local radius = cfg and cfg.range or 15.0
        local dist = #(playerCoords - vector3(router.coords.x, router.coords.y, router.coords.z))
        
        if dist < radius then
            local lvl = 1
            local signalPct = 1.0 - (dist / radius)
            if signalPct > 0.8 then lvl = 4
            elseif signalPct > 0.6 then lvl = 3
            elseif signalPct > 0.4 then lvl = 2 end
            
            if lvl > bestSignal.level then
                bestSignal.name = router.ssid
                bestSignal.level = lvl
                bestSignal.routerId = router.id
                bestSignal.isStatic = false
                
                if router.password and router.password ~= "" then
                    if not AuthenticatedRouters[router.id] then
                        bestSignal.isLocked = true
                        bestSignal.connected = false
                    else
                        bestSignal.isLocked = false
                        bestSignal.connected = true
                    end
                else
                    bestSignal.isLocked = false
                    bestSignal.connected = true
                end
            end
        end
    end
    
    return bestSignal
end

-- ====================================================================
-- SKENOVÁNÍ SÍTÍ PRO UI (SETTINGS)
-- ====================================================================
function GetNearbyNetworks()
    local networks = {}
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local addedSSIDs = {}

    -- 1. Config Zóny
    for _, zone in pairs(Config.WifiZones) do
        local dist = #(pos - zone.coords)
        if dist < zone.radius then
            local signalPct = math.floor((1.0 - (dist / zone.radius)) * 100)
            if signalPct > 0 then
                table.insert(networks, {
                    ssid = zone.label,
                    level = signalPct,
                    auth = (zone.password ~= nil and zone.password ~= ""), -- True pokud má heslo
                    type = 'public'
                })
                addedSSIDs[zone.label] = true
            end
        end
    end

    -- 2. Routery
    for id, router in pairs(LocalRouters) do
        if not addedSSIDs[router.ssid] then
            local cfg = Config.RouterTypes[router.type]
            local radius = cfg and cfg.range or 15.0
            local dist = #(pos - vector3(router.coords.x, router.coords.y, router.coords.z))
            
            if dist < radius then
                local signalPct = math.floor((1.0 - (dist / radius)) * 100)
                if signalPct > 0 then
                    local isLocked = (router.password and router.password ~= "")
                    table.insert(networks, {
                        ssid = router.ssid,
                        level = signalPct,
                        auth = isLocked,
                        type = 'private'
                    })
                    addedSSIDs[router.ssid] = true
                end
            end
        end
    end

    table.sort(networks, function(a, b) return a.level > b.level end)
    return networks
end

RegisterNUICallback('getWifiList', function(data, cb)
    cb(GetNearbyNetworks())
end)

-- Callback pro pokus o připojení
RegisterNUICallback('connectToWifi', function(data, cb)
    local password = data.password
    local ped = PlayerPedId()
    -- Znovu načteme nejsilnější signál, abychom věděli, kam se připojujeme
    -- (V ideálním případě by ID sítě mělo přijít z JS, ale toto pro zjednodušení stačí, pokud stojíš u routeru)
    local signal = GetBestWifiSignal(GetEntityCoords(ped))
    
    if not signal.routerId then
        cb({status = 'error', message = 'Žádná síť v dosahu'})
        return
    end

    -- Rozlišení Statická vs Dynamická
    if signal.isStatic then
        -- Hledání v Configu podle Labelu (který je uložen v signal.name)
        local correctPassword = nil
        for _, zone in pairs(Config.WifiZones) do
            if zone.label == signal.name then
                correctPassword = zone.password
                break
            end
        end

        if correctPassword == password then
            AuthenticatedRouters[signal.routerId] = true
            cb({status = 'ok'})
        else
            cb({status = 'error'})
        end
    else
        -- Dynamický router -> Server callback
        if signal.isLocked then
            local success = lib.callback.await('aprts_tablet:server:verifyWifi', false, signal.routerId, password)
            if success then
                AuthenticatedRouters[signal.routerId] = true
                cb({status = 'ok'})
            else
                cb({status = 'error'})
            end
        else
            -- Nemá heslo, připojíme rovnou
            AuthenticatedRouters[signal.routerId] = true
            cb({status = 'ok'})
        end
    end
end)