-- Inventory management for Community Service (QBox)

-- Safe local reference to global DebugPrint
local function DebugPrint(msg)
    if _G.DebugPrint then _G.DebugPrint(msg) end
end

-- Utility for notifications (fallback)
local function Notify(source, title, description, type)
    if SendClientNotification then
        SendClientNotification(source, title, description, type)
    else
        TriggerClientEvent('ox_lib:notify', source, { title = title, description = description, type = type or 'info' })
    end
end

-- Store inventory before service starts
function StorePlayerInventory(source, citizenid)
    local inventory = exports.ox_inventory:GetInventory(source)
    local items = inventory and inventory.items
    
    if not items or not next(items) then 
        DebugPrint('Player ' .. GetPlayerName(source) .. ' has a truly empty inventory.')
        return 
    end
    
    -- Check for existing storage to avoid overwriting or duplicates
    local existing = MySQL.scalar.await('SELECT COUNT(*) FROM community_service_inventory WHERE citizenid = ?', {citizenid})
    if existing and existing > 0 then
        DebugPrint('Player ' .. GetPlayerName(source) .. ' already has stored items. Clearing inventory to prevent bringing items to service.')
        exports.ox_inventory:ClearInventory(source)
        return
    end
    
    local success = MySQL.insert.await('INSERT INTO community_service_inventory (citizenid, items) VALUES (?, ?)', {citizenid, json.encode(items)})
    
    if success then
        -- Aggressive clearing
        exports.ox_inventory:ClearInventory(source)
        
        -- Double check and force remove if anything remains (like weapons)
        Wait(500)
        local remaining = exports.ox_inventory:GetInventory(source).items
        if remaining and next(remaining) then
            for _, item in pairs(remaining) do
                exports.ox_inventory:RemoveItem(source, item.name, item.count)
            end
        end
        
        DebugPrint('Inventory SECURELY stored and cleared for ' .. GetPlayerName(source))
    else
        DebugPrint('CRITICAL ERROR: Failed to store inventory for ' .. GetPlayerName(source))
    end
end

-- Restore inventory after service completion
function RestorePlayerInventory(source, citizenid)
    local itemsJson = MySQL.scalar.await('SELECT items FROM community_service_inventory WHERE citizenid = ? ORDER BY storage_date DESC LIMIT 1', {citizenid})
    
    if itemsJson then
        local items = json.decode(itemsJson)
        
        SetTimeout(1000, function()
            for _, item in pairs(items) do
                if item.name and item.count then
                    exports.ox_inventory:AddItem(source, item.name, item.count, item.metadata)
                end
            end
            
            MySQL.query('DELETE FROM community_service_inventory WHERE citizenid = ?', {citizenid})
            LogBelongingsRetrieved(GetPlayerName(source), citizenid)
            Notify(source, 'Community Service', _('belongings_returned'), 'success')
        end)
    else
        Notify(source, 'Community Service', _('no_belongings'), 'error')
    end
end

RegisterNetEvent('zcs:retrieveBelongings', function()
    local source = source
    local player = exports.qbx_core:GetPlayer(source)
    local playerData = player and player.PlayerData
    if not playerData or IsEventSpamming(source, 'zcs:retrieveBelongings') then return end
    
    local citizenid = playerData.citizenid
    if playersInService[citizenid] then
        Notify(source, 'Community Service', _('not_in_service'), 'error')
        return
    end
    
    RestorePlayerInventory(source, citizenid)
end)
