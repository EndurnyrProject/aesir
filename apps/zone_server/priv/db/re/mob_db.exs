# Mob Database
# Based on rAthena mob_db.yml structure
# This file contains static mob definitions

[
  # Poring - ID: 1002
  %{
    id: 1002,
    aegis_name: :PORING,
    name: "Poring",
    level: 1,
    hp: 55,
    sp: 0,
    base_exp: 150,
    job_exp: 40,
    atk_min: 1,
    atk_max: 1,
    def: 2,
    mdef: 5,
    stats: %{
      str: 6,
      agi: 1,
      vit: 1,
      int: 0,
      dex: 6,
      luk: 5
    },
    attack_range: 1,
    skill_range: 10,
    chase_range: 12,
    size: :medium,
    race: :plant,
    element: {:water, 1},
    walk_speed: 400,
    attack_delay: 1872,
    attack_motion: 672,
    client_attack_motion: 288,
    damage_motion: 480,
    ai_type: 2,
    modes: [],
    drops: [
      %{item: "Jellopy", rate: 7000},
      %{item: "Knife_", rate: 100},
      %{item: "Sticky_Mucus", rate: 400},
      %{item: "Apple", rate: 1000},
      %{item: "Wing_Of_Fly", rate: 500},
      %{item: "Apple", rate: 150},
      %{item: "Unripe_Apple", rate: 20},
      %{item: "Poring_Card", rate: 20, steal_protected: true}
    ]
  },
  
  # Lunatic - ID: 1063
  %{
    id: 1063,
    aegis_name: :LUNATIC,
    name: "Lunatic",
    level: 3,
    hp: 60,
    sp: 0,
    base_exp: 108,
    job_exp: 60,
    atk_min: 2,
    atk_max: 3,
    def: 4,
    mdef: 20,
    stats: %{
      str: 1,
      agi: 3,
      vit: 3,
      int: 10,
      dex: 8,
      luk: 60
    },
    attack_range: 1,
    skill_range: 10,
    chase_range: 12,
    size: :small,
    race: :brute,
    element: {:neutral, 3},
    walk_speed: 200,
    attack_delay: 1456,
    attack_motion: 456,
    client_attack_motion: 264,
    damage_motion: 336,
    ai_type: 2,
    modes: [],
    drops: [
      %{item: "Clover", rate: 6500},
      %{item: "Feather", rate: 1000},
      %{item: "Carrot", rate: 100},
      %{item: "Red_Herb", rate: 1000},
      %{item: "Lunatic_Card", rate: 20, steal_protected: true}
    ]
  },
  
  # Fabre - ID: 1007
  %{
    id: 1007,
    aegis_name: :FABRE,
    name: "Fabre",
    level: 6,
    hp: 72,
    sp: 0,
    base_exp: 120,
    job_exp: 80,
    atk_min: 3,
    atk_max: 2,
    def: 24,
    mdef: 0,
    stats: %{
      str: 12,
      agi: 18,
      vit: 10,
      int: 1,
      dex: 12,
      luk: 5
    },
    attack_range: 1,
    skill_range: 10,
    chase_range: 12,
    size: :small,
    race: :insect,
    element: {:earth, 1},
    walk_speed: 400,
    attack_delay: 1672,
    attack_motion: 672,
    client_attack_motion: 480,
    damage_motion: 480,
    ai_type: 2,
    modes: [],
    drops: [
      %{item: "Fluff", rate: 6500},
      %{item: "Clover", rate: 500},
      %{item: "Green_Herb", rate: 400},
      %{item: "Wing_Of_Fly", rate: 100},
      %{item: "Fabre_Card", rate: 20, steal_protected: true}
    ]
  }
]