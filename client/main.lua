local Wait = Wait
local vector3 = vector3
local GetEntityCoords = GetEntityCoords
local PlayerPedId = PlayerPedId
local GetGameTimer = GetGameTimer
local DoesEntityExist = DoesEntityExist
local DoesBlipExist = DoesBlipExist
local RemoveBlip = RemoveBlip
local SetBlipRoute = SetBlipRoute
local SetEntityCoords = SetEntityCoords
local IsPedInAnyVehicle = IsPedInAnyVehicle
local TaskLeaveVehicle = TaskLeaveVehicle
local ClearPedTasks = ClearPedTasks
local DetachEntity = DetachEntity
local DeleteEntity = DeleteEntity

-- State variables
local activeTargetZones = {}
local isProcessingTask = false
local taskRequestQueued = false
local inService = false
local tasksRemaining = 0
local currentCleaningSpot = nil
local cleaningSpots = {}
local blips = {}
local markerThread = nil
local boundaryThread = nil
local playerPed = nil
local playerCoords = nil
local frameCounter = 0

-- Task configuration
local taskTypes = {
    {
        name = "Sweeping",
        label = _('label_sweeping'),
        icon = "fas fa-broom",
        dict = "amb@world_human_janitor@male@idle_a",
        anim = "idle_a",
        prop = {
            model = "prop_tool_broom",
            bone = 28422,
            pos = vector3(-0.01, 0.04, -0.03),
            rot = vector3(0.0, 0.0, 0.0)
        },
        progressLabel = _('progress_sweeping')
    },
    {
        name = "Weeding",
        label = _('label_weeding'),
        icon = "fas fa-seedling",
        scenario = "WORLD_HUMAN_GARDENER_PLANT",
        progressLabel = _('progress_weeding')
    },
    {
        name = "Scrubbing",
        label = _('label_scrubbing'),
        icon = "fas fa-spray-can",
        dict = "timetable@floyd@clean_kitchen@base",
        anim = "base",
        prop = {
            model = "prop_sponge_01",
            bone = 28422,
            pos = vector3(0.0, 0.05, -0.01),
            rot = vector3(90.0, 0.0, 0.0)
        },
        progressLabel = _('progress_scrubbing')
    },
    {
        name = "PickingTrash",
        label = _('label_pickingtrash'),
        icon = "fas fa-trash",
        scenario = "PROP_HUMAN_BUM_BIN",
        prop = {
            model = "prop_cs_rub_binbag_01",
            bone = 57005,
            pos = vector3(0.12, 0.0, -0.05),
            rot = vector3(10.0, 0.0, 0.0)
        },
        progressLabel = _('progress_pickingtrash')
    }
}

-- Notification utility
function SendNotification(title, message, type, duration)
    lib.notify({
        id = title .. message,
        title = title,
        description = message,
        type = type or 'info',
        duration = duration or 5000
    })
end

-- Debug logging
function DebugPrint(message)
    if Config and Config.Debug then
        print('[ZCS Debug] ' .. message)
    end
end

