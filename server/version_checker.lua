-- Version Checker for ZCS Community Service
local currentVersion = '1.0.2'
local versionUrl = 'https://raw.githubusercontent.com/ZoniBoy00/Versions/refs/heads/main/zcs-community-service.txt'

local function CheckForUpdates()
    PerformHttpRequest(versionUrl, function(err, response, headers)
        if err ~= 200 or not response then
            print('^1[ZCS] Failed to check for updates.^7')
            return
        end
        
        local latestVersion = response:gsub("%s+", "")
        if currentVersion ~= latestVersion then
            print('^4╔═══════════════════════════════════════════════════════════════════╗^7')
            print('^4║                      ^1ZCS COMMUNITY SERVICE^4                        ║^7')
            print('^4║                        ^1UPDATE AVAILABLE^4                           ║^7')
            print('^4╠═══════════════════════════════════════════════════════════════════╣^7')
            print('^4║  ^3Current: ^1' .. currentVersion .. '                                            ^4       ║^7')
            print('^4║  ^3Latest:  ^2' .. latestVersion .. '                                            ^4       ║^7')
            print('^4║  ^3Link:    ^2https://github.com/ZoniBoy00/zcs-community-service      ^4║^7')
            print('^4╚═══════════════════════════════════════════════════════════════════╝^7')
        else
            print('^2[ZCS] You are running the latest version (' .. currentVersion .. ').^7')
        end
    end, 'GET')
end

CreateThread(function()
    Wait(5000)
    CheckForUpdates()
end)

RegisterCommand('zcs_check_updates', function(source)
    if source == 0 then
        CheckForUpdates()
    else
        -- Simple permission check for QBox admins
        if exports.qbx_core:HasPermission(source, 'admin') then
            CheckForUpdates()
        end
    end
end, true)
