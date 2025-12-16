-- ====================================================================
-- ANIMATION HANDLERS
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

-- Cleanup při restartu scriptu
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        if tabletProp then DeleteEntity(tabletProp) end
        if isTabletOpen then SetNuiFocus(false, false) end
        ClearPedTasks(PlayerPedId())
    end
end)