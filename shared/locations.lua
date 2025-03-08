Locations = {}

-- Service location (where players are teleported when service starts)
Locations.ServiceLocation = {
  x = 170.0, 
  y = -992.0, 
  z = 30.0
}

-- Release location (where players are teleported after service)
Locations.ReleaseLocation = {
  x = 428.0, 
  y = -984.0, 
  z = 30.0
}

-- Retrieval point (where players can get their belongings back)
Locations.RetrievalPoint = {
  x = 440.0, 
  y = -981.0, 
  z = 30.0
}

-- Restricted area boundary (Legion Square)
Locations.RestrictedArea = {
  center = {x = 170.0, y = -990.0, z = 30.0},
  radius = 100.0 -- 100 unit radius around Legion Square
}

-- Task-specific cleaning spots
Locations.TaskSpots = {
  -- Sweeping spots (open areas, sidewalks)
  Sweeping = {
    {x = 164.0, y = -1012.0, z = 29.39},
    {x = 150.0, y = -1008.0, z = 29.39},
    {x = 170.0, y = -1040.0, z = 29.39},
    {x = 183.0, y = -990.0, z = 29.39},
    {x = 190.0, y = -980.0, z = 29.39}
  },
  
  -- Weeding spots (near plants, garden areas)
  Weeding = {
    {x = 174.0, y = -970.0, z = 29.39},
    {x = 155.0, y = -985.0, z = 29.39},
    {x = 145.0, y = -995.0, z = 29.39},
    {x = 165.0, y = -1000.0, z = 29.39},
    {x = 180.0, y = -1005.0, z = 29.39}
  },
  
  -- Scrubbing spots (walls, benches, surfaces)
  Scrubbing = {
    {x = 195.0, y = -995.0, z = 29.39},
    {x = 200.0, y = -975.0, z = 29.39},
    {x = 185.0, y = -965.0, z = 29.39},
    {x = 165.0, y = -960.0, z = 29.39},
    {x = 145.0, y = -965.0, z = 29.39}
  },
  
  -- Trash picking spots (near trash cans, littered areas)
  PickingTrash = {
    {x = 135.0, y = -980.0, z = 29.39},
    {x = 140.0, y = -1000.0, z = 29.39},
    {x = 155.0, y = -1020.0, z = 29.39},
    {x = 175.0, y = -1025.0, z = 29.39},
    {x = 195.0, y = -1015.0, z = 29.39}
  }
}

-- Backward compatibility - keep the old format for scripts that may reference it
Locations.CleaningSpots = {}

-- Populate CleaningSpots from TaskSpots for backward compatibility
for taskType, spots in pairs(Locations.TaskSpots) do
  for _, spot in ipairs(spots) do
    table.insert(Locations.CleaningSpots, spot)
  end
end

