defmodule Aesir.ZoneServer.Mmo.Skill.AfterCastDelay do
  @moduledoc """
  A player's after-cast delay for one level of a skill, in milliseconds, the
  same in both modes.

  The level's table entry is the base. The Monk and Champion combo skills
  (Raging Trifecta Blow, Raging Quadruple Blow, Raging Thrust, Glacier Fist and
  Chain Crush Combo) take 1000 ms when their entry is 0, then lose 4 ms per AGI
  and 2 ms per DEX of the player's status totals. Unless the skill ignores item
  bonuses, the equipment's delay for that skill (`{:skill_delay, skill_id}`) is
  added next.

  Two percentages then sum into one reduction, capped at 100: Bragi's, unless
  the skill ignores status reductions (`ignore_status_delay`), and the
  equipment delay rate (`:delay_rate`, negative for less delay), unless it
  ignores item bonuses (`ignore_item_delay`). The delay is scaled by one minus
  that reduction, a factor computed in single precision as the source does, and
  is then truncated and never below 0.
  """

  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats

  @combo_skill_ids [263, 272, 273, 371, 372]

  @doc "The after-cast delay of `definition` at `level` for the player `caster`."
  @spec resolve(map(), Definition.t(), pos_integer()) :: non_neg_integer()
  def resolve(caster, %Definition{} = definition, level) do
    base = Enum.at(definition.after_cast_delay, level - 1) || 0
    stats = Map.get(caster, :stats)

    base
    |> combo_base(stats, definition.id)
    |> Kernel.+(skill_delay(stats, definition))
    |> scale(status_reduction(caster, definition) + item_reduction(stats, definition))
    |> trunc()
    |> max(0)
  end

  defp combo_base(base, stats, skill_id) when skill_id in @combo_skill_ids do
    if(base == 0, do: 1_000, else: base) - 4 * stat(stats, :agi) - 2 * stat(stats, :dex)
  end

  defp combo_base(base, _stats, _skill_id), do: base

  defp skill_delay(_stats, %Definition{ignore_item_delay: true}), do: 0
  defp skill_delay(stats, definition), do: equipment(stats, {:skill_delay, definition.id})

  defp status_reduction(_caster, %Definition{ignore_status_delay: true}), do: 0

  defp status_reduction(%{character_id: id}, _definition) when is_integer(id) do
    :player
    |> StatusStorage.get_unit_statuses(id)
    |> Enum.reduce(0, fn entry, acc -> acc + Map.get(entry.state || %{}, :delay_reduction, 0) end)
  end

  defp status_reduction(_caster, _definition), do: 0

  defp item_reduction(_stats, %Definition{ignore_item_delay: true}), do: 0
  defp item_reduction(stats, _definition), do: -equipment(stats, :delay_rate)

  defp scale(time, 0), do: time
  defp scale(time, reduction), do: time * single(1 - single(min(reduction, 100) / 100))

  defp single(value) do
    <<rounded::float-32>> = <<value::float-32>>
    rounded
  end

  defp stat(%PlayerStats{} = stats, name), do: PlayerStats.get_effective_stat(stats, name)
  defp stat(_stats, _name), do: 0

  defp equipment(%{modifiers: %{equipment: equipment}}, key), do: Map.get(equipment, key, 0)
  defp equipment(_stats, _key), do: 0
end
