local isInService = false
local spotsRemaining = 0
local currentTask = nil
local serviceBlips = {}
local trashBags = {}
local targetZones = {}
local removedZones = {}

-- Framework initialization
local Framework = nil
Citizen.CreateThread(function()
    if Config.Framework == 'ESX' then
        while ESX == nil do
            ESX = exports["es_extended"]:getSharedObject()
            Citizen.Wait(0)
        end
        Framework = ESX
    elseif Config.Framework == 'QBCore' then
        Framework = exports['qb-core']:GetCoreObject()
    end
end)

-- Start community service
function StartCommunityService(spots)
    isInService = true
    spotsRemaining = spots
    CreateServiceBlips()
    SpawnTrashBags()
    CreateTargetZones()
    
    exports.ox_lib:notify({
        title = 'Community Service',
        description = _U('service_started', spotsRemaining),
        type = 'inform'
    })
end

-- End community service
function EndCommunityService()
    isInService = false
    spotsRemaining = 0
    RemoveServiceBlips()
    RemoveTrashBags()
    RemoveTargetZones()
    exports.ox_lib:notify({
        title = 'Community Service',
        description = _U('service_completed'),
        type = 'success'
    })
end

-- Create map blips for service locations
function CreateServiceBlips()
    for _, location in ipairs(Config.ServiceLocations) do
        local blip = AddBlipForCoord(location.coords)
        SetBlipSprite(blip, Config.Blip.sprite)
        SetBlipColour(blip, Config.Blip.color)
        SetBlipScale(blip, Config.Blip.scale)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(location.label)
        EndTextCommandSetBlipName(blip)
        table.insert(serviceBlips, blip)
    end
end

-- Remove map blips
function RemoveServiceBlips()
    for _, blip in ipairs(serviceBlips) do
        RemoveBlip(blip)
    end
    serviceBlips = {}
end

-- Spawn trash bags
function SpawnTrashBags()
    for _, location in ipairs(Config.ServiceLocations) do
        local model = GetHashKey("prop_rub_binbag_sd_01")
        RequestModel(model)
        while not HasModelLoaded(model) do
            Citizen.Wait(1)
        end
        local coords = vector3(location.coords.x, location.coords.y, location.coords.z - 0.5)
        local obj = CreateObject(model, coords, false, true, true)
        PlaceObjectOnGroundProperly(obj)
        FreezeEntityPosition(obj, true)
        SetModelAsNoLongerNeeded(model)
        table.insert(trashBags, {object = obj, location = location})
    end
end

-- Remove trash bags
function RemoveTrashBags()
    for _, bag in ipairs(trashBags) do
        if DoesEntityExist(bag.object) then
            DeleteObject(bag.object)
        end
    end
    trashBags = {}
end

-- Create target zones
function CreateTargetZones()
    for _, location in ipairs(Config.ServiceLocations) do
        local zoneId = exports.ox_target:addSphereZone({
            coords = location.coords,
            radius = 2.0,
            options = {
                {
                    name = 'community_service_task',
                    icon = 'fas fa-broom',
                    label = _U('perform_task'),
                    canInteract = function()
                        return isInService
                    end,
                    onSelect = function()
                        PerformServiceTask(location)
                    end
                }
            }
        })
        table.insert(targetZones, {id = zoneId, coords = location.coords})
    end
end

-- Remove target zones
function RemoveTargetZones()
    for _, zone in ipairs(targetZones) do
        exports.ox_target:removeZone(zone.id)
    end
    targetZones = {}
end

