defmodule Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator do
  @moduledoc """
  Aggregates stat modifiers from all active statuses on a unit.

  Each status module computes its own modifiers from its instance and context;
  this module merges them, summing numeric values for modifiers contributed by
  more than one status. Non-numeric modifiers (e.g. the atom-valued
  `attack_element`) cannot be summed — the newer status wins, mirroring
  rAthena's latest-status-overwrites semantics.
  """

  alias Aesir.ZoneServer.Mmo.StatusEffect.ContextBuilder
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Mmo.StatusStorage

  @doc """
  Returns the merged modifiers for all active statuses on a unit.
  """
  @spec get_all_modifiers(atom(), integer()) :: map()
  def get_all_modifiers(unit_type, unit_id) do
    unit_type
    |> StatusStorage.get_unit_statuses(unit_id)
    |> Enum.sort_by(&{&1.started_at, &1.type})
    |> Enum.reduce(%{}, fn instance, acc ->
      case Registry.get_definition(instance.type) do
        nil ->
          acc

        definition ->
          context = ContextBuilder.build_context(unit_type, unit_id, instance.source_id, instance)
          merge_modifiers(acc, definition.module.modifiers(instance, context))
      end
    end)
  end

  @doc """
  Merges two modifier maps, summing numeric values present in both.

  `:walk_speed_override` is an exact final value, so the most recently
  applied status wins. Status instances are sorted by application time before
  they reach this function, with the status type as a stable tie-breaker.

  When either colliding value is non-numeric the value from `new` wins.
  """
  @spec merge_modifiers(map(), map()) :: map()
  def merge_modifiers(base, new) do
    Map.merge(base, new, fn
      :walk_speed_override, _v1, v2 -> v2
      _key, v1, v2 when is_number(v1) and is_number(v2) -> v1 + v2
      _key, _v1, v2 -> v2
    end)
  end
end
