defmodule Aesir.ZoneServer.Mmo.Mechanics.CastTime.Renewal do
  @moduledoc "Computes renewal variable and fixed timing with source-width arithmetic."

  @behaviour Aesir.ZoneServer.Mmo.Mechanics.CastTime

  alias Aesir.ZoneServer.Mmo.Mechanics.CastTime.Numeric
  alias Aesir.ZoneServer.Mmo.Skill.CastTime
  alias Aesir.ZoneServer.Mmo.Skill.Definition

  @stat_scale 530
  @radius_skill_ids 2_201..2_232

  @impl true
  @spec early(Definition.t(), pos_integer(), CastTime.inputs()) :: CastTime.stage_result()
  def early(definition, level, _inputs) do
    %{time: Enum.at(definition.cast_time, level - 1, 0), reactions: []}
  end

  @impl true
  @spec late(Definition.t(), pos_integer(), CastTime.inputs(), number()) :: CastTime.resolved()
  def late(_definition, _level, _inputs, time) when time < 0 do
    %{timing: zero(), reactions: []}
  end

  def late(_definition, _level, %{caster_kind: kind}, time) when kind in [:mob, :npc] do
    total = trunc(time)
    %{timing: %{fixed: 0, variable: total, total: total}, reactions: []}
  end

  def late(definition, level, inputs, time) do
    {fixed, time} = fixed_time(definition, level, inputs, time)
    {fixed, time, fixed_rate, reduce_rate} = apply_items(definition, inputs, fixed, time)
    statuses = Map.get(inputs, :statuses, %{})

    {fixed, time, fixed_rate, reduce_rate, reactions} =
      if definition.ignore_status_cast or map_size(statuses) == 0 do
        {fixed, time, fixed_rate, reduce_rate, []}
      else
        apply_statuses(definition, level, inputs, statuses, fixed, time, fixed_rate, reduce_rate)
      end

    fixed_rate =
      if definition.ignore_status_cast and definition.id == 366 and
           Map.has_key?(statuses, :sacrament),
         do: max(fixed_rate, statuses.sacrament),
         else: fixed_rate

    # A negative accumulator defers multipliers until a later reduction brings it
    # back above zero. That step itself still uses its own value as the factor.
    stat_factor =
      if definition.ignore_dex do
        1.0
      else
        stat =
          Numeric.float32((2 * Map.fetch!(inputs, :dex) + Map.fetch!(inputs, :int)) / @stat_scale)

        1 - Numeric.float32(:math.sqrt(stat))
      end

    time = time * stat_factor
    time = time * (1 - Numeric.float32(min(reduce_rate, 100) / 100))
    variable = max(trunc(time), 0)
    fixed_time = (1 - Numeric.float32(min(fixed_rate, 100) / 100)) * max(fixed, 0)

    %{
      timing: %{fixed: trunc(fixed_time), variable: variable, total: trunc(variable + fixed_time)},
      reactions: reactions
    }
  end

  @impl true
  @spec compute(Definition.t(), pos_integer(), CastTime.inputs()) :: CastTime.result()
  def compute(definition, level, inputs) do
    %{time: time} = early(definition, level, inputs)
    late(definition, level, inputs, time).timing
  end

  defp zero, do: %{fixed: 0, variable: 0, total: 0}

  defp fixed_time(definition, level, inputs, time) do
    case Enum.at(definition.fixed_cast_time, level - 1, 0) do
      fixed when fixed < 0 ->
        percent = Map.get(inputs, :default_fixed_castrate, 20)

        if percent > 0,
          do: {div(trunc(time) * percent, 100), time * (100 - percent) / 100},
          else: {0, time}

      fixed ->
        {fixed, time}
    end
  end

  defp apply_items(definition, inputs, fixed, time) do
    if definition.ignore_item_cast do
      {fixed, time, 0, 0}
    else
      {
        fixed + Map.get(inputs, :item_global_fixed_flat, 0) +
          Map.get(inputs, :item_skill_fixed_flat, 0),
        time + Map.get(inputs, :item_global_var_flat, 0) +
          Map.get(inputs, :item_skill_var_flat, 0),
        fixed_item_rate(inputs),
        Map.get(inputs, :item_global_rate, 0) - Map.get(inputs, :item_skill_rate, 0)
      }
    end
  end

  defp apply_statuses(definition, level, inputs, statuses, fixed, time, fixed_rate, reduce_rate) do
    {time, _acc} =
      [
        :slowcast,
        :laziness,
        :suffragium,
        :izayoi,
        :water_insignia,
        :telekinesis_intense,
        :soulfairy
      ]
      |> Enum.map(&status_varcast(&1, statuses, definition))
      |> Enum.reduce({time, 0}, fn value, {time, accumulator} ->
        accumulator = accumulator + value

        if accumulator != 0 and accumulator >= 0,
          do: {time * (1 - Numeric.float32(min(value, 100) / 100)), accumulator},
          else: {time, accumulator}
      end)

    memorize? = Map.get(statuses, :memorize, false) and Map.get(inputs, :effective_skill?, false)
    reduce_rate = reduce_rate + Map.get(statuses, :bragi, 0) + if(memorize?, do: 50, else: 0)

    {skill_level, fixed_rate} =
      fixed_status_rate(definition, level, inputs, statuses, fixed_rate)

    fixed = fixed_status_flat(fixed, skill_level, statuses)
    {fixed, time, fixed_rate, reduce_rate, if(memorize?, do: [:consume_memorize], else: [])}
  end

  defp fixed_status_rate(definition, level, inputs, statuses, rate) do
    rate = if Map.has_key?(statuses, :sacrament), do: max(rate, statuses.sacrament), else: rate
    radius_level = Map.get(inputs, :radius_level, 0)

    {level, rate} =
      if radius_level > 0 and definition.id in @radius_skill_ids do
        radius_rate =
          div(inputs.int + Map.get(inputs, :base_level, 0), 15) + radius_level * 5

        {radius_level, max(rate, radius_rate)}
      else
        {level, rate}
      end

    rate =
      if Map.has_key?(statuses, :dance_with_wug),
        do: max(rate, statuses.dance_with_wug),
        else: rate

    rate =
      if Map.has_key?(statuses, :heat_barrel), do: max(rate, statuses.heat_barrel), else: rate

    rate = rate - if(Map.get(statuses, :freezing, false), do: 50, else: 0)
    rate = if Map.get(statuses, :swing_dance, false), do: max(rate, level * 6), else: rate
    {level, rate}
  end

  defp fixed_status_flat(fixed, skill_level, statuses) do
    fixed =
      fixed + Map.get(statuses, :mandragora, 0) * 500 -
        if(Map.get(statuses, :elemental_option, false), do: 1_000, else: 0)

    fixed = if Map.get(statuses, :izayoi, false), do: 0, else: fixed
    fixed + skill_level * if(Map.get(statuses, :gloomy_day, false), do: 500, else: 0)
  end

  defp fixed_item_rate(inputs) do
    global = Map.get(inputs, :item_global_fixed_rate, 0)

    case Map.get(inputs, :item_skill_fixed_rate) do
      nil -> global
      per_skill -> max(global, per_skill)
    end
  end

  defp status_varcast(:slowcast, statuses, _definition), do: -Map.get(statuses, :slowcast, 0)
  defp status_varcast(:laziness, statuses, _definition), do: -Map.get(statuses, :laziness, 0)
  defp status_varcast(:suffragium, statuses, _definition), do: Map.get(statuses, :suffragium, 0)

  defp status_varcast(:izayoi, statuses, _definition),
    do: if(Map.get(statuses, :izayoi, false), do: 50, else: 0)

  defp status_varcast(:water_insignia, statuses, %{damage_kind: :magic, element: :water}),
    do: Map.get(statuses, :water_insignia, 0)

  defp status_varcast(:water_insignia, _statuses, _definition), do: 0
  defp status_varcast(key, statuses, _definition), do: Map.get(statuses, key, 0)
end
