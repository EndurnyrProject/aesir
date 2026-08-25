defmodule Aesir.ZoneServer.Mmo.Mechanics.CastTime.PreRenewal do
  @moduledoc """
  Pre-renewal uses one DEX-scaled cast with no fixed component.
  """

  @behaviour Aesir.ZoneServer.Mmo.Mechanics.CastTime

  alias Aesir.ZoneServer.Mmo.Skill.CastTime
  alias Aesir.ZoneServer.Mmo.Skill.Definition

  @dex_scale 150

  @impl true
  @spec compute(Definition.t(), pos_integer(), CastTime.stats()) :: CastTime.result()
  def compute(%Definition{} = definition, level, %{dex: dex, int: _int} = stats) do
    case Enum.at(definition.cast_time, level - 1) do
      base when is_integer(base) and base > 0 ->
        variable = variable_cast(definition, base, dex, stats)
        %{fixed: 0, variable: variable, total: variable}

      _other ->
        %{fixed: 0, variable: 0, total: 0}
    end
  end

  defp variable_cast(definition, base, dex, stats) do
    time =
      if definition.ignore_dex do
        base * 1.0
      else
        base * max(0, @dex_scale - dex) / @dex_scale
      end

    skill_rate = Map.get(stats, :classic_skill_rate, 0)
    early_rate = Map.get(stats, :classic_early_rate, 0)

    time = time * max(0, 100 + skill_rate) / 100
    time = trunc(time * max(0, 100 + early_rate) / 100)

    stats
    |> Map.get(:classic_late_reductions, [])
    |> Enum.reduce(time * 1.0, fn reduction, acc ->
      acc * (100 - min(reduction, 100)) / 100
    end)
    |> max(0.0)
    |> trunc()
  end
end