-- Perform service task
function PerformServiceTask(location)
    if currentTask then return end
    currentTask = location

    local playerPed = PlayerPedId()
    local animDict = "amb@world_human_janitor@male@base"
    local animName = "base"

    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do
        Citizen.Wait(10)
    end

    TaskPlayAnim(playerPed, animDict, animName, 8.0, -8.0, -1, 1, 0, false, false, false)

    if exports.ox_lib:progressBar({
        duration = Config.TaskDuration * 1000,
        label = _U('performing_task'),
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
            move = true,
            combat = true,
        },
    }) then
        spotsRemaining = spotsRemaining - 1
        exports.ox_lib:notify({
            title = 'Community Service',
            description = _U('task_completed', spotsRemaining),
            type = 'success'
        })
        
        RemoveTrashBagAtLocation(location)
        TemporarilyRemoveLocationInteraction(location)
        
        if spotsRemaining <= 0 then
            EndCommunityService()
        end
    else
        exports.ox_lib:notify({
            title = 'Community Service',
            description = _U('task_cancelled'),
            type = 'error'
        })
    end
    
    ClearPedTasks(playerPed)
    currentTask = nil
end

-- Remove trash bag at specific location
function RemoveTrashBagAtLocation(location)
    for i, bag in ipairs(trashBags) do
        if bag.location == location then
            if DoesEntityExist(bag.object) then
                DeleteObject(bag.object)
            end
            table.remove(trashBags, i)
            break
        end
    end
end

-- Respawn trash bag
function RespawnTrashBag(location)
    local model = GetHashKey("prop_rub_binbag_sd_01")
    RequestModel(model)
    while not HasModelLoaded(model) do
        Citizen.Wait(1)
    end
    local coords = vector3(location.coords.x, location.coords.y, location.coords.z - 0.5)
    local obj = CreateObject(model, coords, false, true, true)
    PlaceObjectOnGroundProperly(obj)
    FreezeEntityPosition(obj, true)
    SetModelAsNoLongerNeeded(model)
    table.insert(trashBags, {object = obj, location = location})
end

-- Temporarily remove location interaction
function TemporarilyRemoveLocationInteraction(location)
    -- Remove blip
    for i, blip in ipairs(serviceBlips) do
        if GetBlipCoords(blip) == vector3(location.coords.x, location.coords.y, location.coords.z) then
            RemoveBlip(blip)
            table.remove(serviceBlips, i)
            break
        end
    end

    -- Remove target zone
    for i, zone in ipairs(targetZones) do
        if zone.coords == location.coords then
            exports.ox_target:removeZone(zone.id)
            table.insert(removedZones, zone)
            table.remove(targetZones, i)
            break
        end
    end

    -- Respawn after 2 minutes
    SetTimeout(120000, function()
        RespawnLocationInteraction(location)
    end)
end

-- Respawn location interaction
function RespawnLocationInteraction(location)
    -- Respawn blip
    local blip = AddBlipForCoord(location.coords)
    SetBlipSprite(blip, Config.Blip.sprite)
    SetBlipColour(blip, Config.Blip.color)
    SetBlipScale(blip, Config.Blip.scale)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(location.label)
    EndTextCommandSetBlipName(blip)
    table.insert(serviceBlips, blip)

    -- Respawn target zone
    local zoneId = exports.ox_target:addSphereZone({
        coords = location.coords,
        radius = 2.0,
        options = {
            {
                name = 'community_service_task',
                icon = 'fas fa-broom',
                label = _U('perform_task'),
                canInteract = function()
                    return isInService
                end,
                onSelect = function()
                    PerformServiceTask(location)
                end
            }
        }
    })
    table.insert(targetZones, {id = zoneId, coords = location.coords})

    -- Respawn trash bag
    RespawnTrashBag(location)
end

-- Event handler for starting community service
RegisterNetEvent("startCommunityService")
AddEventHandler("startCommunityService", function(spots)
    StartCommunityService(spots)
end)

-- Event handler for opening input dialog
RegisterNetEvent('Z_CommunityService:openInputDialog')
AddEventHandler('Z_CommunityService:openInputDialog', function()
    local input = exports.ox_lib:inputDialog(_U('menu_title'), {
        {type = 'number', label = _U('input_id'), description = _U('input_id'), required = true, min = 1},
        {type = 'number', label = _U('input_spots'), description = _U('input_spots'), required = true, min = 1}
    })

    if input then
        local playerId = input[1]
        local spots = input[2]
        TriggerServerEvent('Z_CommunityService:inputDialogResponse', playerId, spots)
    end
end)
