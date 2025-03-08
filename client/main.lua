-- Optimized client-side script with improved performance

-- Notification debounce system
local lastNotifications = {}
local activeTargetZones = {} -- Track all active target zones
local isProcessingTask = false -- Flag to prevent multiple task processing
local taskRequestQueued = false -- Flag to prevent multiple task requests

-- Create a more robust debounced notification function
function SendNotification(title, message, type, duration)
    -- Create a more unique key that includes the message type, source, and timestamp
    local notifKey = title .. message .. (type or "info") .. GetGameTimer()
    
    -- Send the notification
    lib.notify({
        id = notifKey, -- Use a unique ID for each notification
        title = title,
        description = message,
        type = type or 'info',
        duration = duration or 5000,
        position = 'top-right' -- Consistent position
    })
end

-- Debug function - only executes if debug is enabled
function DebugPrint(message)
    -- Use a safe check for Config.Debug that won't error if Config is nil
    if Config and Config.Debug then
        print('[ZCS Debug] ' .. message)
    end
end

-- Initialize variables
ESX = exports['es_extended']:getSharedObject()
local inService = false
local tasksRemaining = 0
local currentCleaningSpot = nil
local cleaningSpots = {}
local blips = {}
local markerThread = nil
local boundaryThread = nil

-- Task types and their animations - improved animations and props
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
        name = "Picking Trash",
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
                    -- If formatting fails, return the unformatted string
                    return Locales[Config.Locale][str]
                end
            else
                return Locales[Config.Locale][str]
            end
        end
        return 'Translation missing: ' .. str
    end
end

-- Initialize client side
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
    
    -- Load cleaning spots from config based on the task type
    -- This ensures we have a reference to all spots for compatibility
    for _, spot in ipairs(Locations.CleaningSpots) do
        table.insert(cleaningSpots, spot)
    end
    
    DebugPrint('Client initialized with ' .. #cleaningSpots .. ' cleaning spots')
end)

-- Event to start community service
RegisterNetEvent('zcs:startService')
AddEventHandler('zcs:startService', function(spotCount)
    inService = true
    tasksRemaining = spotCount
    isProcessingTask = false
    taskRequestQueued = false
    
    -- Teleport to service location
    local ped = PlayerPedId()
    SetEntityCoords(ped, Locations.ServiceLocation.x, Locations.ServiceLocation.y, Locations.ServiceLocation.z)
    
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
end)

-- Start the boundary check thread
function StartBoundaryCheckThread()
    boundaryThread = Citizen.CreateThread(function()
        local warningShown = false
        local warningCooldown = 0
        
        while inService do
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            
            -- Calculate distance from center of restricted area
            local distance = #(vector3(playerCoords.x, playerCoords.y, playerCoords.z) - 
                           vector3(Locations.RestrictedArea.center.x, Locations.RestrictedArea.center.y, Locations.RestrictedArea.center.z))
            
            -- If player is outside the boundary
            if distance > Locations.RestrictedArea.radius then
                -- Show warning if not recently shown
                if not warningShown and GetGameTimer() > warningCooldown then
                    SendNotification('Community Service', _('leaving_area_warning'), 'error', 3000)
                    warningShown = true
                    warningCooldown = GetGameTimer() + 10000 -- 10 second cooldown
                end
                
                -- If player is in a vehicle, remove them from it
                if IsPedInAnyVehicle(playerPed, false) then
                    TaskLeaveVehicle(playerPed, GetVehiclePedIsIn(playerPed, false), 16)
                    Citizen.Wait(500) -- Wait for player to exit vehicle
                end
                
                -- Teleport back to service location
                SetEntityCoords(playerPed, Locations.ServiceLocation.x, Locations.ServiceLocation.y, Locations.ServiceLocation.z)
                
                -- Also notify server for logging
                TriggerServerEvent('zcs:checkPlayerArea', playerCoords)
            else
                warningShown = false
            end
            
            Citizen.Wait(1000) -- Check every second
        end
        
        boundaryThread = nil
    end)
end

