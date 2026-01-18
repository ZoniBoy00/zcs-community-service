Config = {}

-- Debug mode
Config.Debug = false

-- Test menu option
Config.EnableTestMenu = false

-- Language setting (en or fi)
Config.Locale = 'en'

-- Police job configuration
Config.PoliceJobName = 'police'
Config.MinimumPoliceGrade = 0 

-- Progress UI settings
Config.ProgressStyle = 'bar' -- 'bar' or 'circle'
Config.ProgressDuration = 10000 

-- Cooldown between task completions (ms)
Config.TaskCooldown = 5000

-- Interaction distance
Config.InteractionDistance = 3.0

-- Security settings
Config.SecurityEnabled = true
Config.StrictPositionCheck = true
Config.PlayerPositionCheckInterval = 5000

-- Inventory settings
Config.UseOxInventory = true 

-- Visualization
Config.ShowRestrictedArea = true 
Config.RestrictedAreaColor = {r = 50, g = 150, b = 50, a = 30}

-- Marker settings
Config.MarkerType = 2 
Config.MarkerColor = {r = 65, g = 220, b = 120, a = 180}
Config.MarkerSize = {x = 1.0, y = 1.0, z = 0.5}
Config.MarkerRenderDistance = 40.0

-- Blip settings
Config.CleaningBlipSprite = 584 -- Arrow sprite
Config.CleaningBlipColor = 47 
Config.CleaningBlipScale = 0.7 
Config.CleaningBlipAlpha = 250 
Config.CleaningBlipShowRoute = true 

Config.RetrievalBlipSprite = 478 
Config.RetrievalBlipColor = 25 
Config.RetrievalBlipScale = 0.8 
Config.RetrievalBlipAlpha = 250 

-- Delays
Config.TaskAssignmentDelay = 1500 
Config.ReleaseDelay = 1000 

-- Task type settings
Config.EnableTaskTypeSpecificSpots = true 

-- Translation helper
function _(str, ...)
    if not Locales[Config.Locale] or not Locales[Config.Locale][str] then
        return 'Translation missing: ' .. str
    end
    
    local text = Locales[Config.Locale][str]
    local args = {...}
    
    if #args > 0 then
        local success, result = pcall(string.format, text, ...)
        return success and result or text
    end
    
    return text
end

-- Permission check for QBox
function HasPermission(playerData)
    if not playerData then return false end
    
    local job = playerData.job
    if not job then return false end
    
    return job.name == Config.PoliceJobName and job.grade.level >= Config.MinimumPoliceGrade
end
