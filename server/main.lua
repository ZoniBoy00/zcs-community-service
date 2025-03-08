-- Optimized server-side script with improved performance

-- Notification debounce system
local lastNotifications = {}
local processingTasks = {} -- Track which players are currently processing tasks
local releaseInProgress = {} -- Track players being released to prevent duplicate releases

-- Initialize variables
ESX = exports['es_extended']:getSharedObject()
playersInService = {} -- Make this global so it can be accessed from other files
local playerTasks = {} -- Track current task for each player
local playerLastTaskTime = {} -- Track last task completion time for rate limiting

-- Add task types definition at the top of the file, after the variables initialization
-- Task types for server-side reference
local taskTypes = {
    {name = "Sweeping"},
    {name = "Weeding"},
    {name = "Scrubbing"},
    {name = "PickingTrash"}
}

-- Create a more robust debounced notification function
function SendClientNotification(source, title, message, type, duration)
    -- Generate a more unique key for this notification
    local notifKey = source .. title .. message .. (type or "info") .. GetGameTimer()
    
    -- Send the notification to the client with a unique ID
    TriggerClientEvent('ox_lib:notify', source, {
        id = notifKey,
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
        print('[ZCS] ' .. message)
    end
end

-- Initialize database tables on resource start
MySQL.ready(function()
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS `community_service` (
            `identifier` varchar(60) NOT NULL,
            `spots_assigned` int(11) NOT NULL,
            `spots_remaining` int(11) NOT NULL,
            PRIMARY KEY (`identifier`)
        )
    ]], {}, function()
        print('[ZCS] Community Service database initialized.')
    end)
    
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS `community_service_inventory` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `identifier` varchar(60) NOT NULL,
            `items` longtext,
            `storage_date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`)
        )
    ]], {}, function()
        print('[ZCS] Community Service inventory database initialized.')
    end)
    
    -- Load active service players (optimized query)
    MySQL.Async.fetchAll('SELECT identifier, spots_remaining FROM community_service', {}, function(results)
        for _, data in ipairs(results) do
            playersInService[data.identifier] = data.spots_remaining
        end
        print('[ZCS] Loaded ' .. #results .. ' players in community service')
    end)
end)

-- Check if player has permission to use community service commands
RegisterNetEvent('zcs:checkPermission')
AddEventHandler('zcs:checkPermission', function()
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if HasPermission(xPlayer) then
        TriggerClientEvent('zcs:openMenu', source)
    else
        SendClientNotification(source, 'Community Service', _('no_permission'), 'error')
    end
end)

-- Self-service for testing
RegisterNetEvent('zcs:selfService')
AddEventHandler('zcs:selfService', function(spotCount)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then return end
    
    local identifier = xPlayer.getIdentifier()
    
    -- Store the player's inventory
    StorePlayerInventory(xPlayer)
    
    -- Register the player in the database (single operation)
    MySQL.Async.execute('INSERT INTO community_service (identifier, spots_assigned, spots_remaining) VALUES (@identifier, @spots, @spots) ON DUPLICATE KEY UPDATE spots_assigned = @spots, spots_remaining = @spots', {
        ['@identifier'] = identifier,
        ['@spots'] = spotCount
    }, function()
        playersInService[identifier] = spotCount
        
        -- Teleport player to service location and notify
        TriggerClientEvent('zcs:startService', source, spotCount)
        SendClientNotification(source, 'Community Service', _('service_started', spotCount), 'info', 7000)
        
        DebugPrint('Player ' .. GetPlayerName(source) .. ' put themselves in community service with ' .. spotCount .. ' tasks')
    end)
end)

-- Self-release for testing
RegisterNetEvent('zcs:releaseSelf')
AddEventHandler('zcs:releaseSelf', function()
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then return end
    
    local identifier = xPlayer.getIdentifier()
    
    if not playersInService[identifier] then
        SendClientNotification(source, 'Community Service', _('not_in_service'), 'error')
        return
    end
    
    -- Release the player
    ReleaseFromService(xPlayer)
    
    DebugPrint('Player ' .. GetPlayerName(source) .. ' released themselves from community service')
end)

