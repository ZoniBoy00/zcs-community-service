-- Security measures to prevent exploits

-- Access the playersInService table from main.lua
-- This line ensures we're using the same table defined in main.lua
playersInService = playersInService or {}

-- Rate limiting for events
eventCooldowns = {} -- Make this global so it can be accessed from other files
local eventLimits = {
  ['zcs:completeTask'] = {cooldown = 5000, maxCalls = 3}, -- 5 seconds, max 3 calls
  ['zcs:requestTask'] = {cooldown = 3000, maxCalls = 2}, -- 3 seconds, max 2 calls
  ['zcs:retrieveBelongings'] = {cooldown = 10000, maxCalls = 2} -- 10 seconds, max 2 calls
}

-- Check if an event is being spammed
function IsEventSpamming(source, eventName)
  local identifier = GetPlayerIdentifier(source, 0)
  if not identifier then return true end -- Block if no identifier
  
  local currentTime = GetGameTimer()
  
  -- Initialize player's cooldown tracking if not exists
  if not eventCooldowns[identifier] then
      eventCooldowns[identifier] = {}
  end
  
  -- Initialize event tracking for this player if not exists
  if not eventCooldowns[identifier][eventName] then
      eventCooldowns[identifier][eventName] = {
          lastCall = 0,
          calls = 0,
          resetTime = 0
      }
  end
  
  local eventData = eventCooldowns[identifier][eventName]
  local eventLimit = eventLimits[eventName] or {cooldown = 1000, maxCalls = 5} -- Default limits
  
  -- Reset call counter if reset time has passed
  if currentTime > eventData.resetTime then
      eventData.calls = 0
      eventData.resetTime = currentTime + eventLimit.cooldown
  end
  
  -- Check if cooldown has passed
  if currentTime - eventData.lastCall < eventLimit.cooldown / eventLimit.maxCalls then
      eventData.calls = eventData.calls + 1
      
      -- If too many calls in the period, block and log
      if eventData.calls > eventLimit.maxCalls then
          LogSuspiciousActivity(
              GetPlayerName(source),
              identifier,
              "Event Spamming",
              "Triggered " .. eventName .. " " .. eventData.calls .. " times in " .. eventLimit.cooldown / 1000 .. " seconds"
          )
          return true
      end
  end
  
  -- Update last call time
  eventData.lastCall = currentTime
  return false
end

-- Verify player position for task completion
function VerifyPlayerPosition(source, taskPosition)
  local playerPed = GetPlayerPed(source)
  local playerCoords = GetEntityCoords(playerPed)
  
  -- Check if player is within reasonable distance of the task
  local distance = #(vector3(playerCoords.x, playerCoords.y, playerCoords.z) - 
                 vector3(taskPosition.x, taskPosition.y, taskPosition.z))
  
  -- Use the config value for interaction distance with a safe check
  local maxDistance = (Config and Config.InteractionDistance or 3.0) * 2
  
  if distance > maxDistance then
      local identifier = GetPlayerIdentifier(source, 0)
      LogSuspiciousActivity(
          GetPlayerName(source),
          identifier,
          "Position Spoofing",
          "Player attempted to complete task from " .. distance .. " units away"
      )
      return false
  end
  return true
end

-- Track player positions to detect teleportation
playerLastPositions = {} -- Make this global so it can be accessed from other files

-- Update player position tracking thread:
Citizen.CreateThread(function()
  while true do
      for _, playerId in ipairs(GetPlayers()) do
          local ped = GetPlayerPed(playerId)
          if DoesEntityExist(ped) then
              local coords = GetEntityCoords(ped)
              local identifier = GetPlayerIdentifier(playerId, 0)
              
              if identifier and playersInService and playersInService[identifier] then
                  -- Only track players in community service
                  if playerLastPositions[identifier] then
                      local distance = #(vector3(coords.x, coords.y, coords.z) - 
                                     vector3(playerLastPositions[identifier].x, playerLastPositions[identifier].y, playerLastPositions[identifier].z))
                      
                      -- If player moved too far in a short time (excluding legitimate teleports)
                      if distance > 100.0 then
                          LogSuspiciousActivity(
                              GetPlayerName(playerId),
                              identifier,
                              "Possible Teleport Hack",
                              "Player moved " .. distance .. " units instantly"
                          )
                      end
                  end
                  playerLastPositions[identifier] = coords
              end
          end
      end
      -- Use a default value if Config is not available
      local checkInterval = Config and Config.PlayerPositionCheckInterval or 5000
      Citizen.Wait(checkInterval)
  end
end)

-- Clean up player data on disconnect
AddEventHandler('playerDropped', function()
  local source = source
  local identifier = GetPlayerIdentifier(source, 0)
  
  if identifier then
      if eventCooldowns[identifier] then
          eventCooldowns[identifier] = nil
      end
      if playerLastPositions[identifier] then
          playerLastPositions[identifier] = nil
      end
  end
end)

