defmodule Aesir.ZoneServer.Mmo.Skills.Mage.MgSoulstrike do
  @moduledoc """
  Soul Strike (MG_SOULSTRIKE). Single-target ghost magic that deals a level-scaled
  number of separate hits at full magic attack each, with a bonus against the
  undead.

  The hit count gains one hit every two levels, so level 1 and 2 land one hit and
  level 9 and 10 land five. Each hit is worth 100% of magic attack, raised by
  `5 * level` percent when the target is undead by race or by defensive element.
  Both modes agree on all of that.

  Renewal casts it in a flat 0.4 seconds of variable time plus a 0.1 second
  fixed component, then locks the caster for 1.4 seconds at every level.

  Pre-renewal casts it in a flat 0.5 seconds of purely variable time, and the
  aftercast lock zig-zags with level instead of being flat, climbing from 1.2
  seconds at level 1 to 1.8 seconds at level 10 with every even level shorter
  than the odd level below it.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 13,
    name: :mg_soulstrike,
    requires: [],
    display_name: "Soul Strike",
    max_level: 10,
    target_type: :target_enemy,
    damage_type: :damage,
    damage_kind: :magic,
    element: :ghost,
    range: 9,
    cast_time: [renewal: List.duplicate(400, 10), pre_renewal: List.duplicate(500, 10)],
    fixed_cast_time: List.duplicate(100, 10),
    after_cast_delay: [
      renewal: List.duplicate(1400, 10),
      pre_renewal: [1200, 1000, 1400, 1200, 1600, 1400, 1800, 1600, 2000, 1800]
    ],
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
      {:ok, _ref} -> {:ok, caster}
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