-- Register a player for community service
RegisterNetEvent('zcs:sendToService')
AddEventHandler('zcs:sendToService', function(target, spotCount)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    local tPlayer = ESX.GetPlayerFromId(target)
    
    -- Security: Verify police permissions
    if not HasPermission(xPlayer) then
        SendClientNotification(source, 'Community Service', _('no_permission'), 'error')
        return
    end
    
    if not tPlayer then
        SendClientNotification(source, 'Community Service', _('player_not_found'), 'error')
        return
    end
    
    local identifier = tPlayer.getIdentifier()
    
    -- Store the player's inventory
    StorePlayerInventory(tPlayer)
    
    -- Register the player in the database (optimized query with single operation)
    MySQL.Async.execute('INSERT INTO community_service (identifier, spots_assigned, spots_remaining) VALUES (@identifier, @spots, @spots) ON DUPLICATE KEY UPDATE spots_assigned = @spots, spots_remaining = @spots', {
        ['@identifier'] = identifier,
        ['@spots'] = spotCount
    }, function()
        playersInService[identifier] = spotCount
        
        -- Teleport player to service location and notify
        TriggerClientEvent('zcs:startService', target, spotCount)
        SendClientNotification(target, 'Community Service', _('service_started', spotCount), 'info', 7000)
        
        -- Notify the officer
        SendClientNotification(source, 'Community Service', _('player_sent', spotCount), 'success')
        
        -- Log to Discord
        LogServiceAssignment(
            GetPlayerName(source),
            xPlayer.getIdentifier(),
            GetPlayerName(target),
            identifier,
            spotCount
        )
    end)
end)

-- Register shorthand command for ease of use
RegisterCommand('cs', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    -- Check permission directly here
    if HasPermission(xPlayer) then
        TriggerClientEvent('zcs:openMenu', source)
    else
        SendClientNotification(source, 'Community Service', _('no_permission'), 'error')
    end
end, false)

-- Register the full command as well
RegisterCommand('communityservice', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    -- Check permission directly here
    if HasPermission(xPlayer) then
        TriggerClientEvent('zcs:openMenu', source)
    else
        SendClientNotification(source, 'Community Service', _('no_permission'), 'error')
    end
end, false)

-- Register testing command
RegisterCommand('cs_test', function(source)
    TriggerClientEvent('zcs:openSelfServiceMenu', source)
end, false)

-- Add tasks to a player's service
RegisterNetEvent('zcs:addTasks')
AddEventHandler('zcs:addTasks', function(target, addCount)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    local tPlayer = ESX.GetPlayerFromId(target)
    
    -- Security: Verify police permissions
    if not HasPermission(xPlayer) then
        SendClientNotification(source, 'Community Service', _('no_permission'), 'error')
        return
    end
    
    if not tPlayer then
        SendClientNotification(source, 'Community Service', _('player_not_found'), 'error')
        return
    end
    
    local identifier = tPlayer.getIdentifier()
    
    if not playersInService[identifier] then
        -- Player not in service, assign new service
        TriggerEvent('zcs:sendToService', target, addCount)
        return
    end
    
    -- Add more tasks to existing service
    local newCount = playersInService[identifier] + addCount
    playersInService[identifier] = newCount
    
    -- Update database (optimized query)
    MySQL.Async.execute('UPDATE community_service SET spots_assigned = spots_assigned + @add_count, spots_remaining = spots_remaining + @add_count WHERE identifier = @identifier', {
        ['@identifier'] = identifier,
        ['@add_count'] = addCount
    })
    
    -- Log to Discord
    LogTasksAdded(
        GetPlayerName(source),
        xPlayer.getIdentifier(),
        GetPlayerName(target),
        identifier,
        addCount,
        newCount
    )
    
    -- Notify player and officer
    TriggerClientEvent('zcs:updateTaskCount', target, newCount)
    SendClientNotification(target, 'Community Service', _('service_extended', addCount), 'info', 7000)
    
    SendClientNotification(source, 'Community Service', _('added_tasks', addCount), 'success')
end)

