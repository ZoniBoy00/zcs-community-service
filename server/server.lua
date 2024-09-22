-- Framework initialization
local Framework = nil
if Config.Framework == 'ESX' then
    Framework = exports["es_extended"]:getSharedObject()
elseif Config.Framework == 'QBCore' then
    Framework = exports['qb-core']:GetCoreObject()
end

local asciiArt = [[
 ______ _____                                       _ _         _____                 _          
|___  //  __ \                                     (_) |       /  ___|               (_)         
   / / | /  \/ ___  _ __ ___  _ __ ___  _   _ _ __  _| |_ _   _\ `--.  ___ _ ____   ___  ___ ___ 
  / /  | |    / _ \| '_ ` _ \| '_ ` _ \| | | | '_ \| | __| | | |`--. \/ _ \ '__\ \ / / |/ __/ _ \
./ /___| \__/\ (_) | | | | | | | | | | | |_| | | | | | |_| |_| /\__/ /  __/ |   \ V /| | (_|  __/
\_____/ \____/\___/|_| |_| |_|_| |_| |_|\__,_|_| |_|_|\__|\__, \____/ \___|_|    \_/ |_|\___\___|
    ______                                                 __/ |                                 
   |______|                                               |___/                            

                             By ZoniBoy00
]]

Citizen.CreateThread(function()
    print(asciiArt)
end)

-- Command to start community service (admin only)
RegisterCommand("startservice", function(source, args)
    local hasPermission = false
    if Config.Framework == 'ESX' then
        local xPlayer = Framework.GetPlayerFromId(source)
        hasPermission = xPlayer.job.name == 'police'
    elseif Config.Framework == 'QBCore' then
        local Player = Framework.Functions.GetPlayer(source)
        hasPermission = Player.PlayerData.job.name == "police"
    end
    
    if hasPermission then
        OpenServiceMenu(source)
    else
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Error',
            description = _U('no_permission'),
            type = 'error'
        })
    end
end, false)

-- Open the service menu
function OpenServiceMenu(source)
    TriggerClientEvent('Z_CommunityService:openInputDialog', source)
end

-- Event handler for input dialog response
RegisterNetEvent('Z_CommunityService:inputDialogResponse')
AddEventHandler('Z_CommunityService:inputDialogResponse', function(playerId, spots)
    if playerId and spots then
        TriggerClientEvent("startCommunityService", playerId, spots)
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Community Service',
            description = _U('service_given', playerId, spots),
            type = 'success'
        })
    end
end)