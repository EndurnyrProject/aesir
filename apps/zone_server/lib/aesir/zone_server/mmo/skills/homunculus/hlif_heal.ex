defmodule Aesir.ZoneServer.Mmo.Skills.Homunculus.HlifHeal do
  @moduledoc """
  Healing Touch (HLIF_HEAL). Consumes one Red Slim Potion and restores the
  owning player's HP from Lif's level, effective INT, Brain Surgery rank, and
  MATK. The Homunculus is never healed by this skill.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 8_001,
    name: :hlif_heal,
    display_name: "Healing Touch",
    max_level: 5,
    target_type: :self,
    damage_type: :no_damage,
    damage_kind: :magic,
    sp_cost: [13, 16, 19, 22, 25],
    cooldown: List.duplicate(20_000, 5),
    item_cost: [%{id: 545, amount: 1}]

  alias Aesir.ZoneServer.Mmo.Combat.DamageShared
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Homunculus.Stats
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState

  @behaviour Active

  @impl Active
  def validate(
        %HomunculusState{owner_character_id: owner_character_id},
        :self,
        _level,
        _definition
      ) do
    case TargetResolver.resolve({:player, owner_character_id}) do
      {:ok, _pid, owner, :player} -> if Unit.living?(owner), do: :ok, else: {:error, :owner_dead}
      {:error, _reason} -> {:error, :owner_not_found}
    end
  end

  @impl Active
  def cast(
        %HomunculusState{} = caster,
        :self,
        level,
        %{item_cost: [%{id: item_id, amount: amount}]}
      ) do
    base = (div(caster.level + caster.int, 5) * 30 * level) |> div(10)
    bonus = div(base * Stats.healing_touch_bonus_rate(caster), 100)
    matk = DamageShared.roll(caster.combat_stats.matk_min, caster.combat_stats.matk_max)
    heal = {:player, {:apply_heal, base + bonus + matk, {:homunculus, caster.world_gid}}}

    {:local_effects, caster, [{:owner_item_cost, item_id, amount}, heal]}
  end
end
