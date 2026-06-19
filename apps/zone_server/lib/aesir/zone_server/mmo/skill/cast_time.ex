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
  plain `%{dex: , int: }` stats map, keeping it pure and trivially testable.
  """

  alias Aesir.ZoneServer.Mmo.Skill.Definition

  @vcast_stat_scale 530
  @default_fixed_castrate 0.2

  @typedoc "Caster stats relevant to cast-time reduction."
  @type stats :: %{dex: non_neg_integer(), int: non_neg_integer()}

  @typedoc "Computed cast-time breakdown in milliseconds."
  @type result :: %{
          fixed: non_neg_integer(),
          variable: non_neg_integer(),
          total: non_neg_integer()
        }

  @doc """
  Computes the `%{fixed, variable, total}` cast time in ms for a skill level.

  Returns an instant cast (`%{fixed: 0, variable: 0, total: 0}`) when the
  definition has no base cast time for the level (empty list) or the base is `0`.
  """
  @spec compute(Definition.t(), pos_integer(), stats()) :: result()
  def compute(%Definition{} = definition, level, %{dex: dex, int: int}) do
    base = Enum.at(definition.cast_time, level - 1)
    compute_for_base(base, definition, level, dex, int)
  end

  @spec compute_for_base(
          nil | non_neg_integer(),
          Definition.t(),
          pos_integer(),
          integer(),
          integer()
        ) ::
          result()
  defp compute_for_base(base, _definition, _level, _dex, _int) when base in [nil, 0] do
    %{fixed: 0, variable: 0, total: 0}
  end

  defp compute_for_base(base, definition, level, dex, int) do
    fct = fixed_cast(definition, level, base)
    vct_base = max(0, base - fct)
    reduction = max(0.0, 1 - :math.sqrt((2 * dex + int) / @vcast_stat_scale))
    vct = max(0, round(vct_base * reduction))

    %{fixed: fct, variable: vct, total: fct + vct}
  end

  @spec fixed_cast(Definition.t(), pos_integer(), non_neg_integer()) :: non_neg_integer()
  defp fixed_cast(definition, level, base) do
    case Enum.at(definition.fixed_cast_time, level - 1) do
      value when is_integer(value) -> value
      nil -> round(base * @default_fixed_castrate)
    end
  end
end
