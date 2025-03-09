-- Cache frequently accessed functions to avoid lookup costs
local Wait = Citizen.Wait
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

-- Notification debounce system
local activeTargetZones = {} -- Track all active target zones
local isProcessingTask = false -- Flag to prevent multiple task processing
local taskRequestQueued = false -- Flag to prevent multiple task requests
local inService = false
local tasksRemaining = 0
local currentCleaningSpot = nil
local cleaningSpots = {}
local blips = {}
local markerThread = nil
local boundaryThread = nil
local lastPlayerPos = nil -- Cache player position
local lastFrameTime = 0 -- For throttling operations
local markerUpdateDue = 0 -- Time-based marker updates
local playerPed = nil -- Cache player ped
local playerCoords = nil -- Cache player coordinates
local frameCounter = 0 -- For staggering operations

-- Create a more efficient notification function
function SendNotification(title, message, type, duration)
    lib.notify({
        id = title .. message,
        title = title,
        description = message,
        type = type or 'info',
        duration = duration or 5000
    })
end

-- Debug function - only executes if debug is enabled
function DebugPrint(message)
    if Config and Config.Debug then
        print('[ZCS Debug] ' .. message)
    end
end

-- Initialize variables
ESX = exports['es_extended']:getSharedObject()

-- Cache task types to avoid recreating them
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
        dict = "amb@world_human_gardener_plant@male@base",
        anim = "base",
        prop = {
            model = "prop_cs_trowel",
            bone = 28422,
            pos = vector3(0.0, 0.0, -0.03),
            rot = vector3(0.0, 0.0, 0.0)
        },
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
        dict = "anim@amb@drug_field_workers@rake@male_a@base", 
        anim = "base",
        prop = {
            model = "prop_cs_rub_binbag_01",
            bone = 57005,
            pos = vector3(0.12, 0.0, -0.05),
            rot = vector3(10.0, 0.0, 0.0)
        },
        progressLabel = _('progress_pickingtrash')
    }
}

-- Define a local translation function in case the global one isn't available
if not _ then
    _ = function(str, ...)
        local args = {...}
        if Locales[Config.Locale] and Locales[Config.Locale][str] then
            if #args > 0 then
                local success, result = pcall(string.format, Locales[Config.Locale][str], ...)
                if success then
                    return result
                else
                    return Locales[Config.Locale][str]
                end
            else
                return Locales[Config.Locale][str]
            end
        end
        return 'Translation missing: ' .. str
    end
end

