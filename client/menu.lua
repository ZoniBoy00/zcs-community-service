-- Define a local translation function in case the global one isn't available
local function _(str, ...)
    local args = {...}
    if Locales[Config.Locale] and Locales[Config.Locale][str] then
        -- Check if we have any arguments before formatting
        if #args > 0 then
            return string.format(Locales[Config.Locale][str], ...)
        else
            -- Return the string without formatting if no arguments provided
            return Locales[Config.Locale][str]
        end
    end
    return 'Translation missing: ' .. str
end

-- Community Service Menu System

-- Function to get all online players for the menu
local function GetOnlinePlayers()
    local players = {}
    
    for _, id in ipairs(GetActivePlayers()) do
        local serverId = GetPlayerServerId(id)
        local name = GetPlayerName(id)
        
        if serverId and name then
            table.insert(players, {
                id = serverId,
                name = name,
                label = string.format('[%s] %s', serverId, name)
            })
        end
    end
    
    -- Sort by ID
    table.sort(players, function(a, b)
        return a.id < b.id
    end)
    
    return players
end

-- Open the task count input menu
local function OpenTaskCountMenu(playerId, action)
    lib.registerContext({
        id = 'zcs_task_count',
        title = _('menu_enter_tasks'),
        menu = 'zcs_player_selection',
        options = {
            {
                title = string.format(_('menu_player_id'), playerId),
                description = '',
                disabled = true
            },
            {
                title = _('menu_confirm'),
                description = '',
                onSelect = function()
                    local input = lib.inputDialog(_('menu_enter_tasks'), {
                        {type = 'number', label = 'Task Count', default = 5, min = 1, max = 100}
                    })
                    
                    if input and input[1] and input[1] > 0 then
                        if action == 'assign' then
                            TriggerServerEvent('zcs:sendToService', playerId, input[1])
                        elseif action == 'add' then
                            TriggerServerEvent('zcs:addTasks', playerId, input[1])
                        end
                    end
                end,
                icon = 'check'
            }
        }
    })
    
    lib.showContext('zcs_task_count')
end

-- Forward declaration for OpenMainMenu
local OpenMainMenu

-- Open the player selection menu
local function OpenPlayerSelectionMenu(action)
    local players = GetOnlinePlayers()
    local options = {}
    
    for _, player in ipairs(players) do
        table.insert(options, {
            title = player.label,
            description = '',
            onSelect = function()
                if action == 'assign' or action == 'add' then
                    OpenTaskCountMenu(player.id, action)
                elseif action == 'status' then
                    TriggerServerEvent('zcs:checkPlayerStatus', player.id)
                elseif action == 'release' then
                    TriggerServerEvent('zcs:releasePlayer', player.id)
                end
            end
        })
    end
    
    -- Add a cancel option
    table.insert(options, {
        title = _('menu_cancel'),
        description = '',
        onSelect = function()
            OpenMainMenu()
        end,
        icon = 'xmark'
    })
    
    lib.registerContext({
        id = 'zcs_player_selection',
        title = _('menu_select_player'),
        menu = 'zcs_main_menu',
        options = options
    })
    
    lib.showContext('zcs_player_selection')
end

-- Open the self-service menu for testing
local function OpenSelfServiceMenu()
    lib.registerContext({
        id = 'zcs_self_service',
        title = _('menu_self_service'),
        menu = 'zcs_main_menu',
        options = {
            {
                title = _('menu_assign'),
                description = 'Put yourself in community service for testing',
                onSelect = function()
                    local input = lib.inputDialog(_('menu_self_service'), {
                        {type = 'number', label = 'Task Count', default = 5, min = 1, max = 20}
                    })
                    
                    if input and input[1] and input[1] > 0 then
                        TriggerServerEvent('zcs:selfService', input[1])
                    end
                end,
                icon = 'user-lock'
            },
            {
                title = _('menu_release'),
                description = 'Release yourself from community service',
                onSelect = function()
                    TriggerServerEvent('zcs:releaseSelf')
                end,
                icon = 'user-check'
            }
        }
    })
    
    lib.showContext('zcs_self_service')
end

-- Open the main community service menu
OpenMainMenu = function()
    local options = {
        {
            title = _('menu_assign'),
            description = '',
            onSelect = function()
                OpenPlayerSelectionMenu('assign')
            end,
            icon = 'handcuffs'
        },
        {
            title = _('menu_check_status'),
            description = '',
            onSelect = function()
                OpenPlayerSelectionMenu('status')
            end,
            icon = 'magnifying-glass'
        },
        {
            title = _('menu_release'),
            description = '',
            onSelect = function()
                OpenPlayerSelectionMenu('release')
            end,
            icon = 'unlock'
        },
        {
            title = _('menu_add_tasks'),
            description = '',
            onSelect = function()
                OpenPlayerSelectionMenu('add')
            end,
            icon = 'plus'
        }
    }
    
    -- Only add the test menu option if enabled in config
    if Config.EnableTestMenu then
        table.insert(options, {
            title = _('menu_self_service'),
            description = 'Put yourself in community service for testing',
            onSelect = function()
                OpenSelfServiceMenu()
            end,
            icon = 'vial'
        })
    end
    
    -- Add close button
    table.insert(options, {
        title = _('menu_close'),
        description = '',
        onSelect = function() end,
        icon = 'xmark'
    })
    
    lib.registerContext({
        id = 'zcs_main_menu',
        title = _('menu_title'),
        options = options
    })
    
    lib.showContext('zcs_main_menu')
end

-- Register the command to open the menu
RegisterCommand('communityservice', function()
    -- Check permission on server side
    TriggerServerEvent('zcs:checkPermission')
end, false)

-- Register shorthand command
RegisterCommand('cs', function()
    -- Check permission on server side
    TriggerServerEvent('zcs:checkPermission')
end, false)

-- Register testing command (only if test menu is enabled)
if Config.EnableTestMenu then
    RegisterCommand('cs_test', function()
        OpenSelfServiceMenu()
    end, false)
end

-- Event to open menu after permission check
RegisterNetEvent('zcs:openMenu')
AddEventHandler('zcs:openMenu', function()
    OpenMainMenu()
end)

-- Event to open self-service menu
RegisterNetEvent('zcs:openSelfServiceMenu')
AddEventHandler('zcs:openSelfServiceMenu', function()
    if Config.EnableTestMenu then
        OpenSelfServiceMenu()
    else
        -- If test menu is disabled, show a notification
        SendNotification('Community Service', 'Test menu is disabled in the configuration', 'error')
    end
end)

