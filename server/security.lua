-- Security measures for Community Service (QBox)

playersInService = playersInService or {}
eventCooldowns = {}
playerLastPositions = {}

local eventLimits = {
  ['zcs:completeTask'] = {cooldown = 5000, maxCalls = 3},
  ['zcs:requestTask'] = {cooldown = 3000, maxCalls = 2},
  ['zcs:retrieveBelongings'] = {cooldown = 10000, maxCalls = 2}
}

-- Check for event exploitation
function IsEventSpamming(source, eventName)
  local identifier = GetPlayerIdentifier(source, 0) -- Use static ID for cooldowns
  if not identifier then return true end
  
  local now = GetGameTimer()
  
  if not eventCooldowns[identifier] then
      eventCooldowns[identifier] = {}
  end
  
  if not eventCooldowns[identifier][eventName] then
      eventCooldowns[identifier][eventName] = {
          lastCall = 0,
          calls = 0,
          resetTime = 0
      }
  end
  
  local data = eventCooldowns[identifier][eventName]
  local limit = eventLimits[eventName] or {cooldown = 1000, maxCalls = 5}
  
  if now > data.resetTime then
      data.calls = 0
      data.resetTime = now + limit.cooldown
  end
  
  if now - data.lastCall < (limit.cooldown / limit.maxCalls) then
      data.calls = data.calls + 1
      
      if data.calls > limit.maxCalls then
          LogSuspiciousActivity(GetPlayerName(source), identifier, "Event Abuse", "Triggered " .. eventName .. " " .. data.calls .. "x in short duration")
          return true
      end
  end
  
  data.lastCall = now
  return false
end

-- Validate player coordinate proximity to task
function VerifyPlayerPosition(source, taskPosition)
  local ped = GetPlayerPed(source)
  local coords = GetEntityCoords(ped)
  local distance = #(coords - vector3(taskPosition.x, taskPosition.y, taskPosition.z))
  local maxDistance = (Config.InteractionDistance or 3.0) * 3.0
  
  if distance > maxDistance then
      local identifier = GetPlayerIdentifier(source, 0)
      LogSuspiciousActivity(GetPlayerName(source), identifier, "Teleportation/Spreading", "Task completed from " .. math.floor(distance) .. " units away")
      return false
  end
  return true
end

-- Monitor player movement for teleportation/exploits
CreateThread(function()
    while true do
        for citizenid, _ in pairs(playersInService) do
            local player = exports.qbx_core:GetPlayerByCitizenId(citizenid)
            if player then
                local source = player.PlayerData.source
                local ped = GetPlayerPed(source)
                
                if ped and DoesEntityExist(ped) then
                    local coords = GetEntityCoords(ped)
                    
                    if playerLastPositions[citizenid] then
                        local dist = #(coords - playerLastPositions[citizenid])
                        if dist > 150.0 then
                            LogSuspiciousActivity(GetPlayerName(source), citizenid, "Movement Exploit", "Moved " .. math.floor(dist) .. " units within check interval")
                        end
                    end
                    playerLastPositions[citizenid] = coords
                end
            end
        end
        Wait(Config.PlayerPositionCheckInterval or 5000)
    end
end)

AddEventHandler('playerDropped', function()
  local source = source
  local identifier = GetPlayerIdentifier(source, 0)
  if identifier then
      eventCooldowns[identifier] = nil
  end
  -- CitizenID based tracking is hard to clean without the ID here, 
  -- but it will be overwritten on next session anyway.
end)
