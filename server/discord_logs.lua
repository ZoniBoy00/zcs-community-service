-- Discord webhook logging system
local webhookUrl = 'https://discord.com/api/webhooks/your-webhook-url-here' -- Replace with your actual Discord webhook URL

-- Function to send Discord webhook
local function SendDiscordLog(title, description, color, fields)
    if not webhookUrl or webhookUrl == '' then
        if Config.Debug then
            print('[ZCS] Discord webhook URL not configured. Skipping log.')
        end
        return
    end
    
    -- Default to green if no color specified
    color = color or 65280
    
    local embed = {
        {
            ["title"] = title,
            ["description"] = description,
            ["type"] = "rich",
            ["color"] = color,
            ["footer"] = {
                ["text"] = "ZCS Community Service | " .. os.date("%Y-%m-%d %H:%M:%S")
            },
            ["fields"] = fields or {}
        }
    }
    
    PerformHttpRequest(webhookUrl, function(err, text, headers) end, 'POST', json.encode({
        username = "Community Service Logs",
        embeds = embed
    }), { ['Content-Type'] = 'application/json' })
end

-- Log when a player is sent to community service
function LogServiceAssignment(officerName, officerIdentifier, targetName, targetIdentifier, taskCount)
    local fields = {
        {
            ["name"] = "Officer",
            ["value"] = officerName .. " (" .. officerIdentifier .. ")",
            ["inline"] = true
        },
        {
            ["name"] = "Player",
            ["value"] = targetName .. " (" .. targetIdentifier .. ")",
            ["inline"] = true
        },
        {
            ["name"] = "Tasks",
            ["value"] = tostring(taskCount),
            ["inline"] = true
        }
    }
    
    SendDiscordLog(
        "Community Service Assignment",
        "A player has been assigned to community service",
        3447003, -- Blue
        fields
    )
end

-- Log when a player completes community service
function LogServiceCompletion(playerName, playerIdentifier, tasksCompleted)
    local fields = {
        {
            ["name"] = "Player",
            ["value"] = playerName .. " (" .. playerIdentifier .. ")",
            ["inline"] = true
        },
        {
            ["name"] = "Tasks Completed",
            ["value"] = tostring(tasksCompleted),
            ["inline"] = true
        }
    }
    
    SendDiscordLog(
        "Community Service Completed",
        "A player has completed their community service",
        65280, -- Green
        fields
    )
end

-- Log when a player is force-released by an officer
function LogForceRelease(officerName, officerIdentifier, targetName, targetIdentifier, remainingTasks)
    local fields = {
        {
            ["name"] = "Officer",
            ["value"] = officerName .. " (" .. officerIdentifier .. ")",
            ["inline"] = true
        },
        {
            ["name"] = "Player",
            ["value"] = targetName .. " (" .. targetIdentifier .. ")",
            ["inline"] = true
        },
        {
            ["name"] = "Remaining Tasks",
            ["value"] = tostring(remainingTasks),
            ["inline"] = true
        }
    }
    
    SendDiscordLog(
        "Force Release from Community Service",
        "A player has been force-released from community service by an officer",
        16776960, -- Yellow
        fields
    )
end

-- Log when tasks are added to a player's service
function LogTasksAdded(officerName, officerIdentifier, targetName, targetIdentifier, addedTasks, totalTasks)
    local fields = {
        {
            ["name"] = "Officer",
            ["value"] = officerName .. " (" .. officerIdentifier .. ")",
            ["inline"] = true
        },
        {
            ["name"] = "Player",
            ["value"] = targetName .. " (" .. targetIdentifier .. ")",
            ["inline"] = true
        },
        {
            ["name"] = "Added Tasks",
            ["value"] = tostring(addedTasks),
            ["inline"] = true
        },
        {
            ["name"] = "Total Tasks",
            ["value"] = tostring(totalTasks),
            ["inline"] = true
        }
    }
    
    SendDiscordLog(
        "Community Service Tasks Added",
        "Additional tasks have been added to a player's community service",
        15105570, -- Orange
        fields
    )
end

-- Log when a player retrieves their belongings
function LogBelongingsRetrieved(playerName, playerIdentifier)
    local fields = {
        {
            ["name"] = "Player",
            ["value"] = playerName .. " (" .. playerIdentifier .. ")",
            ["inline"] = true
        }
    }
    
    SendDiscordLog(
        "Belongings Retrieved",
        "A player has retrieved their belongings from storage",
        10181046, -- Purple
        fields
    )
end

-- Log suspicious activity (potential exploits)
function LogSuspiciousActivity(playerName, playerIdentifier, activity, details)
    local fields = {
        {
            ["name"] = "Player",
            ["value"] = playerName .. " (" .. playerIdentifier .. ")",
            ["inline"] = true
        },
        {
            ["name"] = "Activity",
            ["value"] = activity,
            ["inline"] = true
        },
        {
            ["name"] = "Details",
            ["value"] = details or "No additional details",
            ["inline"] = false
        }
    }
    
    SendDiscordLog(
        "⚠️ Suspicious Activity Detected ⚠️",
        "Potential exploit or unauthorized activity detected",
        16711680, -- Red
        fields
    )
end

