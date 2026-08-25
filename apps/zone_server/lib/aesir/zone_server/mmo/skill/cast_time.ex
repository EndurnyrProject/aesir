defmodule Aesir.ZoneServer.Mmo.Skill.CastTime do
  @moduledoc """
  Stateless cast-time computation for the active game mode.

  Renewal splits a skill's per-level base cast time into a fixed and a variable
  portion. Only the variable portion is reduced by the caster's DEX/INT, using
  `VCT = VCT_base * (1 - sqrt((2*DEX + INT) / 530))`. The fixed portion defaults
  to 20% of the base cast time when a skill does not declare one.

  There is no process and no time read inside this module. The caller passes a
  plain stats map, keeping computation pure and directly testable.
  `varcast_reductions` is the list of status-sourced variable-cast reduction
  percentages; each is applied as a separate multiplicative factor over the
  variable cast.

  `varcast_rate` is the separate additive variable-cast channel. It is applied
  once over the already-reduced variable cast, after the multiplicative
  `varcast_reductions` factor.

  `fixcast_rate` is the additive percentage channel on renewal's fixed portion.
  It scales the resolved fixed cast before the flat `fixed_cast` millisecond
  delta. The variable portion is derived from the unmodified fixed cast, so
  shortening the fixed portion never silently lengthens the variable one.

  Pre-renewal has a single DEX-scaled cast and reports it as the variable
  portion, keeping the public result shape stable with a zero fixed component.
  `classic_early_rate` combines equipment/global and Bragi rate changes, while
  `classic_skill_rate` preserves the named skill's separate early modifier.
  Both apply before the first integer truncation. `classic_late_reductions`
  keeps status reductions such as Suffragium separate for application after
  that truncation. Skills with `ignore_dex` skip the active ruleset's stat
  reduction while retaining the rest of that ruleset's cast behavior.
  """

  alias Aesir.ZoneServer.Mmo.Mechanics
  alias Aesir.ZoneServer.Mmo.Skill.Definition

  @typedoc "Caster stats relevant to cast-time reduction."
  @type stats :: %{
          required(:dex) => non_neg_integer(),
          required(:int) => non_neg_integer(),
          optional(:varcast_reductions) => [non_neg_integer()],
          optional(:varcast_rate) => integer(),
          optional(:fixed_cast) => integer(),
          optional(:fixcast_rate) => integer(),
          optional(:classic_early_rate) => integer(),
          optional(:classic_skill_rate) => integer(),
          optional(:classic_late_reductions) => [non_neg_integer()]
        }

  @typedoc "Computed cast-time breakdown in milliseconds."
  @type result :: %{
          fixed: non_neg_integer(),
          variable: non_neg_integer(),
          total: non_neg_integer()
        }

  @doc """
  Computes the `%{fixed, variable, total}` cast time in ms for a skill level.

  Returns an instant cast when the active ruleset resolves no cast time for the
  requested level.
  """
  @spec compute(Definition.t(), pos_integer(), stats()) :: result()
  def compute(%Definition{} = definition, level, %{dex: _dex, int: _int} = stats) do
    Mechanics.cast_time().compute(definition, level, stats)
  end
end