-- Completely clear all target zones
function ClearAllTargetZones()
    -- Remove all active target zones
    for zoneId, _ in pairs(activeTargetZones) do
        if zoneId ~= 'zcs_retrieval_point' then -- Don't remove the retrieval point
            exports.ox_target:removeZone(zoneId)
            DebugPrint('Removed target zone: ' .. zoneId)
            activeTargetZones[zoneId] = nil
        end
    end
end

-- Receive a cleaning task from server
RegisterNetEvent('zcs:receiveTask')
AddEventHandler('zcs:receiveTask', function(spotIndex, spot, taskTypeName)
    -- Reset task request flag
    taskRequestQueued = false
    
    -- Prevent processing multiple tasks simultaneously
    if isProcessingTask then
        DebugPrint('Already processing a task, ignoring new task request')
        return
    end
    
    isProcessingTask = true
    
    -- Clear any existing spot and ALL target zones
    ClearCurrentCleaningSpot()
    ClearAllTargetZones()
    
    -- Wait a moment to ensure all zones are properly cleared
    Citizen.Wait(500)
    
    if tasksRemaining <= 0 then
        isProcessingTask = false
        return
    end
    
    -- Find the task type by name
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
    
    -- Create target zones with increased size and unique ID
    local targetId = 'zcs_cleaning_' .. spotIndex
    exports.ox_target:addBoxZone({
        coords = vec3(spot.x, spot.y, spot.z),
        size = vec3(2.5, 2.5, 3.0), -- Increased size
        rotation = 0.0,
        debug = Config.Debug,
        options = {
            {
                name = targetId,
                icon = taskType.icon,
                label = taskType.label,
                onSelect = function()
                    DoCleaningTask(spotIndex, taskType)
                end
            }
        }
    })
    
    -- Add to active zones tracking
    activeTargetZones[targetId] = true
    
    -- Create a marker thread with optimized performance
    if not markerThread then
        StartMarkerThread()
    end
    
    -- Notify player
    SendNotification('Community Service', _('new_task', taskType.name), 'info', 5000)
    
    DebugPrint('Received task at spot ' .. spotIndex .. ' (' .. spot.x .. ', ' .. spot.y .. ', ' .. spot.z .. ')')
    
    -- Reset processing flag
    isProcessingTask = false
end)

-- Start the marker thread with optimized performance
function StartMarkerThread()
    markerThread = Citizen.CreateThread(function()
        while currentCleaningSpot and inService do
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            local spot = currentCleaningSpot.spot
            local distance = #(vector3(playerCoords.x, playerCoords.y, playerCoords.z) - 
                             vector3(spot.x, spot.y, spot.z))
            
            -- Only draw marker when player is close (within configured distance)
            if distance < Config.MarkerRenderDistance then
                -- Draw a more visible marker
                DrawMarker(
                    Config.MarkerType, -- Marker type from config
                    spot.x, spot.y, spot.z - 0.9, -- Position slightly below ground
                    0.0, 0.0, 0.0, 
                    0.0, 0.0, 0.0, 
                    Config.MarkerSize.x, Config.MarkerSize.y, Config.MarkerSize.z, -- Size from config
                    Config.MarkerColor.r, Config.MarkerColor.g, Config.MarkerColor.b, Config.MarkerColor.a, -- Color from config
                    true, false, 2, true, nil, nil, false
                )
                Citizen.Wait(0) -- Update every frame when close
            else
                Citizen.Wait(Config.MarkerUpdateInterval) -- Use configured interval when far away
            end
        end
        
        markerThread = nil
    end)
end

-- Event to update task count
RegisterNetEvent('zcs:updateTaskCount')
AddEventHandler('zcs:updateTaskCount', function(newCount)
    DebugPrint('Updating task count to: ' .. newCount)
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
        DebugPrint('No current cleaning spot, requesting new task')
        -- Use a longer delay to ensure server has time to process
        Citizen.SetTimeout(Config.TaskAssignmentDelay, function()
            if not isProcessingTask and not taskRequestQueued and inService and tasksRemaining > 0 then
                DebugPrint('Requesting new task after task completion')
                taskRequestQueued = true
                TriggerServerEvent('zcs:requestTask')
            end
        end)
    end
end)

