defmodule Aesir.ZoneServer.Mmo.Skills.Npc.NpcWindattack do
  @moduledoc """
  Wind Attack (NPC_WINDATTACK). Monster-only single-target wind weapon hit.

  rAthena: flat 100% ATK wind-element weapon damage at every level. Many mob
  rows select this from `chase`/`angry` state, while the target is still
  outside the mob's melee `attack_range` (only within `skill_range`), so a
  `%MobState{}` caster's effective attack range is widened to
  `max(attack_range, skill_range)` for the call.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 187,
    name: :npc_windattack,
    requires: [],
    display_name: "Wind Attack",
    max_level: 10,
    target_type: :target_enemy,
    damage_type: :damage,
    damage_kind: :weapon,
    element: :wind,
    range: 7

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Unit.Mob.MobState

  @behaviour Active

  @impl Active
  def cast(caster, {:unit, target_id}, level, definition) do
    opts = [
      skill_id: definition.id,
      skill_level: level,
      skill_ratio: 100,
      element: definition.element
    ]

    case Combat.execute_skill_attack(widen_range(caster), target_id, opts) do
      :ok -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end

  @spec widen_range(Active.caster()) :: Active.caster()
  defp widen_range(%MobState{mob_data: mob_data} = caster) do
    %{
      caster
      | mob_data: %{mob_data | attack_range: max(mob_data.attack_range, mob_data.skill_range)}
    }
  end

  defp widen_range(caster), do: caster
end
