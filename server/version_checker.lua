local currentVersion = "1.0.0"
local repositoryUrl = "https://raw.githubusercontent.com/ZoniBoy00/Versions/refs/heads/main/Z_CommunityService.txt"

function checkForUpdates()
    PerformHttpRequest(repositoryUrl, function(errorCode, responseData, headers)
        if errorCode == 200 then
            local remoteVersion = responseData

            if remoteVersion ~= currentVersion then
                print("New version available: " .. remoteVersion)
                print("Current version: " .. currentVersion)
            else
                print("You are up to date!")
            end
        else
            print("Error loading remote version: " .. errorCode)
        end
    end, "GET", "", {})
end

checkForUpdates()
