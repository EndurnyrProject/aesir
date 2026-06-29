defmodule Aesir.ZoneServer.Mmo.StatusEffect.Definition do
  @moduledoc """
  Behaviour and macro for defining status effects as plain Elixir modules.

  A status effect module declares its static metadata (properties, immunities,
  relationships with other statuses) through `use` options, validated with Peri
  at compile time, and implements its behavior through optional callbacks.

  ## Example

      defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Poison do
        use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
          id: :sc_poison,
          properties: [:debuff, :damage_over_time],
          calc_flags: [:def],
          immunity: [:boss, :plant],
          tick_interval: 1_000

        @impl true
        def modifiers(_instance, _context), do: %{def2: -25}

        @impl true
        def on_tick(target, instance, context) do
          # plain Elixir, full pattern matching and tooling
          {:ok, instance}
        end
      end

  ## Metadata options

    - `:id` - the status identifier atom (required, e.g. `:sc_poison`)
    - `:properties` - list of known properties (`:buff`, `:debuff`, etc.)
    - `:calc_flags` - stat recalculation flags
    - `:flags` - behavior flags (`:no_move`, `:no_attack`, ...)
    - `:prevented_by` - statuses that prevent this one from being applied
    - `:conflicts_with` - statuses that cannot coexist with this one
    - `:end_on_start` - statuses removed when this one is applied
    - `:allow_skills` - skill ids exempt from this status' `:prevents_skills`, e.g.
      the skill that toggles the status off (Play Dead recasts NV_TRICKDEAD)
    - `:immunity` - races/elements/special flags immune to this status
    - `:cleanse` - statuses that cure this one
    - `:resistance_type` - `:physical` or `:magical`
    - `:bypass_resistance` - skip resistance calculations entirely
    - `:initial_phase` - starting phase for multi-phase statuses
    - `:tick_interval` - default tick interval in milliseconds
    - `:duration` - base duration in milliseconds
    - `:permanent` - when true, the status never auto-expires (ignores duration)
    - `:icon` - `:efst` id atom for the buff/debuff icon bar (resolved via `Mmo.Efst`)
    - `:opt1` - sprite body state, e.g. `:stone | :freeze` (`Mmo.Opt1`, single-valued)
    - `:opt2` - sprite health state, e.g. `:poison | :curse` (`Mmo.Opt2`, bitmask)
    - `:option` - sprite effect state, e.g. `:hide | :cloak` (`Mmo.Option`, bitmask)
    - `:opt3` - sprite virtue state (`Mmo.Opt3`, bitmask)
    - `:on_apply_effect` - `:ef_*` one-shot effect fired on apply (`Mmo.EffectId`)
  """

  alias Aesir.ZoneServer.Mmo.DefinitionValidation
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Unit

  @typedoc "The unit a status effect is attached to."
  @type target :: {Unit.unit_type(), integer()}

  @typedoc "Execution context with target/caster stats, built by ContextBuilder."
  @type context :: map()

  @typedoc """
  Result of a lifecycle callback.

  The 3-element form lets `on_damage` request follow-up status applications
  (`[{status_id, params}]`) that the interpreter drains after the damage settles.
  """
  @type hook_result ::
          {:ok, StatusEntry.t()}
          | {:ok, StatusEntry.t(), [{atom(), keyword()}]}
          | :remove
          | {:error, term()}

  @doc "Returns the status identifier atom."
  @callback id() :: atom()

  @doc "Returns the validated static metadata for this status."
  @callback metadata() :: map()

  @doc "Returns the stat modifiers granted by this status for the given instance."
  @callback modifiers(StatusEntry.t(), context()) :: map()

  @doc "Invoked when the status is applied. May veto the application by returning :remove."
  @callback on_apply(target(), StatusEntry.t(), context()) :: hook_result()

  @doc "Invoked when the status is removed or expires."
  @callback on_expire(target(), StatusEntry.t(), context()) :: :ok

  @doc "Invoked on every tick while the status is active."
  @callback on_tick(target(), StatusEntry.t(), context()) :: hook_result()

  @doc "Invoked when the unit holding this status takes damage."
  @callback on_damage(target(), StatusEntry.t(), map(), context()) :: hook_result()

  @doc """
  Pre-damage hook that may reduce or block an incoming hit before HP is applied.

  Receives the running `damage` (already reduced by statuses folded before it) in
  `hit_info` and returns the (possibly lowered) damage plus an updated instance, or
  `:remove` to both pass the hit through unchanged and expire the status.
  """
  @callback absorb_damage(target(), StatusEntry.t(), map(), context()) ::
              {:ok, integer(), StatusEntry.t()} | :remove

  @doc """
  Derives an `Option` sprite bit from this status' live instance.

  Unlike the static `:option` metadata (fixed per definition), this lets a
  status pick its sprite bit from the instance's stored values, so the same
  status can light up different sprites (e.g. the cart tier). Defaults to `nil`,
  meaning the status contributes nothing beyond its static opt metadata.
  """
  @callback dynamic_option(StatusEntry.t()) :: atom() | nil

  @known_properties [
    :buff,
    :debuff,
    :damage_over_time,
    :prevents_movement,
    :prevents_skills,
    :prevents_attack,
    :untargetable,
    :physical,
    :magical,
    :no_resistance
  ]

  @list_defaults %{
    properties: [],
    calc_flags: [],
    flags: [],
    prevented_by: [],
    conflicts_with: [],
    end_on_start: [],
    allow_skills: [],
    immunity: [],
    cleanse: []
  }

  @scalar_defaults %{
    resistance_type: nil,
    bypass_resistance: false,
    initial_phase: nil,
    tick_interval: nil,
    duration: nil,
    permanent: false,
    icon: nil,
    opt1: nil,
    opt2: nil,
    option: nil,
    opt3: nil,
    on_apply_effect: nil
  }

  @metadata_schema %{
    id: {:required, :atom},
    properties: {:list, {:enum, @known_properties}},
    calc_flags: {:list, :atom},
    flags: {:list, :atom},
    prevented_by: {:list, :atom},
    conflicts_with: {:list, :atom},
    end_on_start: {:list, :atom},
    allow_skills: {:list, :integer},
    immunity: {:list, :atom},
    cleanse: {:list, :atom},
    resistance_type: {:enum, [:physical, :magical]},
    bypass_resistance: :boolean,
    initial_phase: :atom,
    tick_interval: {:integer, {:gt, 0}},
    duration: {:integer, {:gt, 0}},
    permanent: :boolean,
    icon: :atom,
    opt1: :atom,
    opt2: :atom,
    option: :atom,
    opt3: :atom,
    on_apply_effect: :atom
  }

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @behaviour Aesir.ZoneServer.Mmo.StatusEffect.Definition

      @status_effect_metadata Aesir.ZoneServer.Mmo.StatusEffect.Definition.validate_metadata!(
                                opts,
                                __MODULE__
                              )

      @impl true
      def id, do: @status_effect_metadata.id

      @impl true
      def metadata, do: @status_effect_metadata

      @impl true
      def modifiers(_instance, _context), do: %{}

      @impl true
      def on_apply(_target, instance, _context), do: {:ok, instance}

      @impl true
      def on_expire(_target, _instance, _context), do: :ok

      @impl true
      def on_tick(_target, instance, _context), do: {:ok, instance}

      @impl true
      def on_damage(_target, instance, _damage_info, _context), do: {:ok, instance}

      @impl true
      def absorb_damage(_target, instance, %{damage: damage}, _context),
        do: {:ok, damage, instance}

      @impl true
      def dynamic_option(_instance), do: nil

      defoverridable modifiers: 2,
                     on_apply: 3,
                     on_expire: 3,
                     on_tick: 3,
                     on_damage: 4,
                     absorb_damage: 4,
                     dynamic_option: 1
    end
  end

  @doc """
  Validates `use` options against the metadata schema and fills in defaults.

  Raises `ArgumentError` at compile time when the metadata is invalid, naming
  the offending module and fields.
  """
  @spec validate_metadata!(keyword(), module()) :: map()
  def validate_metadata!(opts, module) do
    DefinitionValidation.validate!(
      @metadata_schema,
      opts,
      module,
      Map.merge(@list_defaults, @scalar_defaults)
    )
  end
end
