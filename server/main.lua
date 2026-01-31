-- Optimized server-side logic for Community Service (QBox)
local function GetPlayerData(id)
    local p = exports.qbx_core:GetPlayer(id)
    return p and p.PlayerData
end

local function GetCharacterName(source)
    local p = exports.qbx_core:GetPlayer(source)
    if p and p.PlayerData and p.PlayerData.charinfo then
        local ci = p.PlayerData.charinfo
        return ci.firstname .. ' ' .. ci.lastname
    end
    return GetPlayerName(source)
end

-- State Tracking
local processingTasks = {}
local releaseInProgress = {}
playersInService = {} -- Global for security verification
local playerTasks = {}
local playerLastTaskTime = {}

-- Standardized notification sender
local function SendClientNotification(source, title, message, type, duration)
    TriggerClientEvent('ox_lib:notify', source, {
        title = title,
        description = message,
        type = type or 'info',
        duration = duration or 5000,
        position = 'top-right'
    })
end

function DebugPrint(message)
    if Config and Config.Debug then
        print('^2[ZCS Debug]^0 ' .. message)
    end
end

-- Database initialization
MySQL.ready(function()
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `community_service` (
            `citizenid` varchar(50) NOT NULL,
            `spots_assigned` int(11) NOT NULL,
            `spots_remaining` int(11) NOT NULL,
            PRIMARY KEY (`citizenid`)
        )
    ]])
    
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `community_service_inventory` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `citizenid` varchar(50) NOT NULL,
            `items` longtext,
            `storage_date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`)
        )
    ]])
    
    local results = MySQL.query.await('SELECT citizenid, spots_remaining FROM community_service')
    if results then
        for _, data in ipairs(results) do
            playersInService[data.citizenid] = data.spots_remaining
        end
        print('^2[ZCS]^0 Loaded ' .. #results .. ' players in community service')
    end
end)

RegisterNetEvent('zcs:checkInitialService', function()
    local source = source
    local playerData = GetPlayerData(source)
    if not playerData then return end

    local citizenid = playerData.citizenid
    if playersInService[citizenid] then
        DebugPrint('Player ' .. GetCharacterName(source) .. ' rejoined and is still in service.')
        TriggerClientEvent('zcs:startService', source, playersInService[citizenid])
        SendClientNotification(source, 'Community Service', _('service_rejoined', playersInService[citizenid]), 'info', 7000)
    else
        DebugPrint('Player ' .. GetCharacterName(source) .. ' checked initial service but is not in the list.')
    end
end)


RegisterNetEvent('zcs:checkPermission', function()
    local source = source
    local playerData = GetPlayerData(source)
    
    if HasPermission(playerData) then
        TriggerClientEvent('zcs:openMenu', source)
    else
        SendClientNotification(source, 'Community Service', _('no_permission'), 'error')
    end
end)

-- Service Assignment Logic
local function AssignService(source, targetSource, spotCount, isSelf)
    local playerData = GetPlayerData(targetSource)
    if not playerData then 
        DebugPrint('FAILED to assign service: Player data not found for target ' .. tostring(targetSource))
        return 
    end
    
    local citizenid = playerData.citizenid
    StorePlayerInventory(targetSource, citizenid)
    
    DebugPrint('Assigning ' .. spotCount .. ' tasks to ' .. GetPlayerName(targetSource) .. ' (' .. citizenid .. ')')
    
    local success = MySQL.query.await('INSERT INTO community_service (citizenid, spots_assigned, spots_remaining) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE spots_assigned = ?, spots_remaining = ?', 
        {citizenid, spotCount, spotCount, spotCount, spotCount})
    
    if success then
        playersInService[citizenid] = spotCount
        
        -- Start client service
        TriggerClientEvent('zcs:startService', targetSource, spotCount)
        SendClientNotification(targetSource, 'Community Service', _('service_started', spotCount), 'info', 7000)
        
        if not isSelf then
            local officerData = GetPlayerData(source)
            SendClientNotification(source, 'Community Service', _('player_sent', spotCount), 'success')
            LogServiceAssignment(GetCharacterName(source), officerData and officerData.citizenid or "Unknown", GetCharacterName(targetSource), citizenid, spotCount)
        end
        
        DebugPrint('Successfully assigned service to ' .. GetCharacterName(targetSource))
    else
        DebugPrint('DATABASE ERROR: Failed to insert/update community_service for ' .. citizenid)
    end
end

RegisterNetEvent('zcs:selfService', function(spotCount)
    AssignService(source, source, spotCount, true)
end)