-- Initialization
CreateThread(function()
    for _, task in ipairs(taskTypes) do
        if task.dict then
            lib.requestAnimDict(task.dict)
        end
    end
    
    local retrievalBlip = AddBlipForCoord(Locations.RetrievalPoint.x, Locations.RetrievalPoint.y, Locations.RetrievalPoint.z)
    SetBlipSprite(retrievalBlip, Config.RetrievalBlipSprite)
    SetBlipDisplay(retrievalBlip, 4)
    SetBlipScale(retrievalBlip, Config.RetrievalBlipScale)
    SetBlipColour(retrievalBlip, Config.RetrievalBlipColor)
    SetBlipAlpha(retrievalBlip, Config.RetrievalBlipAlpha)
    SetBlipAsShortRange(retrievalBlip, true)
    SetBlipCategory(retrievalBlip, 10)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(_('retrieval_point'))
    EndTextCommandSetBlipName(retrievalBlip)
    
    local retrievalZoneId = 'zcs_retrieval_point'
    exports.ox_target:addBoxZone({
        coords = vec3(Locations.RetrievalPoint.x, Locations.RetrievalPoint.y, Locations.RetrievalPoint.z),
        size = vec3(2.5, 2.5, 3.0),
        rotation = 0.0,
        debug = Config.Debug,
        options = {
            {
                name = 'zcs_retrieval',
                icon = 'fas fa-box-open',
                label = _('retrieval_point'),
                onSelect = function()
                    TriggerServerEvent('zcs:retrieveBelongings')
                end
            }
        }
    })
    
    activeTargetZones[retrievalZoneId] = true
    
    for _, spot in ipairs(Locations.CleaningSpots) do
        table.insert(cleaningSpots, spot)
    end
    
    playerPed = PlayerPedId()
    playerCoords = GetEntityCoords(playerPed)
    
    DebugPrint('Client initialized with ' .. #cleaningSpots .. ' cleaning spots')
    
    -- Check if player is already in service (on resource start or rejoin)
    SetTimeout(1000, function()
        TriggerServerEvent('zcs:checkInitialService')
    end)
end)

-- State update and boundary check thread
CreateThread(function()
    local restrictedCenter = vector3(Locations.RestrictedArea.center.x, Locations.RestrictedArea.center.y, Locations.RestrictedArea.center.z)
    local restrictedRadius = Locations.RestrictedArea.radius
    local warningCooldown = 0
    local warningShown = false

    while true do
        playerPed = PlayerPedId()
        playerCoords = GetEntityCoords(playerPed)
        
        if inService then
            local distance = #(playerCoords - restrictedCenter)
            
            if distance > restrictedRadius then
                if not warningShown and GetGameTimer() > warningCooldown then
                    SendNotification('Community Service', _('leaving_area_warning'), 'error', 3000)
                    warningShown = true
                    warningCooldown = GetGameTimer() + 10000
                end
                
                if IsPedInAnyVehicle(playerPed, false) then
                    TaskLeaveVehicle(playerPed, GetVehiclePedIsIn(playerPed, false), 16)
                    Wait(500)
                end
                
                SetEntityCoords(playerPed, Locations.ServiceLocation.x, Locations.ServiceLocation.y, Locations.ServiceLocation.z)
                
                if distance > restrictedRadius + 20.0 then
                    TriggerServerEvent('zcs:checkPlayerArea', playerCoords)
                end
            else
                warningShown = false
            end
            Wait(500)
        else
            Wait(2000)
        end
    end
end)

function ClearAllTargetZones()
    for zoneId, _ in pairs(activeTargetZones) do
        if zoneId ~= 'zcs_retrieval_point' then
            exports.ox_target:removeZone(zoneId)
            activeTargetZones[zoneId] = nil
        end
    end
end

-- Task reception
RegisterNetEvent('zcs:receiveTask', function(spotIndex, spot, taskTypeName)
    taskRequestQueued = false
    
    if isProcessingTask then return end
    isProcessingTask = true
    
    ClearCurrentCleaningSpot()
    ClearAllTargetZones()
    
    Wait(200)
    
    if tasksRemaining <= 0 then
        isProcessingTask = false
        return
    end
    
    local taskType
    for _, task in ipairs(taskTypes) do
        if task.name == taskTypeName then
            taskType = task
            break
        end
    end
    
    taskType = taskType or taskTypes[math.random(1, #taskTypes)]
    
    currentCleaningSpot = {
        spot = spot,
        index = spotIndex,
        taskType = taskType
    }
    
    local blip = AddBlipForCoord(spot.x, spot.y, spot.z)
    SetBlipSprite(blip, Config.CleaningBlipSprite)
    SetBlipColour(blip, Config.CleaningBlipColor)
    SetBlipScale(blip, Config.CleaningBlipScale)
    SetBlipAlpha(blip, Config.CleaningBlipAlpha)
    SetBlipAsShortRange(blip, false)
    SetBlipCategory(blip, 7)
    
    if Config.CleaningBlipShowRoute then
        SetBlipRoute(blip, true)
        SetBlipRouteColour(blip, Config.CleaningBlipColor)
    end
    
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(taskType.label)
    EndTextCommandSetBlipName(blip)
    table.insert(blips, blip)
    
    local uniqueTaskId = 'zcs_cleaning_' .. spotIndex
    local zoneId = exports.ox_target:addBoxZone({
        coords = vec3(spot.x, spot.y, spot.z),
        size = vec3(2.5, 2.5, 3.0),
        rotation = 0.0,
        debug = Config.Debug,
        options = {
            {
                name = uniqueTaskId,
                icon = taskType.icon,
                label = taskType.label,
                onSelect = function()
                    DoCleaningTask(spotIndex, taskType)
                end
            }
        }
    })
    
    currentCleaningSpot.zoneId = zoneId
    activeTargetZones[zoneId] = true
    
    if not markerThread then
        StartMarkerThread()
    end
    
    SendNotification('Community Service', _('new_task', taskType.label), 'info', 5000)
    isProcessingTask = false
end)

-- Service start
RegisterNetEvent('zcs:startService', function(spotCount)
    -- Reset state
    inService = true
    tasksRemaining = spotCount
    isProcessingTask = false
    taskRequestQueued = false
    currentCleaningSpot = nil
    
    -- Ensure player is not in vehicle
    playerPed = PlayerPedId()
    if IsPedInAnyVehicle(playerPed, false) then
        local veh = GetVehiclePedIsIn(playerPed, false)
        TaskLeaveVehicle(playerPed, veh, 16)
        Wait(1000)
    end
    
    SetEntityCoords(playerPed, Locations.ServiceLocation.x, Locations.ServiceLocation.y, Locations.ServiceLocation.z)
    SendNotification('Community Service', _('service_started', spotCount), 'info', 7000)
    
    UpdateUI()
    
    -- Request first task
    SetTimeout(1500, function()
        if not taskRequestQueued and inService then
            taskRequestQueued = true
            TriggerServerEvent('zcs:requestTask')
        end
    end)
end)

function UpdateUI()
    lib.hideTextUI()
    Wait(50)
    lib.showTextUI(_('remaining_tasks', tasksRemaining), {
        position = "top-center",
        icon = 'hammer',
        style = {
            borderRadius = 5,
            backgroundColor = '#1E1E2E',
            color = 'white'
        }
    })
end

function StartMarkerThread()
    if markerThread then return end
    markerThread = true
    
    CreateThread(function()
        while currentCleaningSpot and inService do
            local spot = vector3(currentCleaningSpot.spot.x, currentCleaningSpot.spot.y, currentCleaningSpot.spot.z)
            if #(playerCoords - spot) < 50.0 then
                DrawMarker(2, spot.x, spot.y, spot.z + 0.5, 0.0, 180.0, 0.0, 0.0, 0.0, 0.0, 0.4, 0.4, 0.4, Config.MarkerColor.r, Config.MarkerColor.g, Config.MarkerColor.b, 180, true, true, 2, true, nil, nil, false)
                Wait(0)
            else
                Wait(1000)
            end
        end
        markerThread = nil
    end)
end

-- Task completion update
RegisterNetEvent('zcs:updateTaskCount', function(newCount)
    tasksRemaining = newCount
    UpdateUI()
    
    if not currentCleaningSpot and not taskRequestQueued then
        SetTimeout(Config.TaskAssignmentDelay or 1500, function()
            if not isProcessingTask and not taskRequestQueued and inService and tasksRemaining > 0 then
                taskRequestQueued = true
                TriggerServerEvent('zcs:requestTask')
            end
        end)
    end
end)

-- Task execution logic
function DoCleaningTask(spotIndex, taskType)
    if not currentCleaningSpot or not inService or isProcessingTask then return end
    
    local distance = #(playerCoords - vector3(currentCleaningSpot.spot.x, currentCleaningSpot.spot.y, currentCleaningSpot.spot.z))
    if distance > (Config.InteractionDistance or 3.0) * 2 then
        SendNotification('Community Service', _('too_far_from_task'), 'error')
        return
    end
    
    isProcessingTask = true
    TriggerEvent('ox_inventory:disableInventory', true)
    TriggerEvent('ox_target:disableTargeting', true)
    
    if taskType.dict and not HasAnimDictLoaded(taskType.dict) then
        lib.requestAnimDict(taskType.dict)
        Wait(100)
    end
    
    local prop = nil
    if taskType.prop and taskType.prop.model then
        prop = CreateObject(GetHashKey(taskType.prop.model), 0, 0, 0, true, true, true)
        AttachEntityToEntity(
            prop, playerPed, GetPedBoneIndex(playerPed, taskType.prop.bone), 
            taskType.prop.pos.x, taskType.prop.pos.y, taskType.prop.pos.z, 
            taskType.prop.rot.x, taskType.prop.rot.y, taskType.prop.rot.z, 
            true, true, false, true, 1, true
        )
    end
    
    local animData = {}
    if taskType.scenario then
        animData.scenario = taskType.scenario
    else
        animData.dict = taskType.dict
        animData.clip = taskType.anim
        animData.flag = 49
    end

    local progressOptions = {
        duration = Config.ProgressDuration or 10000,
        label = taskType.progressLabel,
        useWhileDead = false,
        canCancel = true,
        disable = { car = true, move = true, combat = true },
        anim = animData
    }
    
    if Config.ProgressStyle == 'circle' then progressOptions.type = 'circle' end
    
    local success = lib.progressBar(progressOptions)
    
    ClearPedTasks(playerPed)
    if prop and DoesEntityExist(prop) then
        DetachEntity(prop, true, true)
        DeleteEntity(prop)
    end
    
    TriggerEvent('ox_inventory:disableInventory', false)
    TriggerEvent('ox_target:disableTargeting', false)
    
    if not success then
        SendNotification('Community Service', _('cleaning_interrupted'), 'error')
        isProcessingTask = false
        return
    end
    
    local completedSpotIndex = currentCleaningSpot.index
    local completedTaskType = currentCleaningSpot.taskType.name
    
    ClearCurrentCleaningSpot()
    TriggerServerEvent('zcs:completeTask', completedSpotIndex, completedTaskType)
    
    SetTimeout(1000, function()
        isProcessingTask = false
    end)
end

function ClearCurrentCleaningSpot()
    if not currentCleaningSpot then return end
    
    local zoneId = currentCleaningSpot.zoneId
    if zoneId then
        exports.ox_target:removeZone(zoneId)
        activeTargetZones[zoneId] = nil
    end
    
    for _, blip in ipairs(blips) do
        if DoesBlipExist(blip) then
            SetBlipRoute(blip, false)
            RemoveBlip(blip)
        end
    end
    blips = {}
    currentCleaningSpot = nil
end

-- Release from service
RegisterNetEvent('zcs:releaseFromService', function()
    inService = false
    tasksRemaining = 0
    isProcessingTask = false
    taskRequestQueued = false
    
    ClearCurrentCleaningSpot()
    ClearAllTargetZones()
    lib.hideTextUI()
    
    TriggerEvent('ox_inventory:disableInventory', false)
    TriggerEvent('ox_target:disableTargeting', false)
    
    SetTimeout(Config.ReleaseDelay or 1000, function()
        SetEntityCoords(playerPed, Locations.ReleaseLocation.x, Locations.ReleaseLocation.y, Locations.ReleaseLocation.z)
        SendNotification('Community Service', _('service_completed'), 'success', 7000)
    end)
end)

RegisterNetEvent('zcs:teleportBack', function()
    if not inService then return end
    
    if IsPedInAnyVehicle(playerPed, false) then
        local vehicle = GetVehiclePedIsIn(playerPed, false)
        TaskLeaveVehicle(playerPed, vehicle, 16)
        Wait(500)
    end
    
    SetEntityCoords(playerPed, Locations.ServiceLocation.x, Locations.ServiceLocation.y, Locations.ServiceLocation.z)
    SendNotification('Community Service', _('leaving_area_warning'), 'error', 3000)
end)

RegisterCommand('cs', function()
    TriggerServerEvent('zcs:checkPermission')
end, false)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    ClearAllTargetZones()
    for _, blip in ipairs(blips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    
    if inService then lib.hideTextUI() end
    TriggerEvent('ox_inventory:disableInventory', false)
    TriggerEvent('ox_target:disableTargeting', false)
end)
