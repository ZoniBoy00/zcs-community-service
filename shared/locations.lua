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
    {x = 165.0491, y = -1002.8285, z = 29.3487},
    {x = 191.2736, y = -1012.1491, z = 29.3409},
    {x = 183.9668, y = -1043.8188, z = 29.3046},
    {x = 144.2263, y = -1029.8162, z = 29.3484},
    {x = 142.1835, y = -994.2222, z = 29.3575}
  },
  
  -- Weeding spots (near plants, garden areas) 
  Weeding = {
    {x = 151.8185, y = -991.8115, z = 29.7935},
    {x = 166.2451, y = -994.9388, z = 29.7935},
    {x = 176.3986, y = -983.6129, z = 29.5064},
    {x = 175.0422, y = -965.4458, z = 29.4790},
    {x = 149.5311, y = -980.1889, z = 29.6141}
  },
  
  -- Scrubbing spots (walls, benches, surfaces)
  Scrubbing = {
    {x = 187.6759, y = -1012.4960, z = 29.3168},
    {x = 183.8830, y = -991.0361, z = 29.39},
    {x = 172.4101, y = -965.5352, z = 28.3004},
    {x = 165.0, y = -960.0, z = 29.6558},
    {x = 186.0314, y = -967.4455, z = 30.0548}
  },
  
  -- Trash picking spots (near trash cans, littered areas) -- 193.0281, -968.5134, 28.3004, 18.2741
  PickingTrash = {
    {x = 171.4749, y = -962.6651, z = 29.6558},
    {x = 171.5760, y = -981.2106, z = 29.6496},
    {x = 176.0274, y = -1008.0320, z = 29.3322},
    {x = 171.7868, y = -1039.1399, z = 29.3167},
    {x = 193.0281, y = -968.5134, z = 28.3004}
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

