defmodule Aesir.ZoneServer.Mmo.Skill.CastTime do
  @moduledoc """
  Mode-aware early and late cast-time computation, pure apart from the status
  registry lookup in `held_statuses/1`.

  The caster adapter provides effective combat DEX/INT, raw item bonus channels,
  named status values, effective skill-table membership and caster kind. Early
  timing can be performed before validation; late timing receives its early
  value only after the cast has passed the appropriate checks. Reactions are
  data for the owning cast lifecycle, never mutations made by the formula.
  """

  alias Aesir.ZoneServer.Mmo.Mechanics
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry, as: StatusRegistry
  alias Aesir.ZoneServer.Mmo.StatusEntry

  @typedoc "A status's effect on the owning caster at a cast timing boundary."
  @type reaction :: :consume_memorize | :end_suffragium

  @typedoc """
  The caster's held cast-time statuses: a reduction or penalty in percent, a
  flat delay in milliseconds (`paralysis`), a count (`mandragora`), or presence.
  """
  @type statuses :: %{
          optional(
            :slowcast
            | :laziness
            | :suffragium
            | :water_insignia
            | :telekinesis_intense
            | :soulfairy
            | :bragi
            | :sacrament
            | :dance_with_wug
            | :heat_barrel
            | :mandragora
            | :paralysis
          ) => integer(),
          optional(
            :izayoi
            | :memorize
            | :freezing
            | :swing_dance
            | :elemental_option
            | :gloomy_day
          ) => boolean()
        }

  @typedoc "One held status's contribution: a `statuses()` key and its value."
  @type status_input :: {atom(), integer() | boolean()}

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
          optional(:statuses) => statuses(),
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

  @doc """
  Folds a caster's held status entries into the cast-time `statuses()` input.

  Each status declares its own input through the status definition's
  `cast_time_input/1` callback; statuses without one contribute nothing.
  """
  @spec held_statuses([StatusEntry.t()]) :: statuses()
  def held_statuses(entries) do
    Enum.reduce(entries, %{}, fn %StatusEntry{type: type} = entry, statuses ->
      with %{module: module} <- StatusRegistry.get_definition(type),
           {key, value} <- module.cast_time_input(entry) do
        Map.put(statuses, key, value)
      else
        _ -> statuses
      end
    end)
  end

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