-- Check player status
RegisterNetEvent('zcs:checkPlayerStatus')
AddEventHandler('zcs:checkPlayerStatus', function(target)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    local tPlayer = ESX.GetPlayerFromId(target)
    
    -- Security: Verify police permissions
    if not HasPermission(xPlayer) then
        SendClientNotification(source, 'Community Service', _('no_permission'), 'error')
        return
    end
    
    if not tPlayer then
        SendClientNotification(source, 'Community Service', _('player_not_found'), 'error')
        return
    end
    
    local identifier = tPlayer.getIdentifier()
    
    if not playersInService[identifier] then
        SendClientNotification(source, 'Community Service', _('player_not_in_service'), 'info')
        return
    end
    
    -- Show player's status with proper formatting
    local statusMessage = string.format(_('player_status'), GetPlayerName(target), playersInService[identifier])
    SendClientNotification(source, 'Community Service Status', statusMessage, 'info', 5000)
    
    DebugPrint('Officer ' .. GetPlayerName(source) .. ' checked status of ' .. GetPlayerName(target) .. ': ' .. playersInService[identifier] .. ' tasks remaining')
end)

-- Release a player from community service
RegisterNetEvent('zcs:releasePlayer')
AddEventHandler('zcs:releasePlayer', function(target)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    local tPlayer = ESX.GetPlayerFromId(target)
    
    -- Security: Verify police permissions
    if not HasPermission(xPlayer) then
        SendClientNotification(source, 'Community Service', _('no_permission'), 'error')
        return
    end
    
    if not tPlayer then
        SendClientNotification(source, 'Community Service', _('player_not_found'), 'error')
        return
    end
    
    local identifier = tPlayer.getIdentifier()
    
    if not playersInService[identifier] then
        SendClientNotification(source, 'Community Service', _('player_not_in_service'), 'info')
        return
    end
    
    -- Get remaining tasks for logging
    local remainingTasks = playersInService[identifier]
    
    -- Release the player
    ReleaseFromService(tPlayer)
    
    -- Notify the officer
    SendClientNotification(source, 'Community Service', _('player_released'), 'success')
    
    -- Log to Discord
    LogForceRelease(
        GetPlayerName(source),
        xPlayer.getIdentifier(),
        GetPlayerName(target),
        identifier,
        remainingTasks
    )
end)

-- Update the task request handler to support task-specific locations

