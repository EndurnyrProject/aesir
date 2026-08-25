defmodule Aesir.ZoneServer.Mmo.Mechanics.CastTime.Renewal do
  @moduledoc """
  Renewal cast time splits a skill's base time into fixed and variable portions.
  """

  @behaviour Aesir.ZoneServer.Mmo.Mechanics.CastTime

  alias Aesir.ZoneServer.Mmo.Skill.CastTime
  alias Aesir.ZoneServer.Mmo.Skill.Definition

  @vcast_stat_scale 530
  @default_fixed_castrate 0.2

  # A single status's variable-cast reduction cannot remove more than the full
  # variable portion, so 100% is the per-factor ceiling.
  @max_varcast_reduction 100

  @impl true
  @spec compute(Definition.t(), pos_integer(), CastTime.stats()) :: CastTime.result()
  def compute(%Definition{} = definition, level, %{dex: _dex, int: _int} = stats) do
    base = Enum.at(definition.cast_time, level - 1)
    compute_for_base(base, definition, level, stats)
  end

  @spec compute_for_base(
          nil | non_neg_integer(),
          Definition.t(),
          pos_integer(),
          CastTime.stats()
        ) :: CastTime.result()
  defp compute_for_base(base, definition, level, stats) when base in [nil, 0] do
    case Enum.at(definition.fixed_cast_time, level - 1) do
      fixed when is_integer(fixed) and fixed > 0 ->
        fixed = adjust_fixed(fixed, stats)
        %{fixed: fixed, variable: 0, total: fixed}

      _other ->
        %{fixed: 0, variable: 0, total: 0}
    end
  end

  defp compute_for_base(base, definition, level, stats) do
    %{dex: dex, int: int} = stats
    varcast_reductions = Map.get(stats, :varcast_reductions, [])
    varcast_rate = Map.get(stats, :varcast_rate, 0)

    fct_base = fixed_cast(definition, level, base)
    fct = adjust_fixed(fct_base, stats)
    vct_base = max(0, base - fct_base)
    reduction = stat_reduction(definition, dex, int)
    vct_after_stat = round(vct_base * reduction)

    factor =
      Enum.reduce(varcast_reductions, 1.0, fn r, acc ->
        acc * (100 - min(r, @max_varcast_reduction)) / 100
      end)

    vct_reduced = max(0, round(vct_after_stat * factor))
    vct = round(vct_reduced * max(0, 100 + varcast_rate) / 100)

    %{fixed: fct, variable: vct, total: fct + vct}
  end

  # Applies the percentage `fixcast_rate` scaling, then the flat `fixed_cast`
  # delta, to a resolved fixed-cast base; floored at 0.
  @spec adjust_fixed(non_neg_integer(), CastTime.stats()) :: non_neg_integer()
  defp adjust_fixed(fct_base, stats) do
    rate = Map.get(stats, :fixcast_rate, 0)
    scaled = round(fct_base * max(0, 100 + rate) / 100)
    max(0, scaled + Map.get(stats, :fixed_cast, 0))
  end

  @spec stat_reduction(Definition.t(), non_neg_integer(), non_neg_integer()) :: float()
  defp stat_reduction(%{ignore_dex: true}, _dex, _int), do: 1.0

  defp stat_reduction(_definition, dex, int) do
    max(0.0, 1 - :math.sqrt((2 * dex + int) / @vcast_stat_scale))
  end

  @spec fixed_cast(Definition.t(), pos_integer(), non_neg_integer()) :: non_neg_integer()
  defp fixed_cast(definition, level, base) do
    case Enum.at(definition.fixed_cast_time, level - 1) do
      value when is_integer(value) -> value
      nil -> round(base * @default_fixed_castrate)
    end
  end
end