-- Initialize client side - optimized to reduce redundant operations
Citizen.CreateThread(function()
    -- Pre-load all animation dictionaries in the background
    for _, task in ipairs(taskTypes) do
        lib.requestAnimDict(task.dict)
    end
    
    -- Create retrieval point blip with improved appearance
    local retrievalBlip = AddBlipForCoord(Locations.RetrievalPoint.x, Locations.RetrievalPoint.y, Locations.RetrievalPoint.z)
    SetBlipSprite(retrievalBlip, Config.RetrievalBlipSprite)
    SetBlipDisplay(retrievalBlip, 4)
    SetBlipScale(retrievalBlip, Config.RetrievalBlipScale)
    SetBlipColour(retrievalBlip, Config.RetrievalBlipColor)
    SetBlipAlpha(retrievalBlip, Config.RetrievalBlipAlpha)
    SetBlipAsShortRange(retrievalBlip, true)
    SetBlipCategory(retrievalBlip, 10) -- Put in "Services" category
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(_('retrieval_point'))
    EndTextCommandSetBlipName(retrievalBlip)
    
    -- Create retrieval point target with increased size
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
    
    -- Add to active zones
    activeTargetZones[retrievalZoneId] = true
    
    -- Load cleaning spots from config based on the task type - only once at startup
    for _, spot in ipairs(Locations.CleaningSpots) do
        table.insert(cleaningSpots, spot)
    end
    
    -- Initialize cached player data
    playerPed = PlayerPedId()
    playerCoords = GetEntityCoords(playerPed)
    
    DebugPrint('Client initialized with ' .. #cleaningSpots .. ' cleaning spots')
end)

-- Optimize boundary check function with adaptive timing
function StartBoundaryCheckThread()
    boundaryThread = Citizen.CreateThread(function()
        local warningShown = false
        local warningCooldown = 0
        local checkInterval = 2000 -- Start with 2 seconds
        local restrictedCenter = vector3(
            Locations.RestrictedArea.center.x, 
            Locations.RestrictedArea.center.y, 
            Locations.RestrictedArea.center.z
        )
        local restrictedRadius = Locations.RestrictedArea.radius
        local lastDistance = 0
        
        while inService do
            -- Use cached player coordinates when possible
            local distance = #(playerCoords - restrictedCenter)
            
            -- Adaptive timing - check more frequently when near boundary
            if math.abs(distance - restrictedRadius) < 20.0 then
                checkInterval = 1000 -- Check more often when near boundary
            else
                checkInterval = 3000 -- Check less often when far from boundary
            end
            
            -- If player is outside the boundary
            if distance > restrictedRadius then
                -- Show warning if not recently shown
                if not warningShown and GetGameTimer() > warningCooldown then
                    SendNotification('Community Service', _('leaving_area_warning'), 'error', 3000)
                    warningShown = true
                    warningCooldown = GetGameTimer() + 10000 -- 10 second cooldown
                end
                
                -- If player is in a vehicle, remove them from it
                if IsPedInAnyVehicle(playerPed, false) then
                    TaskLeaveVehicle(playerPed, GetVehiclePedIsIn(playerPed, false), 16)
                    Wait(500) -- Wait for player to exit vehicle
                end
                
                -- Teleport back to service location
                SetEntityCoords(playerPed, Locations.ServiceLocation.x, Locations.ServiceLocation.y, Locations.ServiceLocation.z)
                
                -- Only notify server if significantly outside boundary (saves network traffic)
                if distance > restrictedRadius + 20.0 then
                    TriggerServerEvent('zcs:checkPlayerArea', playerCoords)
                end
            else
                warningShown = false
            end
            
            lastDistance = distance
            Wait(checkInterval)
        end
        
        boundaryThread = nil
    end)
end

-- Completely clear all target zones - optimized to reduce redundant operations
function ClearAllTargetZones()
    for zoneId, _ in pairs(activeTargetZones) do
        if zoneId ~= 'zcs_retrieval_point' then -- Don't remove the retrieval point
            exports.ox_target:removeZone(zoneId)
            activeTargetZones[zoneId] = nil
        end
    end
    
    -- Ensure we have an empty table (except for retrieval point)
    local newActiveZones = {}
    if activeTargetZones['zcs_retrieval_point'] then
        newActiveZones['zcs_retrieval_point'] = true
    end
    activeTargetZones = newActiveZones
end

-- Receive a cleaning task from server
RegisterNetEvent('zcs:receiveTask')
AddEventHandler('zcs:receiveTask', function(spotIndex, spot, taskTypeName)
    -- Reset task request flag
    taskRequestQueued = false
    
    -- Prevent processing multiple tasks simultaneously
    if isProcessingTask then
        return
    end
    
    isProcessingTask = true
    
    -- Clear any existing spot and ALL target zones
    ClearCurrentCleaningSpot()
    ClearAllTargetZones()
    
    -- Wait a moment to ensure all zones are properly cleared
    Wait(500)
    
    if tasksRemaining <= 0 then
        isProcessingTask = false
        return
    end
    
    -- Find the task type by name - optimize with direct lookup
    local taskType
    for _, task in ipairs(taskTypes) do
        if task.name == taskTypeName then
            taskType = task
            break
        end
    end
    
    -- If task type not found, select a random one (fallback)
    if not taskType then
        taskType = taskTypes[math.random(1, #taskTypes)]
    end
    
    currentCleaningSpot = {
        spot = spot,
        index = spotIndex,
        taskType = taskType
    }
    
    -- Create blip with improved appearance
    local blip = AddBlipForCoord(spot.x, spot.y, spot.z)
    SetBlipSprite(blip, Config.CleaningBlipSprite)
    SetBlipColour(blip, Config.CleaningBlipColor)
    SetBlipScale(blip, Config.CleaningBlipScale)
    SetBlipAlpha(blip, Config.CleaningBlipAlpha)
    SetBlipAsShortRange(blip, false) -- Visible from further away
    SetBlipCategory(blip, 7) -- Put in "Activities" category
    
    -- Add route to the cleaning spot if enabled
    if Config.CleaningBlipShowRoute then
        SetBlipRoute(blip, true)
        SetBlipRouteColour(blip, Config.CleaningBlipColor)
    end
    
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(taskType.label)
    EndTextCommandSetBlipName(blip)
    table.insert(blips, blip)
    
    -- Generate a unique ID for this specific task instance
    local uniqueTaskId = 'zcs_cleaning_' .. spotIndex .. '_' .. GetGameTimer()
    
    -- Create target zones with increased size and unique ID
    exports.ox_target:addBoxZone({
        coords = vec3(spot.x, spot.y, spot.z),
        size = vec3(2.5, 2.5, 3.0), -- Increased size
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
    
    -- Add to active zones tracking with the unique ID
    activeTargetZones[uniqueTaskId] = true
    
    -- Create a marker thread with optimized performance
    if not markerThread then
        StartMarkerThread()
    end
    
    -- Notify player
    SendNotification('Community Service', _('new_task', taskType.name), 'info', 5000)
    
    -- Reset processing flag
    isProcessingTask = false
end)

-- Modify the zcs:startService event to start the combat prevention thread
RegisterNetEvent('zcs:startService')
AddEventHandler('zcs:startService', function(spotCount)
    inService = true
    tasksRemaining = spotCount
    isProcessingTask = false
    taskRequestQueued = false
    
    -- Teleport to service location
    SetEntityCoords(playerPed, Locations.ServiceLocation.x, Locations.ServiceLocation.y, Locations.ServiceLocation.z)
    
    -- Display UI notification
    SendNotification('Community Service', _('service_started', spotCount), 'info', 7000)
    
    -- Show persistent UI
    lib.showTextUI(_('remaining_tasks', tasksRemaining), {
        position = "top-center",
        icon = 'hammer',
        style = {
            borderRadius = 5,
            backgroundColor = '#1E1E2E',
            color = 'white'
        }
    })
    
    -- Request a new task after a short delay
    Citizen.SetTimeout(500, function()
        if not taskRequestQueued and inService then
            taskRequestQueued = true
            TriggerServerEvent('zcs:requestTask')
        end
    end)
    
    -- Start boundary check thread if not already running
    if not boundaryThread then
        StartBoundaryCheckThread()
    end
    
    -- Start position update thread
    StartPositionUpdateThread()
end)

-- Add a new thread to update player position at a controlled rate
function StartPositionUpdateThread()
    Citizen.CreateThread(function()
        while inService do
            -- Update cached player data
            playerPed = PlayerPedId()
            playerCoords = GetEntityCoords(playerPed)
            frameCounter = (frameCounter + 1) % 60
            
            -- Use a longer wait time to reduce CPU usage
            Wait(500)
        end
    end)
end

-- Ultra-optimized marker thread
function StartMarkerThread()
    markerThread = Citizen.CreateThread(function()
        local nextMarkerUpdate = 0
        local markerRenderDistance = Config.MarkerRenderDistance or 50.0
        
        while currentCleaningSpot and inService do
            local currentTime = GetGameTimer()
            
            -- Only update markers when due
            if currentTime >= nextMarkerUpdate then
                local spot = currentCleaningSpot.spot
                local spotCoords = vector3(spot.x, spot.y, spot.z)
                local distance = #(playerCoords - spotCoords)
                
                -- Only draw marker when player is close (within configured distance)
                if distance < markerRenderDistance then
                    -- Adjust update interval based on distance
                    local updateInterval = distance < 10.0 and 0 or 500
                    
                    -- Only draw markers when player is looking in that direction
                    if distance < 20.0 then
                        -- Draw only one marker type based on distance to save resources
                        if distance < 10.0 then
                            -- Close range - draw both markers but less frequently
                            if frameCounter % 2 == 0 then
                                DrawMarker(
                                    1, -- Vertical cylinder
                                    spot.x, spot.y, spot.z - 0.9,
                                    0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                                    1.0, 1.0, 0.5,
                                    Config.MarkerColor.r, Config.MarkerColor.g, Config.MarkerColor.b, 100,
                                    false, true, 2, true, nil, nil, false
                                )
                            else
                                -- Alternate frames - draw circle marker
                                DrawMarker(
                                    25, -- Thin circle
                                    spot.x, spot.y, spot.z - 0.95,
                                    0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                                    1.2, 1.2, 1.2,
                                    Config.MarkerColor.r, Config.MarkerColor.g, Config.MarkerColor.b, 150,
                                    false, false, 2, true, nil, nil, false
                                )
                            end
                        else
                            -- Medium range - draw only one marker
                            DrawMarker(
                                1, -- Vertical cylinder
                                spot.x, spot.y, spot.z - 0.9,
                                0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                                1.0, 1.0, 0.5,
                                Config.MarkerColor.r, Config.MarkerColor.g, Config.MarkerColor.b, 100,
                                false, true, 2, true, nil, nil, false
                            )
                        end
                    end
                    
                    nextMarkerUpdate = currentTime + updateInterval
                    Wait(0)
                else
                    -- Far away - use a much longer interval
                    nextMarkerUpdate = currentTime + 1000
                    Wait(500)
                end
            else
                -- Not time to update yet
                Wait(100)
            end
        end
        
        markerThread = nil
    end)
end

-- Event to update task count
RegisterNetEvent('zcs:updateTaskCount')
AddEventHandler('zcs:updateTaskCount', function(newCount)
    tasksRemaining = newCount
    
    -- Update the UI with the new count
    lib.hideTextUI() -- Hide first to ensure it refreshes
    Wait(50) -- Small wait to prevent UI flicker
    lib.showTextUI(_('remaining_tasks', tasksRemaining), {
        position = "top-center",
        icon = 'hammer',
        style = {
            borderRadius = 5,
            backgroundColor = '#1E1E2E',
            color = 'white'
        }
    })
    
    -- If no current cleaning spot, request a new one after a short delay
    if not currentCleaningSpot and not taskRequestQueued then
        -- Use a longer delay to ensure server has time to process
        Citizen.SetTimeout(Config.TaskAssignmentDelay, function()
            if not isProcessingTask and not taskRequestQueued and inService and tasksRemaining > 0 then
                taskRequestQueued = true
                TriggerServerEvent('zcs:requestTask')
            end
        end)
    end
end)

-- Optimize the DoCleaningTask function
function DoCleaningTask(spotIndex, taskType)
    if not currentCleaningSpot or not inService then
        return
    end
    
    -- Prevent multiple simultaneous task processing
    if isProcessingTask then
        return
    end
    
    isProcessingTask = true
    
    -- Check if player is close enough to the spot
    local spotCoords = vector3(currentCleaningSpot.spot.x, currentCleaningSpot.spot.y, currentCleaningSpot.spot.z)
    local distance = #(playerCoords - spotCoords)
    
    if distance > Config.InteractionDistance * 2 then
        SendNotification('Community Service', _('too_far_from_task'), 'error')
        isProcessingTask = false
        return
    end
    
    -- Disable inventory and target systems using events
    TriggerEvent('ox_inventory:disableInventory', true)
    TriggerEvent('ox_target:disableTargeting', true)
    
    -- Make sure the animation dictionary is loaded
    if not HasAnimDictLoaded(taskType.dict) then
        lib.requestAnimDict(taskType.dict)
        Wait(100) -- Give it a moment to load
    end
    
    -- Create prop if specified with improved attachment
    local prop = nil
    if taskType.prop and taskType.prop.model then
        prop = CreateObject(GetHashKey(taskType.prop.model), 0, 0, 0, true, true, true)
        AttachEntityToEntity(
            prop, 
            playerPed, 
            GetPedBoneIndex(playerPed, taskType.prop.bone), 
            taskType.prop.pos.x, taskType.prop.pos.y, taskType.prop.pos.z, 
            taskType.prop.rot.x, taskType.prop.rot.y, taskType.prop.rot.z, 
            true, true, false, true, 1, true
        )
    end
    
    -- Start the animation with better parameters
    TaskPlayAnim(playerPed, taskType.dict, taskType.anim, 8.0, -8.0, -1, 49, 0, false, false, false)
    
    -- Progress bar or circle based on configuration
    local progressOptions = {
        duration = Config.ProgressDuration,
        label = taskType.progressLabel,
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
            move = true,
            combat = true,
        },
        anim = {
            dict = taskType.dict,
            clip = taskType.anim,
            flag = 49
        }
    }
    
    -- Add circle type if configured
    if Config and Config.ProgressStyle == 'circle' then
        progressOptions.type = 'circle'
    end
    
    local success = lib.progressBar(progressOptions)
    
    -- Clear animation and prop
    ClearPedTasks(playerPed)
    if prop and DoesEntityExist(prop) then
        DetachEntity(prop, true, true)
        DeleteEntity(prop)
    end
    
    -- Re-enable inventory and target systems
    TriggerEvent('ox_inventory:disableInventory', false)
    TriggerEvent('ox_target:disableTargeting', false)
    
    if not success then
        SendNotification('Community Service', _('cleaning_interrupted'), 'error')
        isProcessingTask = false
        return
    end
    
    -- Complete the task - store values before clearing
    local completedSpotIndex = currentCleaningSpot.index
    local completedTaskType = currentCleaningSpot.taskType.name
    
    -- Clear current spot before sending completion to server
    ClearCurrentCleaningSpot()
    
    -- Send completion to server with the task type
    TriggerServerEvent('zcs:completeTask', completedSpotIndex, completedTaskType)
    
    -- Reset processing flag after a short delay
    Citizen.SetTimeout(1000, function()
        isProcessingTask = false
    end)
end

-- Optimize the ClearCurrentCleaningSpot function
function ClearCurrentCleaningSpot()
    if currentCleaningSpot then
        -- Find and remove all target zones related to this spot
        for zoneId, _ in pairs(activeTargetZones) do
            -- Check if this zone is related to the current cleaning spot
            if string.find(zoneId, 'zcs_cleaning_' .. currentCleaningSpot.index) then
                exports.ox_target:removeZone(zoneId)
                activeTargetZones[zoneId] = nil
            end
        end
        
        -- Remove blips and clear routes
        for _, blip in ipairs(blips) do
            if DoesBlipExist(blip) then
                SetBlipRoute(blip, false) -- Clear route before removing
                RemoveBlip(blip)
            end
        end
        blips = {}
        
        currentCleaningSpot = nil
    end
end

-- Modify the zcs:releaseFromService event to properly stop combat prevention
RegisterNetEvent('zcs:releaseFromService')
AddEventHandler('zcs:releaseFromService', function()
    -- Set flags first to prevent any new tasks
    inService = false
    tasksRemaining = 0
    isProcessingTask = false
    taskRequestQueued = false
    
    -- Clear all cleaning spots and target zones
    ClearCurrentCleaningSpot()
    ClearAllTargetZones()
    
    -- Hide the UI
    lib.hideTextUI()
    
    -- Make sure inventory and target are enabled when released
    TriggerEvent('ox_inventory:disableInventory', false)
    TriggerEvent('ox_target:disableTargeting', false)
    
    -- Teleport to release location after a short delay
    Citizen.SetTimeout(Config.ReleaseDelay, function()
        SetEntityCoords(playerPed, Locations.ReleaseLocation.x, Locations.ReleaseLocation.y, Locations.ReleaseLocation.z)
        
        SendNotification('Community Service', _('service_completed'), 'success', 7000)
    end)
end)

-- Event to teleport back to service area
RegisterNetEvent('zcs:teleportBack')
AddEventHandler('zcs:teleportBack', function()
    if inService then
        -- If player is in a vehicle, remove them from it
        if IsPedInAnyVehicle(playerPed, false) then
            TaskLeaveVehicle(playerPed, GetVehiclePedIsIn(playerPed, false), 16)
            Wait(500) -- Wait for player to exit vehicle
        end
        
        -- Teleport back to service location
        SetEntityCoords(playerPed, Locations.ServiceLocation.x, Locations.ServiceLocation.y, Locations.ServiceLocation.z)
        
        -- Notify player
        SendNotification('Community Service', _('leaving_area_warning'), 'error', 3000)
    end
end)

-- Register the command to open the menu (client-side)
RegisterCommand('cs', function()
    TriggerServerEvent('zcs:checkPermission')
end, false)

-- Optimize the resource stop handler to properly clean up
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then
        return
    end
    
    -- Clean up all target zones
    ClearAllTargetZones()
    
    -- Clean up all blips
    for _, blip in ipairs(blips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    
    -- Hide UI if showing
    if inService then
        lib.hideTextUI()
    end
    
    -- Make sure inventory and target are enabled when resource stops
    TriggerEvent('ox_inventory:disableInventory', false)
    TriggerEvent('ox_target:disableTargeting', false)
    
    -- Reset all flags
    inService = false
    isProcessingTask = false
    taskRequestQueued = false
end)

