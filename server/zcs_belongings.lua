-- Server-side script specifically for handling inventory management
-- Optimized for performance and reliability

-- Add reference to the notification debounce function if it's not accessible from main.lua
if not SendClientNotification then
    local lastNotifications = {}
    
    function SendClientNotification(source, title, message, type, duration)
        -- Generate a unique key for this notification
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
end

-- Debug function - only executes if debug is enabled
function DebugPrint(message)
    -- Use a safe check for Config.Debug that won't error if Config is nil
    if Config and Config.Debug then
        print('[ZCS] ' .. message)
    end
end

-- Store player inventory in database (optimized)
function StorePlayerInventory(xPlayer)
    local identifier = xPlayer.getIdentifier()
    local source = xPlayer.source
    local playerName = GetPlayerName(source)
    local items = exports.ox_inventory:GetInventoryItems(source)
    
    if not items or #items == 0 then 
        DebugPrint('No items to store for player ' .. playerName)
        return 
    end
    
    -- Check if player already has stored items to prevent duplicates
    MySQL.Async.fetchScalar('SELECT COUNT(*) FROM community_service_inventory WHERE identifier = @identifier', {
        ['@identifier'] = identifier
    }, function(count)
        if count and count > 0 then
            DebugPrint('Player ' .. playerName .. ' already has stored items. Skipping storage.')
            return
        end
        
        -- Convert items to JSON string
        local itemsJson = json.encode(items)
        
        -- Store in database (optimized query)
        MySQL.Async.execute('INSERT INTO community_service_inventory (identifier, items) VALUES (@identifier, @items)', {
            ['@identifier'] = identifier,
            ['@items'] = itemsJson
        }, function()
            -- Log each item being taken with ox_inventory's logging system
            for _, item in pairs(items) do
                if item.name and item.count then
                    -- Use ox_inventory's built-in logging for each item
                    exports.ox_inventory:RemoveItem(source, item.name, item.count, item.metadata, true, 
                        function(success, reason)
                            if not success and Config.Debug then
                                print('[ZCS] Failed to remove item ' .. item.name .. ' from player ' .. playerName .. ': ' .. reason)
                            end
                        end
                    )
                end
            end
            
            -- Clear player inventory after logging each item
            exports.ox_inventory:ClearInventory(source, true)
            
            DebugPrint('Stored inventory for player ' .. playerName)
        end)
    end)
end

-- Restore player inventory from database (optimized)
function RestorePlayerInventory(xPlayer)
    local identifier = xPlayer.getIdentifier()
    local source = xPlayer.source
    local playerName = GetPlayerName(source)
    
    -- Add a flag to prevent duplicate processing
    if not xPlayer.retrievingBelongings then
        xPlayer.retrievingBelongings = true
        
        -- Optimized query to get only the most recent inventory
        MySQL.Async.fetchScalar('SELECT items FROM community_service_inventory WHERE identifier = @identifier ORDER BY storage_date DESC LIMIT 1', {
            ['@identifier'] = identifier
        }, function(items)
            if items then
                local itemsData = json.decode(items)
                
                -- Wait a bit to ensure player is ready
                SetTimeout(1000, function()
                    -- Give back the items with proper logging
                    for _, item in pairs(itemsData) do
                        if item.name and item.count then
                            -- Use ox_inventory's built-in logging for each item
                            exports.ox_inventory:AddItem(source, item.name, item.count, item.metadata, nil, 
                                function(success, response)
                                    if not success and Config.Debug then
                                        print('[ZCS] Failed to add item ' .. item.name .. ' to player ' .. playerName .. ': ' .. response)
                                    end
                                end
                            )
                        end
                    end
                    
                    -- Delete the stored inventory
                    MySQL.Async.execute('DELETE FROM community_service_inventory WHERE identifier = @identifier', {
                        ['@identifier'] = identifier
                    })
                    
                    -- Log to Discord
                    LogBelongingsRetrieved(playerName, identifier)
                    
                    SendClientNotification(source, 'Community Service', _('belongings_returned'), 'success', 5000)
                    
                    DebugPrint('Restored inventory for player ' .. playerName)
                    
                    -- Reset the flag after a delay
                    SetTimeout(5000, function()
                        xPlayer.retrievingBelongings = nil
                    end)
                end)
            else
                SendClientNotification(source, 'Community Service', _('no_belongings'), 'error', 5000)
                
                -- Reset the flag immediately
                xPlayer.retrievingBelongings = nil
            end
        end)
    else
        DebugPrint('Player ' .. playerName .. ' is already retrieving belongings. Ignoring duplicate request.')
    end
end

-- Request to retrieve stored belongings
RegisterNetEvent('zcs:retrieveBelongings')
AddEventHandler('zcs:retrieveBelongings', function()
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then return end
    
    -- Security: Check for event spamming
    if IsEventSpamming(source, 'zcs:retrieveBelongings') then
        return
    end
    
    -- Process the retrieval
    local identifier = xPlayer.getIdentifier()
    
    -- Check if player is in service (shouldn't be able to retrieve while in service)
    if playersInService[identifier] then
        SendClientNotification(source, 'Community Service', _('not_in_service'), 'error')
        return
    end
    
    -- Check if player has stored inventory
    MySQL.Async.fetchScalar('SELECT COUNT(*) FROM community_service_inventory WHERE identifier = @identifier', {
        ['@identifier'] = identifier
    }, function(count)
        if count and count > 0 then
            -- Player has stored items, restore them
            RestorePlayerInventory(xPlayer)
        else
            -- No stored items found
            SendClientNotification(source, 'Community Service', _('no_belongings'), 'error')
        end
    end)
end)

