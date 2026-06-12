defmodule Aesir.ZoneServer.Mmo.MobManagement.Mobs.Fabre do
  @moduledoc false
  use Aesir.ZoneServer.Mmo.MobManagement.Definition,
    id: 1007,
    aegis_name: :FABRE,
    name: "Fabre",
    level: 6,
    hp: 72,
    base_exp: 120,
    job_exp: 80,
    atk_min: 2,
    atk_max: 3,
    def: 24,
    stats: %{str: 12, agi: 18, vit: 10, int: 1, dex: 12, luk: 5},
    attack_range: 1,
    size: :small,
    race: :insect,
    element: {:earth, 1},
    walk_speed: 400,
    attack_delay: 1_672,
    attack_motion: 672,
    client_attack_motion: 480,
    damage_motion: 480,
    ai_type: 2,
    drops: [
      %{item: "Fluff", rate: 6_500},
      %{item: "Clover", rate: 500},
      %{item: "Green_Herb", rate: 400},
      %{item: "Wing_Of_Fly", rate: 100},
      %{item: "Fabre_Card", rate: 20, steal_protected: true}
    ]
end
