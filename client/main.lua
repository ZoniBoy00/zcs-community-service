-- Optimized client-side script with improved performance

-- Notification debounce system
local lastNotifications = {}
local activeTargetZones = {} -- Track all active target zones
local isProcessingTask = false -- Flag to prevent multiple task processing
local taskRequestQueued = false -- Flag to prevent multiple task requests
local combatControlsThread = nil
local inService = false
local tasksRemaining = 0
local currentCleaningSpot = nil
local cleaningSpots = {}
local blips = {}
local markerThread = nil
local boundaryThread = nil
local lastCombatControlTime = 0
local combatControlInterval = 100 -- Check combat controls every 100ms instead of every frame

-- Pre-cache frequently used values
local COMBAT_CONTROLS = {
    24, 25, 47, 58, 140, 141, 142, 143, 263, 264, 257, 37, 
    157, 158, 160, 164, 165, 159, 161, 162, 163
}

-- Function to disable combat controls - optimized to run less frequently
function DisableCombatControls()
    local currentTime = GetGameTimer()
    if currentTime - lastCombatControlTime < combatControlInterval then
        return -- Skip if we checked recently
    end
    
    lastCombatControlTime = currentTime
    
    -- Check if player is trying to use a weapon before disabling controls
    local playerPed = PlayerPedId()
    if IsPedArmed(playerPed, 4) or IsPedArmed(playerPed, 1) or IsPedArmed(playerPed, 2) then
        -- Only disable controls if player is trying to use weapons
        for _, control in ipairs(COMBAT_CONTROLS) do
            DisableControlAction(0, control, true)
        end
    end
end

-- Create a more efficient notification function
function SendNotification(title, message, type, duration)
    lib.notify({
        id = title .. message .. GetGameTimer(),
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

-- Optimize the boundary check thread to use less resources
function StartBoundaryCheckThread()
    boundaryThread = Citizen.CreateThread(function()
        local warningShown = false
        local warningCooldown = 0
        local checkInterval = 1000 -- Check every second
        local restrictedCenter = vector3(
            Locations.RestrictedArea.center.x, 
            Locations.RestrictedArea.center.y, 
            Locations.RestrictedArea.center.z
        )
        local restrictedRadius = Locations.RestrictedArea.radius
        
        while inService do
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            
            -- Calculate distance from center of restricted area
            local distance = #(playerCoords - restrictedCenter)
            
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
                    Citizen.Wait(500) -- Wait for player to exit vehicle
                end
                
                -- Teleport back to service location
                SetEntityCoords(playerPed, Locations.ServiceLocation.x, Locations.ServiceLocation.y, Locations.ServiceLocation.z)
                
                -- Also notify server for logging
                TriggerServerEvent('zcs:checkPlayerArea', playerCoords)
            else
                warningShown = false
            end
            
            -- Also handle combat controls here instead of a separate thread
            if inService then
                DisableCombatControls()
            end
            
            Citizen.Wait(checkInterval)
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
    Citizen.Wait(500)
    
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
    
    -- Reset processing flag
    isProcessingTask = false
end)

-- Optimize the marker thread to use less resources
function StartMarkerThread()
    markerThread = Citizen.CreateThread(function()
        local markerUpdateInterval = Config.MarkerUpdateInterval or 250
        local markerRenderDistance = Config.MarkerRenderDistance or 50.0
        
        while currentCleaningSpot and inService do
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            local spot = currentCleaningSpot.spot
            local spotCoords = vector3(spot.x, spot.y, spot.z)
            local distance = #(playerCoords - spotCoords)
            
            -- Only draw marker when player is close (within configured distance)
            if distance < markerRenderDistance then
                -- Adjust update interval based on distance
                local updateInterval = distance < 10.0 and 0 or markerUpdateInterval
                
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
                
                Citizen.Wait(updateInterval)
            else
                -- Use a longer interval when far away
                Citizen.Wait(markerUpdateInterval * 2)
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
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
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
        -- Remove target zone for this specific spot
        local targetId = 'zcs_cleaning_' .. currentCleaningSpot.index
        if activeTargetZones[targetId] then
            exports.ox_target:removeZone(targetId)
            activeTargetZones[targetId] = nil
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

-- Optimize the release from service event
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
        local ped = PlayerPedId()
        SetEntityCoords(ped, Locations.ReleaseLocation.x, Locations.ReleaseLocation.y, Locations.ReleaseLocation.z)
        
        SendNotification('Community Service', _('service_completed'), 'success', 7000)
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

-- Optimize the resource stop handler
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

