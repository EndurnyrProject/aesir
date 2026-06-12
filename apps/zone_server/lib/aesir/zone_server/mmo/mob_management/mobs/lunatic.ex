defmodule Aesir.ZoneServer.Mmo.MobManagement.Mobs.Lunatic do
  @moduledoc false
  use Aesir.ZoneServer.Mmo.MobManagement.Definition,
    id: 1063,
    aegis_name: :LUNATIC,
    name: "Lunatic",
    level: 3,
    hp: 60,
    base_exp: 108,
    job_exp: 60,
    atk_min: 2,
    atk_max: 3,
    def: 4,
    mdef: 20,
    stats: %{str: 1, agi: 3, vit: 3, int: 10, dex: 8, luk: 60},
    attack_range: 1,
    size: :small,
    race: :brute,
    element: {:neutral, 3},
    walk_speed: 200,
    attack_delay: 1_456,
    attack_motion: 456,
    client_attack_motion: 264,
    damage_motion: 336,
    ai_type: 2,
    drops: [
      %{item: "Clover", rate: 6_500},
      %{item: "Feather", rate: 1_000},
      %{item: "Carrot", rate: 100},
      %{item: "Red_Herb", rate: 1_000},
      %{item: "Lunatic_Card", rate: 20, steal_protected: true}
    ]
end
