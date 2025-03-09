Config = {}

-- Debug mode (set to false in production)
Config.Debug = false

-- Test menu option (set to false to hide the self-service testing option)
Config.EnableTestMenu = false

-- Language setting (en or fi)
Config.Locale = 'en'

-- Police job configuration
Config.PoliceJobName = 'police'
Config.MinimumPoliceGrade = 2 -- Minimum grade required to use community service

-- Progress UI settings
Config.ProgressStyle = 'bar' -- 'bar' or 'circle'
Config.ProgressDuration = 10000 -- Duration in ms for cleaning tasks

-- Cooldown between task completions (in milliseconds)
Config.TaskCooldown = 5000

-- Maximum distance to interact with cleaning spots
Config.InteractionDistance = 3.0

-- Security settings
Config.SecurityEnabled = true
Config.MaxTasksPerMinute = 5

-- Inventory settings
Config.UseOxInventory = true -- Set to false if using another inventory system

-- Optimization settings
Config.MarkerUpdateInterval = 250 -- ms between marker updates (higher = better performance)
Config.UIUpdateInterval = 1000 -- ms between UI updates
Config.PlayerPositionCheckInterval = 5000 -- ms between position checks

-- Restricted area visualization
Config.ShowRestrictedArea = true -- Set to true to show the boundary
Config.RestrictedAreaColor = {r = 50, g = 150, b = 50, a = 30} -- More subtle green with low transparency

-- Update marker settings for a more modern look
Config.MarkerType = 1 -- Vertical cylinder with moving gradient (more modern)
Config.MarkerColor = {r = 65, g = 220, b = 120, a = 180} -- Brighter green, semi-transparent
Config.MarkerSize = {x = 1.0, y = 1.0, z = 0.5} -- Slightly larger and flatter for modern look

-- Blip settings (map icons)
Config.CleaningBlipSprite = 280 -- Cleaning cloth icon (more modern)
Config.CleaningBlipColor = 47 -- Light blue (more visible)
Config.CleaningBlipScale = 0.7 -- Slightly smaller for cleaner look
Config.CleaningBlipAlpha = 250 -- More opaque
Config.CleaningBlipShowRoute = true -- Show route to the cleaning spot

Config.RetrievalBlipSprite = 478 -- Package/box icon (more modern)
Config.RetrievalBlipColor = 25 -- Purple (more distinct)
Config.RetrievalBlipScale = 0.8 -- Good size
Config.RetrievalBlipAlpha = 250 -- More opaque

-- Add a new config option for position checking strictness
Config.StrictPositionCheck = false -- Set to false for more lenient position checking

-- Performance optimization settings
Config.MarkerRenderDistance = 50.0 -- Only render markers when player is within this distance
Config.TaskAssignmentDelay = 1500 -- ms to wait before assigning a new task
Config.ReleaseDelay = 1000 -- ms to wait before teleporting player after release

-- Add notification debounce to prevent duplicates
Config.NotificationDebounce = 3000 -- ms between similar notifications

-- Task type settings
Config.EnableTaskTypeSpecificSpots = true -- If true, each task type will only use its own spots

-- Add a new config option for inventory restrictions during tasks
Config.DisableInventoryDuringTasks = true -- Set to true to disable inventory access during cleaning tasks

-- Function to translate text with error handling
function _(str, ...)
local args = {...}
if Locales[Config.Locale] and Locales[Config.Locale][str] then
    if #args > 0 then
        local success, result = pcall(string.format, Locales[Config.Locale][str], ...)
        if success then
            return result
        else
            -- If formatting fails, return the unformatted string
            return Locales[Config.Locale][str]
        end
    else
        return Locales[Config.Locale][str]
    end
end
return 'Translation missing: ' .. str
end

-- Function to check if player has permission to use community service
function HasPermission(xPlayer)
if not xPlayer then return false end

local job = xPlayer.getJob()

-- Only police with sufficient grade
if job.name == Config.PoliceJobName and job.grade >= Config.MinimumPoliceGrade then
    return true
end

return false
end

