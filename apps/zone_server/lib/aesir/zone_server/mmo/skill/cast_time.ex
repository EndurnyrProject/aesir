defmodule Aesir.ZoneServer.Mmo.Skill.CastTime do
  @moduledoc """
  Stateless renewal cast-time computation.

  Splits a skill's per-level base cast time into a fixed and a variable portion.
  Only the variable portion is reduced by the caster's DEX/INT, following the
  renewal formula `VCT = VCT_base * (1 - sqrt((2*DEX + INT) / 530))`
  (rAthena `skill.cpp:10376`, `vcast_stat_scale = 530`). The fixed portion
  defaults to 20% of the base cast time when a skill does not declare one
  (`default_fixed_castrate = 20`, rAthena `battle.cpp:8753`).

  There is no process and no time read inside this module - the caller passes a
  plain `%{dex: , int: , varcast_reductions: }` stats map, keeping it pure and
  trivially testable. `varcast_reductions` is the LIST of status-sourced
  variable-cast reduction percentages (Suffragium, Bragi); each is applied as a
  separate multiplicative factor over the variable cast, matching rAthena
  `skill_vfcastfix` where Suffragium is a `VARCAST_REDUCTION` (its own multiply)
  and Bragi is the sole additive `reduce_cast_rate` (one multiply) -- for these
  two sources the two channels collapse to `Π((100 - r_i)/100)`
  (skill.cpp:10323/10336/10378). The interpreter reads `StatusStorage` and passes
  plain integers so this module never touches state.

  `varcast_rate` is the separate ADDITIVE variable-cast channel (rAthena
  `bVariableCastrate`, summed across sources, negative = faster). It is applied
  once as `* max(0, 100 + varcast_rate) / 100` over the already-reduced variable
  cast, after the multiplicative `varcast_reductions` factor - matching rAthena's
  distinct additive pass in `skill_vfcastfix`.

  `fixed_cast` is a FLAT millisecond delta on the fixed portion only (equipment
  fixed-cast bonuses are overwhelmingly negative). It is applied after the
  skill's own fixed cast is resolved and floored at 0; the variable portion is
  derived from the unmodified fixed cast, so shortening the fixed portion never
  silently lengthens the variable one.

  Skills with rAthena's `CastTimeFlags.IgnoreDex` set `ignore_dex` on their
  definition. Their variable portion skips the DEX/INT stat factor while still
  honoring status and equipment cast-time modifiers.
  """

  alias Aesir.ZoneServer.Mmo.Skill.Definition

  @vcast_stat_scale 530
  @default_fixed_castrate 0.2

  # A single status's variable-cast reduction cannot remove more than the full
  # variable portion, so 100% is the per-factor ceiling.
  @max_varcast_reduction 100

  @typedoc "Caster stats relevant to cast-time reduction."
  @type stats :: %{
          required(:dex) => non_neg_integer(),
          required(:int) => non_neg_integer(),
          optional(:varcast_reductions) => [non_neg_integer()],
          optional(:varcast_rate) => integer(),
          optional(:fixed_cast) => integer()
        }

  @typedoc "Computed cast-time breakdown in milliseconds."
  @type result :: %{
          fixed: non_neg_integer(),
          variable: non_neg_integer(),
          total: non_neg_integer()
        }

  @doc """
  Computes the `%{fixed, variable, total}` cast time in ms for a skill level.

  Returns an instant cast (`%{fixed: 0, variable: 0, total: 0}`) when the
  definition has neither a base nor an explicit fixed cast time for the level.
  """
  @spec compute(Definition.t(), pos_integer(), stats()) :: result()
  def compute(%Definition{} = definition, level, %{dex: _dex, int: _int} = stats) do
    base = Enum.at(definition.cast_time, level - 1)
    compute_for_base(base, definition, level, stats)
  end

  @spec compute_for_base(nil | non_neg_integer(), Definition.t(), pos_integer(), stats()) ::
          result()
  defp compute_for_base(base, definition, level, stats) when base in [nil, 0] do
    case Enum.at(definition.fixed_cast_time, level - 1) do
      fixed when is_integer(fixed) and fixed > 0 ->
        fixed = max(0, fixed + Map.get(stats, :fixed_cast, 0))
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
    fct = max(0, fct_base + Map.get(stats, :fixed_cast, 0))
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