-- Improved function to handle the cleaning task animation and completion
function DoCleaningTask(spotIndex, taskType)
    if not currentCleaningSpot or not inService then
        DebugPrint('Cannot do cleaning task: not in service or no current spot')
        return
    end
    
    -- Prevent multiple simultaneous task processing
    if isProcessingTask then
        DebugPrint('Already processing a task, ignoring new task request')
        return
    end
    
    isProcessingTask = true
    
    DebugPrint('Starting cleaning task: ' .. spotIndex)
    
    -- Check if player is close enough to the spot
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local spotCoords = vector3(currentCleaningSpot.spot.x, currentCleaningSpot.spot.y, currentCleaningSpot.spot.z)
    local distance = #(playerCoords - spotCoords)
    
    if distance > Config.InteractionDistance * 2 then
        SendNotification('Community Service', _('too_far_from_task'), 'error')
        isProcessingTask = false
        return
    end
    
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
    
    -- Common progress options
    local progressOptions = {
        duration = Config.ProgressDuration or 10000,
        label = taskType.progressLabel,
        position = 'bottom',
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
    
    local success = false
    
    -- Use the appropriate progress type based on config
    if Config and Config.ProgressStyle == 'circle' then
        success = lib.progressCircle(progressOptions)
    else
        success = lib.progressBar(progressOptions)
    end
    
    -- Clear animation and prop
    ClearPedTasks(playerPed)
    if prop and DoesEntityExist(prop) then
        DetachEntity(prop, true, true)
        DeleteEntity(prop)
    end
    
    if not success then
        SendNotification('Community Service', _('cleaning_interrupted'), 'error')
        isProcessingTask = false
        return
    end
    
    -- Complete the task
    DebugPrint('Completing task: ' .. spotIndex)
    
    -- Store the current spot index and task type before clearing
    local completedSpotIndex = currentCleaningSpot.index
    local completedTaskType = currentCleaningSpot.taskType.name
    
    -- Clear current spot before sending completion to server
    ClearCurrentCleaningSpot()
    
    -- Send completion to server with the task type
    TriggerServerEvent('zcs:completeTask', completedSpotIndex, completedTaskType)
    
    -- Reset processing flag after a short delay
    Citizen.SetTimeout(1000, function()
        isProcessingTask = false
        DebugPrint('Task processing flag reset')
    end)
end

-- Clear current cleaning spot
function ClearCurrentCleaningSpot()
    if currentCleaningSpot then
        -- Remove target zone for this specific spot
        local targetId = 'zcs_cleaning_' .. currentCleaningSpot.index
        if activeTargetZones[targetId] then
            exports.ox_target:removeZone(targetId)
            activeTargetZones[targetId] = nil
            DebugPrint('Removed target zone: ' .. targetId)
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

-- Event to release from service
RegisterNetEvent('zcs:releaseFromService')
AddEventHandler('zcs:releaseFromService', function()
    DebugPrint('Received release from service event')
    
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
    
    -- Teleport to release location after a short delay
    Citizen.SetTimeout(Config.ReleaseDelay, function()
        local ped = PlayerPedId()
        SetEntityCoords(ped, Locations.ReleaseLocation.x, Locations.ReleaseLocation.y, Locations.ReleaseLocation.z)
        
        SendNotification('Community Service', _('service_completed'), 'success', 7000)
        DebugPrint('Player released from service and teleported')
    end)
end)

-- Event to teleport back to service area
RegisterNetEvent('zcs:teleportBack')
AddEventHandler('zcs:teleportBack', function()
    if inService then
        local playerPed = PlayerPedId()
        
        -- If player is in a vehicle, remove them from it
        if IsPedInAnyVehicle(playerPed, false) then
            TaskLeaveVehicle(playerPed, GetVehiclePedIsIn(playerPed, false), 16)
            Citizen.Wait(500) -- Wait for player to exit vehicle
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

-- Clean up on resource stop
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
    
    -- Reset all flags
    inService = false
    isProcessingTask = false
    taskRequestQueued = false
    
    DebugPrint('Resource stopped, cleaned up all resources')
end)

