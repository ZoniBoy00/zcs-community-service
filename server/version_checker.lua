-- Version Checker for ZCS Community Service
local currentVersion = '1.0.1' -- Make sure this matches the version in fxmanifest.lua
local resourceName = GetCurrentResourceName()
local versionCheckUrl = 'https://raw.githubusercontent.com/ZoniBoy00/Versions/refs/heads/main/zcs-community-service.txt'

-- Function to check for updates with detailed debugging
function CheckForUpdates(debug)
    if debug then
        print('^3[ZCS] Checking for updates...^7')
        print('^3[ZCS] Requesting version from: ^5' .. versionCheckUrl .. '^7')
    end
    
    PerformHttpRequest(versionCheckUrl, function(err, response, headers)
        if err ~= 200 then
            print('^1[ZCS] Failed to check for updates. Error code: ' .. tostring(err) .. '^7')
            return
        end
        
        -- Print raw response for debugging
        if debug then
            print('^3[ZCS] Raw response: "^5' .. tostring(response) .. '^3"^7')
            print('^3[ZCS] Response length: ^5' .. tostring(string.len(response)) .. '^7')
            
            -- Print hex representation to check for hidden characters
            local hex = ""
            for i = 1, string.len(response) do
                hex = hex .. string.format("%02X ", string.byte(response, i))
            end
            print('^3[ZCS] Response hex: ^5' .. hex .. '^7')
        end
        
        -- Remove any whitespace, newlines, or carriage returns
        local latestVersion = response:gsub("%s+", ""):gsub("\r", ""):gsub("\n", "")
        
        if debug then
            print('^3[ZCS] Cleaned response: "^5' .. latestVersion .. '^3"^7')
            print('^3[ZCS] Current version: "^5' .. currentVersion .. '^3"^7')
            print('^3[ZCS] Versions match: ^5' .. tostring(currentVersion == latestVersion) .. '^7')
        end
        
        -- Compare versions
        if currentVersion ~= latestVersion then
            -- Enhanced visual appearance for update notification
            print('')
            print('^4╔═══════════════════════════════════════════════════════════════════╗^7')
            print('^4║                                                                   ║^7')
            print('^4║                      ^1ZCS COMMUNITY SERVICE^4                        ║^7')
            print('^4║                        ^1UPDATE AVAILABLE^4                           ║^7')
            print('^4║                                                                   ║^7')
            print('^4╠═══════════════════════════════════════════════════════════════════╣^7')
            print('^4║                                                                   ║^7')
            print('^4║  ^3Current version: ^1' .. string.format("%-10s", currentVersion) .. '                                      ^4║^7')
            print('^4║  ^3Latest version:  ^2' .. string.format("%-10s", latestVersion) .. '                                      ^4║^7')
            print('^4║                                                                   ║^7')
            print('^4║  ^3Please update to the latest version from:                       ^4║^7')
            print('^4║  ^2https://github.com/ZoniBoy00/zcs-community-service               ^4║^7')
            print('^4║                                                                   ║^7')
            print('^4╚═══════════════════════════════════════════════════════════════════╝^7')
            print('')
        else
            -- Enhanced visual appearance for up-to-date notification
            print('')
            print('^2╔═══════════════════════════════════════════════════════════════════╗^7')
            print('^2║                                                                   ║^7')
            print('^2║                      ZCS COMMUNITY SERVICE                        ║^7')
            print('^2║                          UP TO DATE                               ║^7')
            print('^2║                                                                   ║^7')
            print('^2╠═══════════════════════════════════════════════════════════════════╣^7')
            print('^2║                                                                   ║^7')
            print('^2║  You are running the latest version: ' .. string.format("%-10s", currentVersion) .. '                   ║^7')
            print('^2║                                                                   ║^7')
            print('^2╚═══════════════════════════════════════════════════════════════════╝^7')
            print('')
        end
    end, 'GET', '', { ['Cache-Control'] = 'no-cache' })
end

-- Check for updates when the resource starts
AddEventHandler('onResourceStart', function(resource)
    if resource == resourceName then
        -- Wait a bit to ensure everything is loaded
        Citizen.SetTimeout(2000, function()
            CheckForUpdates(false)
        end)
    end
end)

-- Command to manually check for updates
RegisterCommand('zcs_check_updates', function(source, args, rawCommand)
    -- Only allow server console or admin to run this command
    if source == 0 then
        CheckForUpdates(false)
    else
        local xPlayer = ESX.GetPlayerFromId(source)
        if xPlayer and xPlayer.getGroup() == 'admin' then
            CheckForUpdates(false)
            TriggerClientEvent('chat:addMessage', source, {
                color = {255, 255, 0},
                multiline = true,
                args = {"ZCS", "Checking for updates. Check server console for results."}
            })
        end
    end
end, true)

-- Add a debug command to show detailed version check information
RegisterCommand('zcs_debug_version', function(source, args, rawCommand)
    if source == 0 then
        print('^3[ZCS] Running version check in debug mode...^7')
        CheckForUpdates(true)
    end
end, true)

-- Force update check with cache bypass
RegisterCommand('zcs_force_update_check', function(source, args, rawCommand)
    if source == 0 then
        print('^3[ZCS] Forcing update check with cache bypass...^7')
        
        -- Generate a unique URL with a timestamp to bypass any caching
        local timestampedUrl = versionCheckUrl .. '?t=' .. os.time()
        print('^3[ZCS] Using URL: ^5' .. timestampedUrl .. '^7')
        
        PerformHttpRequest(timestampedUrl, function(err, response, headers)
            if err ~= 200 then
                print('^1[ZCS] Failed to check for updates. Error code: ' .. tostring(err) .. '^7')
                return
            end
            
            -- Print raw response
            print('^3[ZCS] Raw response: "^5' .. tostring(response) .. '^3"^7')
            
            -- Remove any whitespace or newlines
            local latestVersion = response:gsub("%s+", ""):gsub("\r", ""):gsub("\n", "")
            print('^3[ZCS] Cleaned response: "^5' .. latestVersion .. '^3"^7')
            print('^3[ZCS] Current version: "^5' .. currentVersion .. '^3"^7')
            
            -- Compare versions
            if currentVersion ~= latestVersion then
                print('^3[ZCS] Update available! Latest version: ^5' .. latestVersion .. '^7')
            else
                print('^3[ZCS] No update available. Current version: ^5' .. currentVersion .. '^7')
            end
        end, 'GET', '', { ['Cache-Control'] = 'no-cache', ['Pragma'] = 'no-cache' })
    end
end, true)

