Config = {}

Config.Framework = 'QBCore' -- 'ESX' or 'QBCore'

Config.TrashBagRespawnTime = 120000

Config.ServiceLocations = {
    {coords = vector3(170.0, -990.0, 30.0), label = "Trash Collection"},
    {coords = vector3(180.0, -980.0, 30.0), label = "Graffiti Cleaning"},
    {coords = vector3(190.0, -970.0, 30.0), label = "Street Sweeping"},
    {coords = vector3(200.0, -960.0, 30.0), label = "Park Maintenance"}
}

Config.TaskDuration = 10 -- seconds per task
Config.Blip = {
    sprite = 52,
    color = 5,
    scale = 0.8
}

Config.Locale = 'en' -- 'en' for English, 'fi' for Finnish