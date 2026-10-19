defmodule Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator do
  @moduledoc """
  Aggregates stat modifiers from all active statuses on a unit.

  Each status module computes its own modifiers from its instance and context;
  this module merges them, summing numeric values for modifiers contributed by
  more than one status. Movement slows and hastes and walk-speed floors keep
  the strongest value. Overrides and non-numeric modifiers (e.g. the
  atom-valued `attack_element`) take the newer value.
  """

  alias Aesir.ZoneServer.Mmo.StatusEffect.ContextBuilder
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Mmo.StatusStorage

  @strongest_wins [
    :walk_speed_floor,
    :haste_rate,
    :movement_speed,
    :move_haste2,
    :speed_rate_bonus
  ]

  # Status contributions that stay live at a monster's battle stages. Every
  # other key a status emits is already published in the monster's calculated
  # snapshot, so re-reading it here would apply it twice. Keyed by status
  # identity, never by key name alone: Provoke caches Def/Def2 but keeps its
  # attack percentage, and a PC-only key name is not a monster contribution.
  @monster_battle_keys %{
    sc_curse: [:atk_rate],
    sc_truesight: [:atk_rate],
    sc_concentration: [:atk_rate],
    sc_incatkrate: [:atk_rate],
    sc_bloodlust: [:atk_rate],
    sc_fleet: [:atk_rate],
    sc_stripweapon: [:atk_rate],
    sc_provoke: [:atk_rate],
    sc_jointbeat: [:atk_rate],
    sc_enchantarms: [:enchant_arms_element],
    sc_overthrust: [:skill_ratio],
    sc_aurablade: [:post_defense_atk, :post_defense_atk_excludes],
    sc_volcano: [:element_ratio],
    sc_deluge: [:element_ratio],
    sc_violentgale: [:element_ratio],
    sc_fogwall: [:normal_ranged_hit_taken_flat],
    sc_weaponperfection: [:ignore_size_penalty],
    sc_inchealrate: [:received_heal_rate]
  }

  @doc """
  Returns the merged modifiers for all active statuses on a unit.
  """
  @spec get_all_modifiers(atom(), integer()) :: map()
  def get_all_modifiers(unit_type, unit_id) do
    calculate_modifiers(unit_type, unit_id, fn instance ->
      ContextBuilder.build_context(unit_type, unit_id, instance.source_id, instance)
    end)
  end

  @doc false
  @spec get_all_modifiers(atom(), integer(), map()) :: map()
  def get_all_modifiers(unit_type, unit_id, target_stats) when is_map(target_stats) do
    calculate_modifiers(unit_type, unit_id, fn instance ->
      ContextBuilder.build_context(unit_type, unit_id, instance.source_id, instance, target_stats)
    end)
  end

  defp calculate_modifiers(unit_type, unit_id, context_builder, transform \\ &keep_all/2) do
    unit_type
    |> StatusStorage.get_unit_statuses(unit_id)
    |> Enum.sort_by(&{&1.started_at, &1.type})
    |> Enum.reduce(%{}, fn instance, acc ->
      case Registry.get_definition(instance.type) do
        nil ->
          acc

        definition ->
          context = context_builder.(instance)
          contributed = definition.module.modifiers(instance, context)
          merge_modifiers(acc, transform.(instance.type, contributed))
      end
    end)
  end

  @doc """
  Returns the modifiers a unit contributes at a live battle stage.

  A monster publishes its cached calculation inputs in `Unit.Mob.Calculated`, so
  only the matrix-classified live contributions stay here; everything else is
  already applied to the snapshot. Non-monsters keep the full aggregation.
  """
  @spec get_battle_modifiers(atom(), integer()) :: map()
  def get_battle_modifiers(:mob, unit_id) do
    calculate_modifiers(
      :mob,
      unit_id,
      fn instance ->
        ContextBuilder.build_context(:mob, unit_id, instance.source_id, instance)
      end,
      &monster_battle_modifiers/2
    )
  end

  def get_battle_modifiers(unit_type, unit_id), do: get_all_modifiers(unit_type, unit_id)

  defp keep_all(_status_id, modifiers), do: modifiers

  defp monster_battle_modifiers(status_id, modifiers) do
    allowed = Map.get(@monster_battle_keys, status_id, [])
    Map.filter(modifiers, fn {key, _value} -> live_key?(key, allowed) end)
  end

  defp live_key?(key, allowed) when is_atom(key), do: key in allowed
  defp live_key?({tag, _value}, allowed), do: tag in allowed

  @doc """
  Merges two modifier maps, summing numeric values present in both.

  `:walk_speed_override` is an exact final value, so the most recently
  applied status wins. Status instances are sorted by application time before
  they reach this function, with the status type as a stable tie-breaker.
  `:walk_speed_floor` is a minimum cell delay, so the slowest floor wins.
  `:movement_speed` (slow), `:haste_rate` and `:move_haste2` (hastes) and
  `:speed_rate_bonus` (a status bonus speed rate) are percentages of which
  only the strongest counts.
  `:def_override` and `:mdef_override` replace the computed hard DEF and MDEF, so
  the most recently merged value wins.

  When either colliding value is non-numeric the value from `new` wins.
  """
  @spec merge_modifiers(map(), map()) :: map()
  def merge_modifiers(base, new) do
    Map.merge(base, new, fn
      :walk_speed_override, _v1, v2 -> v2
      :def_override, _v1, v2 -> v2
      :mdef_override, _v1, v2 -> v2
      key, v1, v2 when key in @strongest_wins -> max(v1, v2)
      _key, v1, v2 when is_number(v1) and is_number(v2) -> v1 + v2
      _key, _v1, v2 -> v2
    end)
  end
end