-- Assign a cleaning task to player
RegisterNetEvent('zcs:requestTask')
AddEventHandler('zcs:requestTask', function()
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    local identifier = xPlayer.getIdentifier()
    
    -- Security: Verify player is in service
    if not playersInService[identifier] then
        SendClientNotification(source, 'Community Service', _('not_in_service'), 'error')
        return
    end
    
    -- Check if player is already processing a task
    if processingTasks[identifier] then
        DebugPrint('Player ' .. GetPlayerName(source) .. ' is already processing a task. Ignoring request.')
        return
    end
    
    -- Security: Check for event spamming
    if IsEventSpamming(source, 'zcs:requestTask') then
        return
    end
    
    -- Mark player as processing a task
    processingTasks[identifier] = true
    
    -- Select a random task type
    local taskTypeIndex = math.random(1, #taskTypes)
    local taskTypeName = taskTypes[taskTypeIndex].name
    
    -- If task-specific spots are enabled, get spots only for this task type
    local spots = {}
    local spotIndex = 0
    local spot = nil
    
    if Config.EnableTaskTypeSpecificSpots and Locations.TaskSpots and Locations.TaskSpots[taskTypeName] then
        -- Get spots for this specific task type
        spots = Locations.TaskSpots[taskTypeName]
        if #spots > 0 then
            -- Select a random spot from this task type's spots
            local randomIndex = math.random(1, #spots)
            spot = spots[randomIndex]
            spotIndex = randomIndex
            DebugPrint('Assigned task ' .. taskTypeName .. ' at specific spot ' .. spotIndex)
        else
            -- Fallback to generic spots if task-specific spots are empty
            spotIndex = math.random(1, #Locations.CleaningSpots)
            spot = Locations.CleaningSpots[spotIndex]
            DebugPrint('No specific spots for ' .. taskTypeName .. ', using generic spot ' .. spotIndex)
        end
    else
        -- Use generic spots
        spotIndex = math.random(1, #Locations.CleaningSpots)
        spot = Locations.CleaningSpots[spotIndex]
        DebugPrint('Using generic spot ' .. spotIndex .. ' for task ' .. taskTypeName)
    end
    
    -- Store the assigned task
    playerTasks[identifier] = {
        index = spotIndex,
        position = spot,
        taskType = taskTypeName
    }
    
    DebugPrint('Assigning task ' .. spotIndex .. ' to player ' .. GetPlayerName(source))
    
    -- Send task to client with the task type name
    TriggerClientEvent('zcs:receiveTask', source, spotIndex, spot, taskTypeName)
    
    -- Reset processing flag after a delay
    Citizen.SetTimeout(2000, function()
        processingTasks[identifier] = nil
    end)
end)

-- Update the completeTask event handler to save and respect task type
RegisterNetEvent('zcs:completeTask')
AddEventHandler('zcs:completeTask', function(spotIndex, taskTypeName)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    local identifier = xPlayer.getIdentifier()
    
    DebugPrint('Player ' .. GetPlayerName(source) .. ' attempting to complete task ' .. spotIndex .. ' (' .. (taskTypeName or "unknown") .. ')')
    
    -- Security: Verify player is in service
    if not playersInService[identifier] then
        SendClientNotification(source, 'Community Service', _('not_in_service'), 'error')
        return
    end
    
    -- Check if player is already processing a task
    if processingTasks[identifier] then
        DebugPrint('Player ' .. GetPlayerName(source) .. ' is already processing a task. Ignoring completion request.')
        return
    end
    
    -- Mark player as processing a task
    processingTasks[identifier] = true
    
    -- Security: Check for event spamming
    if IsEventSpamming(source, 'zcs:completeTask') then
        processingTasks[identifier] = nil
        return
    end
    
    -- Rate limiting
    local currentTime = GetGameTimer()
    if playerLastTaskTime[identifier] and (currentTime - playerLastTaskTime[identifier]) < Config.TaskCooldown then
        SendClientNotification(source, 'Community Service', _('cleaning_interrupted'), 'error')
        processingTasks[identifier] = nil
        return
    end
    playerLastTaskTime[identifier] = currentTime
    
    -- Security: Verify this is the assigned task - more lenient check
    if not playerTasks[identifier] or playerTasks[identifier].index ~= spotIndex then
        -- Just log it but allow completion
        DebugPrint('Warning: Player ' .. GetPlayerName(source) .. ' completed task #' .. spotIndex .. 
                  ' but was assigned #' .. (playerTasks[identifier] and playerTasks[identifier].index or "none") .. 
                  '. Allowing completion anyway.')
    end
    
    -- Verify task type if provided
    if taskTypeName and playerTasks[identifier] and playerTasks[identifier].taskType and 
       playerTasks[identifier].taskType ~= taskTypeName then
        DebugPrint('Warning: Player ' .. GetPlayerName(source) .. ' completed task type ' .. taskTypeName .. 
                  ' but was assigned ' .. playerTasks[identifier].taskType .. '. Allowing completion anyway.')
    end
    
    -- Security: Verify player position - make this optional based on config
    if Config.SecurityEnabled and Config.StrictPositionCheck and not VerifyPlayerPosition(source, playerTasks[identifier].position) then
        SendClientNotification(source, 'Community Service', _('cleaning_interrupted'), 'error')
        processingTasks[identifier] = nil
        return
    end
    
    -- Decrement remaining tasks
    playersInService[identifier] = playersInService[identifier] - 1
    
    DebugPrint('Player ' .. GetPlayerName(source) .. ' completed task. Remaining: ' .. playersInService[identifier])
    
    -- Update database (optimized query)
    MySQL.Async.execute('UPDATE community_service SET spots_remaining = @spots_remaining WHERE identifier = @identifier', {
        ['@identifier'] = identifier,
        ['@spots_remaining'] = playersInService[identifier]
    })
    
    -- Notify player of progress
    SendClientNotification(source, 'Community Service', _('task_completed', playersInService[identifier]), 'success')
    
    -- Clear the current task
    playerTasks[identifier] = nil
    
    -- Check if service is completed
    if playersInService[identifier] <= 0 then
        -- Release the player
        ReleaseFromService(xPlayer)
    else
        -- Continue service, update task count
        TriggerClientEvent('zcs:updateTaskCount', source, playersInService[identifier])
        
        -- Reset processing flag after a delay
        Citizen.SetTimeout(1000, function()
            processingTasks[identifier] = nil
            DebugPrint('Processing flag reset for player ' .. GetPlayerName(source))
        end)
    end
end)

-- Release from service function - improved with error handling
function ReleaseFromService(xPlayer)
    local identifier = xPlayer.getIdentifier()
    local source = xPlayer.source
    
    -- Check if release is already in progress
    if releaseInProgress[identifier] then
        DebugPrint('Release already in progress for player ' .. GetPlayerName(source))
        return
    end
    
    -- Set release in progress flag
    releaseInProgress[identifier] = true
    
    -- Get the number of completed tasks for logging
    MySQL.Async.fetchScalar('SELECT spots_assigned FROM community_service WHERE identifier = @identifier', {
        ['@identifier'] = identifier
    }, function(spots_assigned)
        local tasksCompleted = spots_assigned or 0
        
        -- Remove from database
        MySQL.Async.execute('DELETE FROM community_service WHERE identifier = @identifier', {
            ['@identifier'] = identifier
        }, function()
            -- Remove from active service list
            playersInService[identifier] = nil
            playerTasks[identifier] = nil
            playerLastTaskTime[identifier] = nil
            processingTasks[identifier] = nil
            
            -- Notify player
            TriggerClientEvent('zcs:releaseFromService', source)
            SendClientNotification(source, 'Community Service', _('service_completed'), 'success', 7000)
            
            -- Log to Discord
            LogServiceCompletion(GetPlayerName(source), identifier, tasksCompleted)
            
            DebugPrint('Player ' .. GetPlayerName(source) .. ' released from community service')
            
            -- Clear release in progress flag after a delay
            Citizen.SetTimeout(5000, function()
                releaseInProgress[identifier] = nil
            end)
        end)
    end)
end

-- Check player on connect (optimized)
AddEventHandler('esx:playerLoaded', function(playerId, xPlayer)
    local identifier = xPlayer.getIdentifier()
    
    -- Check if player has pending community service (optimized query)
    MySQL.Async.fetchScalar('SELECT spots_remaining FROM community_service WHERE identifier = @identifier', {
        ['@identifier'] = identifier
    }, function(spots_remaining)
        if spots_remaining and spots_remaining > 0 then
            -- Add to active service list
            playersInService[identifier] = spots_remaining
            
            -- Notify player and start service
            TriggerClientEvent('zcs:startService', playerId, spots_remaining)
            SendClientNotification(playerId, 'Community Service', _('service_started', spots_remaining), 'info', 7000)
            
            DebugPrint('Player ' .. GetPlayerName(playerId) .. ' reconnected with ' .. spots_remaining .. ' tasks remaining')
        end
    end)
end)

-- Clean up resources when player disconnects
AddEventHandler('playerDropped', function()
    local source = source
    local identifier = GetPlayerIdentifier(source, 0)
    
    if identifier then
        -- Don't remove from playersInService as they need to resume on reconnect
        playerTasks[identifier] = nil
        playerLastTaskTime[identifier] = nil
        processingTasks[identifier] = nil
        releaseInProgress[identifier] = nil
        
        -- Clean up other tracking data
        if eventCooldowns[identifier] then
            eventCooldowns[identifier] = nil
        end
        
        if playerLastPositions[identifier] then
            playerLastPositions[identifier] = nil
        end
    end
end)

-- Clean up on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then
        return
    end
    
    -- Clean up processing flags
    processingTasks = {}
    releaseInProgress = {}
    
    DebugPrint('Resource stopped, cleaned up all resources')
end)

