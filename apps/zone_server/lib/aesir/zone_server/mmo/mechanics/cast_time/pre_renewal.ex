defmodule Aesir.ZoneServer.Mmo.Mechanics.CastTime.PreRenewal do
  @moduledoc "Computes classic early DEX/item timing and late status timing separately."

  @behaviour Aesir.ZoneServer.Mmo.Mechanics.CastTime

  alias Aesir.ZoneServer.Mmo.Mechanics.CastTime.Numeric
  alias Aesir.ZoneServer.Mmo.Skill.CastTime
  alias Aesir.ZoneServer.Mmo.Skill.Definition

  @dex_scale 150

  @impl true
  @spec early(Definition.t(), pos_integer(), CastTime.inputs()) :: CastTime.stage_result()
  def early(definition, level, inputs) do
    time = Enum.at(definition.cast_time, level - 1, 0) * 1.0

    if time > 0 and not definition.ignore_dex and inputs.dex >= @dex_scale,
      do: %{time: 0, reactions: []},
      else: early_after_dex(definition, inputs, time)
  end

  defp early_after_dex(definition, inputs, time) do
    time =
      if definition.ignore_dex,
        do: time,
        else: time * (@dex_scale - inputs.dex) / @dex_scale

    time =
      time +
        if(definition.ignore_item_cast, do: 0, else: Map.get(inputs, :item_global_var_flat, 0))

    time = time + time * Map.get(inputs, :item_skill_rate, 0) / 100
    time = time + Map.get(inputs, :item_skill_var_flat, 0)

    statuses = Map.get(inputs, :statuses, %{})
    bragi = if definition.ignore_status_cast, do: 0, else: Map.get(statuses, :bragi, 0)
    memorize? = Map.get(statuses, :memorize, false) and Map.get(inputs, :effective_skill?, false)

    time =
      if memorize? and not definition.ignore_status_cast, do: time - time * 50 / 100, else: time

    item_rate = if definition.ignore_item_cast, do: 0, else: Map.get(inputs, :item_global_rate, 0)
    time = time * (1 - Numeric.float32((item_rate + bragi) / 100))
    time = time * Map.get(inputs, :cast_rate, 100) / 100

    %{time: max(trunc(time), 0), reactions: if(memorize?, do: [:consume_memorize], else: [])}
  end

  @impl true
  @spec late(Definition.t(), pos_integer(), CastTime.inputs(), number()) :: CastTime.resolved()
  def late(_definition, _level, _inputs, time) when time < 0,
    do: %{timing: %{fixed: 0, variable: 0, total: 0}, reactions: []}

  def late(_definition, _level, %{caster_kind: kind}, time) when kind in [:mob, :npc] do
    total = max(trunc(time), 0)
    %{timing: %{fixed: 0, variable: total, total: total}, reactions: []}
  end

  def late(definition, _level, inputs, time) do
    statuses = Map.get(inputs, :statuses, %{})
    time = if definition.ignore_status_cast, do: time, else: late_status_time(time, statuses)
    suffragium = Map.get(statuses, :suffragium)

    time =
      if suffragium && not definition.ignore_status_cast,
        do: time - time * suffragium / 100,
        else: time

    total = max(trunc(time), 0)
    reactions = if suffragium, do: [:end_suffragium], else: []
    %{timing: %{fixed: 0, variable: total, total: total}, reactions: reactions}
  end

  defp late_status_time(time, statuses) do
    time = time + time * Map.get(statuses, :slowcast, 0) / 100
    time = time + Map.get(statuses, :paralysis, 0)
    if Map.get(statuses, :izayoi, false), do: time - time * 50 / 100, else: time
  end

  @impl true
  @spec compute(Definition.t(), pos_integer(), CastTime.inputs()) :: CastTime.result()
  def compute(definition, level, inputs) do
    %{time: time} = early(definition, level, inputs)
    late(definition, level, inputs, time).timing
  end
end
