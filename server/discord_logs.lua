-- Discord webhook logging system
local webhookUrl = 'https://discord.com/api/webhooks/your-webhook-url-here'

local function SendDiscordLog(title, description, color, fields)
    if not webhookUrl or webhookUrl == '' or webhookUrl:find('your-webhook') then
        return
    end
    
    local embed = {
        {
            ["title"] = title,
            ["description"] = description,
            ["type"] = "rich",
            ["color"] = color or 65280,
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

function LogServiceAssignment(officerName, officerIdentifier, targetName, targetIdentifier, taskCount)
    local fields = {
        { ["name"] = "Officer", ["value"] = officerName .. " (" .. officerIdentifier .. ")", ["inline"] = true },
        { ["name"] = "Player", ["value"] = targetName .. " (" .. targetIdentifier .. ")", ["inline"] = true },
        { ["name"] = "Tasks", ["value"] = tostring(taskCount), ["inline"] = true }
    }
    SendDiscordLog("Community Service Assignment", "A player has been assigned to community service", 3447003, fields)
end

function LogServiceCompletion(playerName, playerIdentifier, tasksCompleted)
    local fields = {
        { ["name"] = "Player", ["value"] = playerName .. " (" .. playerIdentifier .. ")", ["inline"] = true },
        { ["name"] = "Tasks Completed", ["value"] = tostring(tasksCompleted), ["inline"] = true }
    }
    SendDiscordLog("Community Service Completed", "A player has completed their community service", 65280, fields)
end

function LogForceRelease(officerName, officerIdentifier, targetName, targetIdentifier, remainingTasks)
    local fields = {
        { ["name"] = "Officer", ["value"] = officerName .. " (" .. officerIdentifier .. ")", ["inline"] = true },
        { ["name"] = "Player", ["value"] = targetName .. " (" .. targetIdentifier .. ")", ["inline"] = true },
        { ["name"] = "Remaining Tasks", ["value"] = tostring(remainingTasks), ["inline"] = true }
    }
    SendDiscordLog("Force Release", "A player has been force-released from community service", 16776960, fields)
end

function LogTasksAdded(officerName, officerIdentifier, targetName, targetIdentifier, addedTasks, totalTasks)
    local fields = {
        { ["name"] = "Officer", ["value"] = officerName .. " (" .. officerIdentifier .. ")", ["inline"] = true },
        { ["name"] = "Player", ["value"] = targetName .. " (" .. targetIdentifier .. ")", ["inline"] = true },
        { ["name"] = "Added Tasks", ["value"] = tostring(addedTasks), ["inline"] = true },
        { ["name"] = "Total Tasks", ["value"] = tostring(totalTasks), ["inline"] = true }
    }
    SendDiscordLog("Tasks Added", "Additional tasks have been added to a player's service", 15105570, fields)
end

function LogBelongingsRetrieved(playerName, playerIdentifier)
    local fields = {
        { ["name"] = "Player", ["value"] = playerName .. " (" .. playerIdentifier .. ")", ["inline"] = true }
    }
    SendDiscordLog("Belongings Retrieved", "A player has retrieved their belongings", 10181046, fields)
end

function LogSuspiciousActivity(playerName, playerIdentifier, activity, details)
    local fields = {
        { ["name"] = "Player", ["value"] = playerName .. " (" .. playerIdentifier .. ")", ["inline"] = true },
        { ["name"] = "Activity", ["value"] = activity, ["inline"] = true },
        { ["name"] = "Details", ["value"] = details or "N/A", ["inline"] = false }
    }
    SendDiscordLog("⚠️ Suspicious Activity ⚠️", "Potential exploit detected", 16711680, fields)
end
