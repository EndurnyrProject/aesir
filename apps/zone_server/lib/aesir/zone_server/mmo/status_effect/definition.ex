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
        def modifiers(_instance, _context), do: %{def2_rate: -25}

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
    - `:duration_adjustment` - milliseconds added after resistance reduction
    - `:bypass_resistance` - skip resistance calculations entirely
    - `:initial_phase` - starting phase for multi-phase statuses
    - `:tick_interval` - default tick interval in milliseconds
    - `:duration` - base duration in milliseconds
    - `:permanent` - when true, the status never auto-expires (ignores duration)
    - `:no_save` - when true, the status is not persisted across logout (mirrors
      rAthena's `NoSave` status flag); use it for session-bound statuses that are
      rebuilt from other state or tied to live world objects
    - `:remove_on_map_change` - when true, a cross-map warp ends the status through
      the ordinary removal path (mirrors rAthena's `SCF_REMOVEONCHGMAP`); use it for
      statuses tied to a specific location or a live pairing that cannot survive the
      player leaving the map
    - `:bypass_boss_immunity` - when true, the status applies to a boss-flagged
      target even from an external caster; use it for a status a boss must be able
      to receive by design (e.g. Root locking a boss attacker), where the usual
      "boss rejects externally-sourced statuses" gate would otherwise block it
    - `:require_weapon` - list of weapon type atoms (mirrors rAthena's
      `SCF_REQUIREWEAPON`); when non-empty, the status ends the moment its
      holder wields a weapon outside the list. Enforced by
      `Interpreter.enforce_weapon_requirements/3`, called after equipment
      changes and job changes; use it for a self-buff that only functions
      with a specific weapon class (e.g. Two-Hand Quicken and a two-handed
      sword)
    - `:no_dispel` - **required**; when true, the status survives Dispel (mirrors
      rAthena's `SCF_NODISPELL` status flag). There is no default: dispel
      disposition is a per-status gameplay decision that must be made
      deliberately, so a new status cannot silently become dispellable. Note
      that this is *not* a buff/debuff distinction - rAthena's `SA_DISPELL`
      walks every entry in `status_db` and ends everything that lacks the flag,
      so Poison, Stun, Curse, Silence, Blind, Bleeding, Freeze and Stone are all
      dispellable. Mirror the `NoDispell` flag of the matching entry in
      rAthena's `db/re/status.yml`; a status with no rAthena counterpart records
      its disposition with a one-line rationale.
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
  A skill the status asks the engine to cast on its holder's behalf, naming the
  skill by its catalog name. Drained by the combat path that fired the hook.
  """
  @type auto_cast :: {:auto_cast, atom(), pos_integer(), {:unit, integer()}}

  @typedoc "A follow-up action a lifecycle callback asks the engine to run after it returns."
  @type follow_up :: {atom(), keyword()} | auto_cast()

  @typedoc """
  Result of a lifecycle callback.

  The 3-element form lets a hook request follow-ups the engine drains once the
  triggering event has settled: `{status_id, params}` applies another status
  (`on_damage`), `{:auto_cast, skill_name, level, target}` casts a skill for the
  holder (`on_dealt_damage`).
  """
  @type hook_result ::
          {:ok, StatusEntry.t()}
          | {:ok, StatusEntry.t(), [follow_up()]}
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

  @doc "Invoked when the status holder makes movement contact with another unit."
  @callback on_contact(target(), StatusEntry.t(), target(), context()) :: hook_result()

  @doc """
  Invoked on the attacker holding this status after one of its weapon hits commits.

  The attacker-side counterpart of `c:on_damage/4`, fired only for basic/weapon
  attacks - never for magic or skill damage. `hit_info` carries the `:target`,
  the `:damage` dealt and the weapon `:element`. Returning
  `{:auto_cast, skill_name, level, target}` follow-ups makes the engine cast
  those skills for the holder once the triggering hit has settled.

  Statuses that do not implement it are excluded from dispatch entirely: the
  registry indexes the implementers (`__status_capabilities__/0`), so a hit by
  an attacker holding no implementing status costs one registry read.
  """
  @callback on_dealt_damage(target(), StatusEntry.t(), map(), context()) :: hook_result()

  @doc """
  Intercepts a weapon swing before it selects Trifecta or resolves damage.

  The hook may atomically consume a single-use entry of the target (the
  `StatusStorage.take_status/3` claim pattern the Lex Aeterna hit path uses) and
  return `{:intercept, result}` to end the swing without damage, or `:continue`
  to leave the hit untouched. The first status returning an interception wins.
  """
  @callback before_weapon_hit(target(), StatusEntry.t(), map(), context()) ::
              :continue | {:intercept, term()}

  @doc """
  Post-damage hook fired on the victim after a delivered hit reduced its HP.

  Runs inside the attacker's process, and only for short-range weapon damage:
  ranged and magic hits, and hits already flagged `reflected`/`redirected`,
  never reach it. Returning `{:reflect, amount}` sends `amount` damage back to
  the attacker through the asynchronous damage path (flagged `reflected: true`,
  so it can never re-trigger this hook); `:ok` does nothing. `hit_info` carries
  the delivered `:damage`, plus the hit's `:dmg_type`, `:is_short` and
  `:element`.

  Statuses that do not implement it are excluded from dispatch entirely (the
  registry indexes the implementers), so a hit on a victim holding none costs
  one registry read.
  """
  @callback after_damage_taken(target(), StatusEntry.t(), map(), context()) ::
              :ok | {:reflect, non_neg_integer()}

  @doc """
  Pre-damage hook that may reduce or block an incoming hit before HP is applied.

  Receives the running `damage` (already reduced by statuses folded before it) in
  `hit_info` and returns the (possibly lowered) damage plus an updated instance, or
  `:remove` to both pass the hit through unchanged and expire the status.

  `hit_info` describes the hit:

    * `:damage` - the running damage, injected by the interpreter;
    * `:dmg_type` - `:physical`, `:magic` or `:misc` (rAthena's `BF_*` flag);
    * `:is_short` - whether the hit is melee-ranged;
    * `:element` - the hit's attack element;
    * `:skill_id` / `:skill_level` - the incoming skill, `nil` for a basic attack;
    * `:from_caster?` - true when the damage source is the caster themselves
      (rAthena's `src == dsrc`): a direct cast including its splash, or a basic
      attack. False for a placed skill unit's tick and status DoTs. Asserted on
      the magic and physical paths; absent on the misc paths, where traps and
      direct throws share one entry point. A hook that must not over-absorb
      should match it positively rather than assume it.

  Implementations must tolerate absent keys: match the hits they act on and let
  everything else fall through a catch-all clause.
  """
  @callback absorb_damage(target(), StatusEntry.t(), map(), context()) ::
              {:ok, integer(), StatusEntry.t()} | {:remove, integer()} | :remove

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
    :conceals,
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
    cleanse: [],
    require_weapon: []
  }

  @scalar_defaults %{
    resistance_type: nil,
    duration_adjustment: 0,
    bypass_resistance: false,
    initial_phase: nil,
    tick_interval: nil,
    duration: nil,
    permanent: false,
    no_save: false,
    remove_on_map_change: false,
    bypass_boss_immunity: false,
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
    require_weapon: {:list, :atom},
    resistance_type: {:enum, [:physical, :magical]},
    duration_adjustment: :integer,
    bypass_resistance: :boolean,
    initial_phase: :atom,
    tick_interval: {:integer, {:gt, 0}},
    duration: {:integer, {:gt, 0}},
    permanent: :boolean,
    no_save: :boolean,
    remove_on_map_change: :boolean,
    bypass_boss_immunity: :boolean,
    no_dispel: {:required, :boolean},
    icon: :atom,
    opt1: :atom,
    opt2: :atom,
    option: :atom,
    opt3: :atom,
    on_apply_effect: :atom
  }

  @typedoc """
  A hook a status module opts into by implementing it, published for the
  registry to index. Only hooks whose dispatch is on a hot path are tracked;
  the rest are called unconditionally through their no-op defaults.
  """
  @type capability :: :before_weapon_hit | :on_dealt_damage | :after_damage_taken

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @behaviour Aesir.ZoneServer.Mmo.StatusEffect.Definition
      @before_compile Aesir.ZoneServer.Mmo.StatusEffect.Definition

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
      def on_contact(_target, instance, _contact, _context), do: {:ok, instance}

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
                     on_contact: 4,
                     absorb_damage: 4,
                     dynamic_option: 1
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    dealt_damage? = Module.defines?(env.module, {:on_dealt_damage, 4})
    before_weapon_hit? = Module.defines?(env.module, {:before_weapon_hit, 4})
    after_damage_taken? = Module.defines?(env.module, {:after_damage_taken, 4})

    dealt_damage_default =
      unless dealt_damage? do
        quote do
          @impl true
          def on_dealt_damage(_target, instance, _hit_info, _context), do: {:ok, instance}
        end
      end

    before_weapon_hit_default =
      unless before_weapon_hit? do
        quote do
          @impl true
          def before_weapon_hit(_target, _instance, _attack_info, _context), do: :continue
        end
      end

    after_damage_taken_default =
      unless after_damage_taken? do
        quote do
          @impl true
          def after_damage_taken(_target, _instance, _hit_info, _context), do: :ok
        end
      end

    capabilities =
      []
      |> maybe_add_capability(before_weapon_hit?, :before_weapon_hit)
      |> maybe_add_capability(dealt_damage?, :on_dealt_damage)
      |> maybe_add_capability(after_damage_taken?, :after_damage_taken)

    quote do
      unquote(dealt_damage_default)
      unquote(before_weapon_hit_default)
      unquote(after_damage_taken_default)

      @doc false
      def __status_capabilities__, do: unquote(capabilities)
    end
  end

  defp maybe_add_capability(capabilities, true, capability), do: [capability | capabilities]
  defp maybe_add_capability(capabilities, false, _capability), do: capabilities

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
