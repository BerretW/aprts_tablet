-- ====================================================================
-- BATTERY & CHARGING LOGIC
-- ====================================================================

chargerCoords = nil
isConnectedToCharger = false
chargingSlot = nil 
chargingSerial = nil 

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

-- OX TARGET INTEGRACE
CreateThread(function()
    if GetResourceState('ox_target') == 'started' then
        exports.ox_target:addModel(Config.ChargerModels, {{
            name = 'tablet_charge_prop',
            icon = 'fas fa-bolt',
            label = 'Připojit tablet k nabíječce',
            onSelect = function(data) OpenChargerMenu(GetEntityCoords(data.entity)) end,
            canInteract = function(entity) return not isConnectedToCharger end
        }, {
            name = 'tablet_disconnect_prop',
            icon = 'fas fa-unlink',
            label = 'Odpojit tablet',
            onSelect = function() DisconnectCharger() end,
            canInteract = function() return isConnectedToCharger end
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
                    onSelect = function() OpenChargerMenu(coords) end,
                    canInteract = function() return not isConnectedToCharger end
                }, {
                    name = 'tablet_disconnect_loc_' .. i,
                    icon = 'fas fa-unlink',
                    label = 'Odpojit nabíječku',
                    onSelect = function() DisconnectCharger() end,
                    canInteract = function() return isConnectedToCharger end
                }}
            })
        end
    end
end)