RegisterNetEvent('zcs:sendToService', function(target, spotCount)
    local source = source
    local officerData = GetPlayerData(source)
    
    if not HasPermission(officerData) then
        SendClientNotification(source, 'Community Service', _('no_permission'), 'error')
        return
    end
    
    AssignService(source, target, spotCount, false)
end)

RegisterNetEvent('zcs:addTasks', function(target, addCount)
    local source = source
    local officerData = GetPlayerData(source)
    local targetData = GetPlayerData(target)
    
    if not HasPermission(officerData) then
        SendClientNotification(source, 'Community Service', _('no_permission'), 'error')
        return
    end
    
    if not targetData then
        SendClientNotification(source, 'Community Service', _('player_not_found'), 'error')
        return
    end
    
    local citizenid = targetData.citizenid
    
    if not playersInService[citizenid] then
        AssignService(source, target, addCount, false)
        return
    end
    
    local newCount = playersInService[citizenid] + addCount
    playersInService[citizenid] = newCount
    
    MySQL.query('UPDATE community_service SET spots_assigned = spots_assigned + ?, spots_remaining = spots_remaining + ? WHERE citizenid = ?', 
        {addCount, addCount, citizenid})
    
    LogTasksAdded(GetCharacterName(source), officerData.citizenid, GetCharacterName(target), citizenid, addCount, newCount)
    
    TriggerClientEvent('zcs:updateTaskCount', target, newCount)
    SendClientNotification(target, 'Community Service', _('service_extended', addCount), 'info', 7000)
    SendClientNotification(source, 'Community Service', _('added_tasks', addCount), 'success')
end)

RegisterNetEvent('zcs:checkPlayerStatus', function(target)
    local source = source
    local officerData = GetPlayerData(source)
    if not HasPermission(officerData) then return end
    
    local targetData = GetPlayerData(target)
    if not targetData then return end
    
    local citizenid = targetData.citizenid
    if not playersInService[citizenid] then
        SendClientNotification(source, 'Community Service', _('player_not_in_service'), 'info')
        return
    end
    
    local statusMessage = string.format(_('player_status'), GetCharacterName(target), playersInService[citizenid])
    SendClientNotification(source, 'Status', statusMessage, 'info')
end)

RegisterNetEvent('zcs:releasePlayer', function(target)
    local source = source
    local officerData = GetPlayerData(source)
    if not HasPermission(officerData) then return end
    
    local targetData = GetPlayerData(target)
    if not targetData then return end
    
    local citizenid = targetData.citizenid
    if not playersInService[citizenid] then return end
    
    local remainingTasks = playersInService[citizenid]
    ReleaseFromService(target, citizenid)
    
    SendClientNotification(source, 'Community Service', _('player_released'), 'success')
    LogForceRelease(GetCharacterName(source), officerData.citizenid, GetCharacterName(target), citizenid, remainingTasks)
end)

RegisterNetEvent('zcs:releaseSelf', function()
    local player = exports.qbx_core:GetPlayer(source)
    local playerData = player and player.PlayerData
    if not playerData or not playersInService[playerData.citizenid] then return end
    ReleaseFromService(source, playerData.citizenid)
end)

