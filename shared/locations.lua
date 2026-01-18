Locations = {}

-- Service location (where players are teleported when service starts)
Locations.ServiceLocation = {
  x = 168.5071, 
  y = -1002.5361, 
  z = 29.3436
}

-- Release location (where players are teleported after service)
Locations.ReleaseLocation = {
  x = 428.0, 
  y = -984.0, 
  z = 30.0
}

-- Retrieval point (where players can get their belongings back)
Locations.RetrievalPoint = {
  x = 441.9200, 
  y = -979.6357, 
  z = 31.0
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
    {x = 165.5869, y = -1001.1230, z = 29.3453},
    {x = 141.7839, y = -992.1917, z = 29.3576},
    {x = 173.3587, y = -1006.1498, z = 29.3361},
    {x = 174.6838, y = -989.3917, z = 30.0919},
    {x = 155.6161, y = -983.9922, z = 30.0919}
  },
  
  -- Weeding spots (near plants, garden areas) 
  Weeding = {
    {x = 172.9809, y = -997.5831, z = 29.2918},
    {x = 185.3267, y = -1002.1675, z = 29.2918},
    {x = 203.1243, y = -1003.3600, z = 29.2918},
    {x = 147.9259, y = -988.0351, z = 29.2977},
    {x = 140.1307, y = -987.3079, z = 29.3082}
  },
  
  -- Scrubbing spots (walls, benches, surfaces)
  Scrubbing = {
    {x = 187.7384, y = -1012.4857, z = 29.3168},
    {x = 173.7583, y = -987.0775, z = 30.0919},
    {x = 173.5242, y = -962.7205, z = 29.8752},
    {x = 141.3152, y = -989.8867, z = 29.3650},
    {x = 199.9247, y = -983.9917, z = 30.0919}
  },
  
  -- Trash picking spots (near trash cans, littered areas) -- 193.0281, -968.5134, 28.3004, 18.2741
  PickingTrash = {
    {x = 175.1183, y = -1007.7466, z = 29.3333},
    {x = 134.3717, y = -994.1509, z = 29.3574},
    {x = 199.0107, y = -1020.5764, z = 29.4446},
    {x = 172.0197, y = -1039.0201, z = 29.3166},
    {x = 160.0620, y = -1039.6855, z = 29.2661}
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

