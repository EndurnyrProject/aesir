# Mob Spawn Database
# Defines where and when mobs spawn on maps
# Structure: Map name as key, list of spawn configurations

%{
  "prt_fild01" => [
    %{
      # Poring
      mob_id: 1002,
      amount: 50,
      respawn_time: 10_000,
      # Near fountain
      spawn_area: %{x: 110, y: 203, xs: 5, ys: 5}
    }
  ]
}