-- Task Handling
RegisterNetEvent('zcs:requestTask', function()
    local source = source
    local playerData = GetPlayerData(source)
    if not playerData then return end
    local citizenid = playerData.citizenid
    
    if not playersInService[citizenid] then 
        DebugPrint('Request rejected: ' .. GetCharacterName(source) .. ' not in service list.')
        return 
    end
    
    if processingTasks[citizenid] then return end
    if IsEventSpamming(source, 'zcs:requestTask') then return end
    
    processingTasks[citizenid] = true
    
    -- Pick a random task type
    local types = {"Sweeping", "Weeding", "Scrubbing", "PickingTrash"}
    local taskType = types[math.random(1, #types)]
    
    local spotIndex, spot
    if Config.EnableTaskTypeSpecificSpots and Locations.TaskSpots[taskType] then
        local spots = Locations.TaskSpots[taskType]
        spotIndex = math.random(1, #spots)
        spot = spots[spotIndex]
    else
        spotIndex = math.random(1, #Locations.CleaningSpots)
        spot = Locations.CleaningSpots[spotIndex]
    end
    
    if not spot then
        DebugPrint('CRITICAL: No spot found for task ' .. taskType)
        processingTasks[citizenid] = nil
        return
    end
    
    playerTasks[citizenid] = { index = spotIndex, position = spot, taskType = taskType }
    TriggerClientEvent('zcs:receiveTask', source, spotIndex, spot, taskType)
    DebugPrint('Sent task ' .. taskType .. ' to ' .. GetCharacterName(source))
    
    SetTimeout(1000, function() processingTasks[citizenid] = nil end)
end)

RegisterNetEvent('zcs:completeTask', function(spotIndex, taskType)
    local source = source
    local playerData = GetPlayerData(source)
    if not playerData then return end
    local citizenid = playerData.citizenid
    
    if not playersInService[citizenid] or processingTasks[citizenid] then return end
    if IsEventSpamming(source, 'zcs:completeTask') then return end
    
    -- Rate limit check
    local now = GetGameTimer()
    if playerLastTaskTime[citizenid] and (now - playerLastTaskTime[citizenid]) < (Config.TaskCooldown or 5000) then
        SendClientNotification(source, 'Community Service', _('cleaning_interrupted'), 'error')
        return
    end
    playerLastTaskTime[citizenid] = now
    
    -- Security position check
    if Config.SecurityEnabled and Config.StrictPositionCheck then
        if not VerifyPlayerPosition(source, playerTasks[citizenid].position) then
            SendClientNotification(source, 'Community Service', _('cleaning_interrupted'), 'error')
            return
        end
    end
    
    processingTasks[citizenid] = true
    local newCount = playersInService[citizenid] - 1
    playersInService[citizenid] = newCount
    
    MySQL.query.await('UPDATE community_service SET spots_remaining = ? WHERE citizenid = ?', {newCount, citizenid})
    SendClientNotification(source, 'Community Service', _('task_completed', newCount), 'success')
    
    playerTasks[citizenid] = nil
    
    if newCount <= 0 then
        ReleaseFromService(source, citizenid)
    else
        TriggerClientEvent('zcs:updateTaskCount', source, newCount)
        SetTimeout(1000, function() processingTasks[citizenid] = nil end)
    end
end)

function ReleaseFromService(source, citizenid)
    if releaseInProgress[citizenid] then return end
    releaseInProgress[citizenid] = true
    
    local spots_assigned = MySQL.scalar.await('SELECT spots_assigned FROM community_service WHERE citizenid = ?', {citizenid})
    local completedValue = spots_assigned or 0
    
    MySQL.query.await('DELETE FROM community_service WHERE citizenid = ?', {citizenid})
    
    playersInService[citizenid] = nil
    playerTasks[citizenid] = nil
    playerLastTaskTime[citizenid] = nil
    processingTasks[citizenid] = nil
    
    TriggerClientEvent('zcs:releaseFromService', source)
    SendClientNotification(source, 'Community Service', _('service_completed'), 'success', 7000)
    LogServiceCompletion(GetCharacterName(source), citizenid, completedValue)
    
    SetTimeout(5000, function() releaseInProgress[citizenid] = nil end)
end

-- Player connection/disconnection
AddEventHandler('qbx_core:server:onPlayerLoaded', function(source)
    local playerData = GetPlayerData(source)
    if not playerData then return end
    
    local citizenid = playerData.citizenid
    local remaining = MySQL.scalar.await('SELECT spots_remaining FROM community_service WHERE citizenid = ?', {citizenid})
    
    if remaining and remaining > 0 then
        playersInService[citizenid] = remaining
        TriggerClientEvent('zcs:startService', source, remaining)
        SendClientNotification(source, 'Community Service', _('service_started', remaining), 'info', 7000)
    end
end)


-- State Cleanup on Disconnect
AddEventHandler('playerDropped', function()
    local source = source
    local playerData = GetPlayerData(source)
    if playerData then
        processingTasks[playerData.citizenid] = nil
        playerTasks[playerData.citizenid] = nil
    end
end)

-- Callback to get online players with character names
lib.callback.register('zcs:server:getOnlinePlayers', function(source)
    local players = {}
    local activePlayers = exports.qbx_core:GetQBPlayers()
    
    for _, v in pairs(activePlayers) do
        local charinfo = v.PlayerData.charinfo
        table.insert(players, {
            id = v.PlayerData.source,
            name = charinfo.firstname .. ' ' .. charinfo.lastname,
            label = string.format('[%s] %s %s', v.PlayerData.source, charinfo.firstname, charinfo.lastname)
        })
    end
    
    table.sort(players, function(a, b)
        return a.id < b.id
    end)
    
    return players
end)
