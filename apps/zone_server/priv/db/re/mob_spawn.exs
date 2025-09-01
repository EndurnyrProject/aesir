# Mob Spawn Database
# Defines where and when mobs spawn on maps
# Structure: Map name as key, list of spawn configurations

%{
  # Prontera Fields
  "prt_fild08" => [
    %{
      mob_id: 1002, # Poring
      amount: 130,
      respawn_time: 5000,
      spawn_area: %{x: 0, y: 0, xs: 0, ys: 0} # 0,0 means entire map
    },
    %{
      mob_id: 1002, # Poring - concentrated spawn
      amount: 10,
      respawn_time: 5000,
      spawn_area: %{x: 150, y: 150, xs: 50, ys: 50} # specific area
    },
    %{
      mob_id: 1063, # Lunatic
      amount: 50,
      respawn_time: 5000,
      spawn_area: %{x: 0, y: 0, xs: 0, ys: 0}
    },
    %{
      mob_id: 1007, # Fabre
      amount: 40,
      respawn_time: 5000,
      spawn_area: %{x: 0, y: 0, xs: 0, ys: 0}
    }
  ],
  
  # Prontera South Field
  "prt_fild00" => [
    %{
      mob_id: 1002, # Poring
      amount: 100,
      respawn_time: 5000,
      spawn_area: %{x: 0, y: 0, xs: 0, ys: 0}
    },
    %{
      mob_id: 1063, # Lunatic
      amount: 80,
      respawn_time: 5000,
      spawn_area: %{x: 0, y: 0, xs: 0, ys: 0}
    }
  ],
  
  # Prontera East Field
  "prt_fild01" => [
    %{
      mob_id: 1063, # Lunatic
      amount: 120,
      respawn_time: 5000,
      spawn_area: %{x: 0, y: 0, xs: 0, ys: 0}
    },
    %{
      mob_id: 1007, # Fabre
      amount: 60,
      respawn_time: 5000,
      spawn_area: %{x: 0, y: 0, xs: 0, ys: 0}
    }
  ],
  
  # Test spawn area - concentrated spawn for debugging
  "prontera" => [
    %{
      mob_id: 1002, # Poring
      amount: 5,
      respawn_time: 10_000,
      spawn_area: %{x: 156, y: 191, xs: 5, ys: 5} # Near fountain
    }
  ]
}