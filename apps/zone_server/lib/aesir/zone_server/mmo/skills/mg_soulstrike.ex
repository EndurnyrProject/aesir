defmodule Aesir.ZoneServer.Mmo.Skills.MgSoulstrike do
  @moduledoc """
  Soul Strike (MG_SOULSTRIKE). Single-target ghost magic that deals a level-scaled
  number of separate hits at 100% MATK each, with a bonus against the undead.

  rAthena renewal: ghost element, hits `[1,1,2,2,3,3,4,4,5,5]` (one extra hit every
  two levels), range 9. The per-hit ratio is 100% plus `5 * level`% when the target
  is undead (undead race or undead defense element).
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 13,
    name: :mg_soulstrike,
    display_name: "Soul Strike",
    max_level: 10,
    target_type: :target_enemy,
    damage_type: :damage,
    damage_kind: :magic,
    element: :ghost,
    range: 9,
    cast_time: List.duplicate(400, 10),
    fixed_cast_time: List.duplicate(100, 10),
    after_cast_delay: List.duplicate(1400, 10),
    sp_cost: [18, 14, 24, 20, 30, 26, 36, 32, 42, 38]

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.RaceModifiers
  alias Aesir.ZoneServer.Mmo.Skill.Active

  @behaviour Active

  @impl Active
  def cast(caster, {:unit, target_id}, level, definition) do
    opts = [
      skill_id: definition.id,
      skill_level: level,
      skill_ratio: skill_ratio(target_id, level),
      hit_count: div(level + 1, 2),
      element: definition.element,
      skip_range: true
    ]

    case Combat.execute_magic_attack(caster, target_id, opts) do
      :ok -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end

  @spec skill_ratio(integer(), pos_integer()) :: pos_integer()
  defp skill_ratio(target_id, level) do
    if undead_target?(target_id), do: 100 + 5 * level, else: 100
  end

  @spec undead_target?(integer()) :: boolean()
  defp undead_target?(target_id) do
    case Combat.resolve_combatant(target_id) do
      {:ok, %{race: race, element: element}} ->
        RaceModifiers.undead?(race) or undead_element?(element)

      {:error, _reason} ->
        false
    end
  end

  @spec undead_element?(tuple() | atom()) :: boolean()
  defp undead_element?({element, _level}), do: element == :undead
  defp undead_element?(element), do: element == :undead
end
