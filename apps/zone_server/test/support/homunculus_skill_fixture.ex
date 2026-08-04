defmodule Aesir.ZoneServer.Mmo.Skills.Homunculus.TestSupport do
  @moduledoc false

  use Aesir.ZoneServer.Mmo.Skill,
    id: 8001,
    name: :hlif_heal,
    display_name: "Homunculus Test Support",
    max_level: 5,
    target_type: :target_ally,
    range: 5,
    sp_cost: [10, 12, 14, 16, 18],
    cooldown: List.duplicate(1_000, 5)

  @behaviour Aesir.ZoneServer.Mmo.Skill.Active

  @impl true
  def cast(caster, :self, _level, _definition) do
    effect = {:homunculus, {:apply_heal, caster.world_gid, 5, {:homunculus, caster.world_gid}}}
    {:local_effects, caster, [effect]}
  end

  def cast(caster, {:unit, {:player, _owner_id}}, _level, _definition) do
    effect = {:player, {:apply_heal, 7, {:homunculus, caster.world_gid}}}
    {:local_effects, caster, [effect]}
  end
end

defmodule Aesir.ZoneServer.Mmo.Skills.Homunculus.TestMissingBehavior do
  @moduledoc false

  use Aesir.ZoneServer.Mmo.Skill,
    id: 8003,
    name: :hlif_brain,
    display_name: "Homunculus Passive Fixture",
    max_level: 5,
    target_type: :passive
end

defmodule Aesir.ZoneServer.Mmo.Skills.Homunculus.TestEvolved do
  @moduledoc false

  use Aesir.ZoneServer.Mmo.Skill,
    id: 8004,
    name: :hlif_change,
    display_name: "Homunculus Evolved Fixture",
    max_level: 3,
    target_type: :self,
    sp_cost: List.duplicate(1, 3),
    cooldown: List.duplicate(1_000, 3)

  @behaviour Aesir.ZoneServer.Mmo.Skill.Active

  @impl true
  def cast(caster, _target, _level, _definition), do: {:ok, caster}
end

defmodule Aesir.ZoneServer.Mmo.Skills.Homunculus.TestAttack do
  @moduledoc false

  use Aesir.ZoneServer.Mmo.Skill,
    id: 8002,
    name: :hlif_avoid,
    display_name: "Homunculus Test Attack",
    max_level: 5,
    target_type: :target_enemy,
    range: 5,
    sp_cost: [20, 22, 24, 26, 28],
    cast_time: List.duplicate(100, 5),
    ignore_dex: true,
    cooldown: List.duplicate(2_000, 5)

  @behaviour Aesir.ZoneServer.Mmo.Skill.Active

  @impl true
  def cast(caster, target, level, _definition) do
    send(self(), {:homunculus_test_attack, target, level})
    {:ok, caster}
  end
end
