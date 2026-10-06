defmodule Aesir.ZoneServer.Mmo.Skill.CastTime do
  @moduledoc """
  Pure, mode-aware early and late cast-time computation.

  The caster adapter provides effective combat DEX/INT, raw item bonus channels,
  named status values, effective skill-table membership and caster kind. Early
  timing can be performed before validation; late timing receives its early
  value only after the cast has passed the appropriate checks. Reactions are
  data for the owning cast lifecycle, never mutations made by the formula.
  """

  alias Aesir.ZoneServer.Mmo.Mechanics
  alias Aesir.ZoneServer.Mmo.Skill.Definition

  @typedoc "A status's effect on the owning caster at a cast timing boundary."
  @type reaction :: :consume_memorize | :end_suffragium

  @typedoc "Named source inputs; missing optional item/status channels are zero."
  @type inputs :: %{
          required(:dex) => integer(),
          required(:int) => integer(),
          optional(:caster_kind) => :player | :homunculus | :mob | :npc,
          optional(:base_level) => non_neg_integer(),
          optional(:item_global_rate) => integer(),
          optional(:item_skill_rate) => integer(),
          optional(:item_global_var_flat) => integer(),
          optional(:item_skill_var_flat) => integer(),
          optional(:item_global_fixed_rate) => integer(),
          optional(:item_skill_fixed_rate) => integer() | nil,
          optional(:item_global_fixed_flat) => integer(),
          optional(:item_skill_fixed_flat) => integer(),
          optional(:statuses) => map(),
          optional(:effective_skill?) => boolean(),
          optional(:radius_level) => non_neg_integer(),
          optional(:cast_rate) => integer(),
          optional(:default_fixed_castrate) => integer()
        }

  @typedoc "An early time in milliseconds and reactions that stage earned."
  @type stage_result :: %{time: number(), reactions: [reaction()]}

  @typedoc "Cast duration parts. Total is authoritative, not necessarily their sum."
  @type result :: %{
          fixed: non_neg_integer(),
          variable: non_neg_integer(),
          total: non_neg_integer()
        }

  @typedoc "Late timing and its own reactions."
  @type resolved :: %{timing: result(), reactions: [reaction()]}

  @doc "Computes early cast timing without reading or changing status state."
  @spec early(Definition.t(), pos_integer(), inputs()) :: stage_result()
  def early(%Definition{} = definition, level, inputs),
    do: Mechanics.cast_time().early(definition, level, inputs)

  @doc "Completes late timing from the early result without changing the caster."
  @spec late(Definition.t(), pos_integer(), inputs(), number()) :: resolved()
  def late(%Definition{} = definition, level, inputs, time),
    do: Mechanics.cast_time().late(definition, level, inputs, time)

  @doc "Pure convenience composition of early and late cast timing."
  @spec compute(Definition.t(), pos_integer(), inputs()) :: result()
  def compute(%Definition{} = definition, level, inputs) do
    %{time: time} = early(definition, level, inputs)
    late(definition, level, inputs, time).timing
  end
end
