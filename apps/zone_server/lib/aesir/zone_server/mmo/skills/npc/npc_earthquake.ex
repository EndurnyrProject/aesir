defmodule Aesir.ZoneServer.Mmo.Skills.Npc.NpcEarthquake do
  @moduledoc """
  NPC Earthquake (NPC_EARTHQUAKE), a monster's neutral shockwave.

  The monster places one cell under itself that lives 910 ms, ignores Land
  Protector, and strikes every enemy within 5, 7, 9, 11 or 13 cells of it (by
  level, repeating from level 6) once every 300 ms, from when it first reached
  that enemy. A strike is magic damage that ignores MDEF: the monster's
  attack (raised by its attack-percent statuses in pre-renewal) at
  `200 + 100 * level + 100 * (level / 2)` percent, plus 100 from level 5,
  split evenly among the enemies within the same distance of the cell.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 653,
    name: :npc_earthquake,
    requires: [],
    display_name: "NPC Earthquake",
    max_level: 10,
    target_type: :ground,
    damage_type: :damage,
    damage_kind: :magic,
    element: :neutral,
    splash_radius: 5,
    hit_interval: 300,
    unit_duration: List.duplicate(910, 10),
    is_npc: true,
    damage_splash: true

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.AtkPercent
  alias Aesir.ZoneServer.Mmo.Combat.DamageInputs
  alias Aesir.ZoneServer.Mmo.Combat.SplashTargets
  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator

  @behaviour Ground

  @reach [5, 7, 9, 11, 13, 5, 7, 9, 11, 13]

  @impl Ground
  def on_place(%Group{center: center, level: level}) do
    definition = definition()

    {:ok,
     %{
       cells: [center],
       state: %{ignore_land_protector: true},
       interval: definition.hit_interval,
       duration: Enum.at(definition.unit_duration, level_index(level)),
       unit_range: reach(level)
     }}
  end

  @impl Ground
  def on_interval(%Group{} = group, _now), do: {:ok, group}

  @impl Ground
  def unit_targets(%Group{} = group, _cell, refs) do
    case Combat.resolve_combatant(group.caster_type, group.caster_id) do
      {:ok, caster} -> SplashTargets.eligible(refs, caster)
      {:error, _reason} -> []
    end
  end

  @impl Ground
  def on_unit_hit(%Group{} = group, cell, {unit_type, target_id}, _now) do
    with {:ok, caster} <- Combat.resolve_combatant(group.caster_type, group.caster_id),
         {:ok, attack} <- DamageInputs.non_player_base_attack(caster, skill_id: group.skill_id) do
      enemies =
        group.map_name |> SplashTargets.select(cell, reach(group.level), caster) |> length()

      Combat.apply_skill_unit_damage(
        caster,
        unit_type,
        target_id,
        group.skill_id,
        group.level,
        :neutral,
        100,
        base_damage: base_damage(attack, caster, group, enemies),
        ignore_mdef: true
      )
    end

    {:ok, group}
  end

  defp base_damage(attack, caster, %Group{level: level} = group, enemies) do
    attack
    |> attack_percent(caster, group.skill_id, GameMode.mode())
    |> Kernel.*(200 + 100 * level + 100 * div(level, 2) + if(level > 4, do: 100, else: 0))
    |> div(100)
    |> div(max(enemies, 1))
  end

  defp attack_percent(attack, _caster, _skill_id, :renewal), do: attack

  defp attack_percent(attack, caster, skill_id, :pre_renewal) do
    modifiers = ModifierCalculator.get_battle_modifiers(caster.unit_type, caster.unit_id)
    div(attack * AtkPercent.percent(caster.unit_type, skill_id, modifiers), 100)
  end

  defp reach(level), do: Enum.at(@reach, level_index(level))

  defp level_index(level), do: min(level, 10) - 1
end
