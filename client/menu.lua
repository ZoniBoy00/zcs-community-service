-- Community Service Menu System (Powered by ox_lib)

local function OpenTaskCountMenu(playerId, action)
    lib.registerContext({
        id = 'zcs_task_count',
        title = _('menu_enter_tasks'),
        menu = 'zcs_player_selection',
        options = {
            {
                title = string.format(_('menu_player_id'), playerId),
                disabled = true
            },
            {
                title = _('menu_confirm'),
                icon = 'check',
                onSelect = function()
                    local input = lib.inputDialog(_('menu_enter_tasks'), {
                        {type = 'number', label = 'Task Count', default = 5, min = 1, max = 1000}
                    })
                    
                    if input and input[1] and input[1] > 0 then
                        if action == 'assign' then
                            TriggerServerEvent('zcs:sendToService', playerId, input[1])
                        elseif action == 'add' then
                            TriggerServerEvent('zcs:addTasks', playerId, input[1])
                        end
                    end
                end
            }
        }
    })
    
    lib.showContext('zcs_task_count')
end

local OpenMainMenu -- Forward declaration

local function OpenPlayerSelectionMenu(action)
    local players = lib.callback.await('zcs:server:getOnlinePlayers', false)
    if not players then return end
    
    local options = {}
    
    for i = 1, #players do
        local player = players[i]
        table.insert(options, {
            title = player.label,
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
    
    table.insert(options, {
        title = _('menu_cancel'),
        icon = 'xmark',
        onSelect = function()
            OpenMainMenu()
        end
    })
    
    lib.registerContext({
        id = 'zcs_player_selection',
        title = _('menu_select_player'),
        menu = 'zcs_main_menu',
        options = options
    })
    
    lib.showContext('zcs_player_selection')
end

local function OpenSelfServiceMenu()
    lib.registerContext({
        id = 'zcs_self_service',
        title = _('menu_self_service'),
        menu = 'zcs_main_menu',
        options = {
            {
                title = _('menu_assign'),
                description = 'Put yourself in community service for testing',
                icon = 'user-lock',
                onSelect = function()
                    local input = lib.inputDialog(_('menu_self_service'), {
                        {type = 'number', label = 'Task Count', default = 5, min = 1, max = 20}
                    })
                    
                    if input and input[1] and input[1] > 0 then
                        TriggerServerEvent('zcs:selfService', input[1])
                    end
                end
            },
            {
                title = _('menu_release'),
                description = 'Release yourself from community service',
                icon = 'user-check',
                onSelect = function()
                    TriggerServerEvent('zcs:releaseSelf')
                end
            }
        }
    })
    
    lib.showContext('zcs_self_service')
end

OpenMainMenu = function()
    local options = {
        {
            title = _('menu_assign'),
            icon = 'handcuffs',
            onSelect = function() OpenPlayerSelectionMenu('assign') end
        },
        {
            title = _('menu_check_status'),
            icon = 'magnifying-glass',
            onSelect = function() OpenPlayerSelectionMenu('status') end
        },
        {
            title = _('menu_release'),
            icon = 'unlock',
            onSelect = function() OpenPlayerSelectionMenu('release') end
        },
        {
            title = _('menu_add_tasks'),
            icon = 'plus',
            onSelect = function() OpenPlayerSelectionMenu('add') end
        }
    }
    
    if Config.EnableTestMenu then
        table.insert(options, {
            title = _('menu_self_service'),
            description = 'Testing tools',
            icon = 'vial',
            onSelect = OpenSelfServiceMenu
        })
    end
    
    table.insert(options, {
        title = _('menu_close'),
        icon = 'xmark',
        onSelect = function() end
    })
    
    lib.registerContext({
        id = 'zcs_main_menu',
        title = _('menu_title'),
        options = options
    })
    
    lib.showContext('zcs_main_menu')
end

RegisterCommand('communityservice', function()
    TriggerServerEvent('zcs:checkPermission')
end, false)

RegisterCommand('cs', function()
    TriggerServerEvent('zcs:checkPermission')
end, false)

if Config.EnableTestMenu then
    RegisterCommand('cs_test', function()
        OpenSelfServiceMenu()
    end, false)
end

RegisterNetEvent('zcs:openMenu', function()
    OpenMainMenu()
end)

RegisterNetEvent('zcs:openSelfServiceMenu', function()
    if Config.EnableTestMenu then
        OpenSelfServiceMenu()
    else
        SendNotification('Community Service', 'Test menu is disabled in the configuration', 'error')
    end
end)
