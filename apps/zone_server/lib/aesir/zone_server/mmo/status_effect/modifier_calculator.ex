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

  defp calculate_modifiers(unit_type, unit_id, context_builder) do
    unit_type
    |> StatusStorage.get_unit_statuses(unit_id)
    |> Enum.sort_by(&{&1.started_at, &1.type})
    |> Enum.reduce(%{}, fn instance, acc ->
      case Registry.get_definition(instance.type) do
        nil ->
          acc

        definition ->
          context = context_builder.(instance)
          merge_modifiers(acc, definition.module.modifiers(instance, context))
      end
    end)
  end

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
