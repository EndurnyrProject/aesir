defmodule Aesir.ZoneServer.Mmo.Skill.Active do
  @moduledoc """
  Capability behaviour for skills that are actively cast.

  A skill opts into this capability by declaring `@behaviour Skill.Active` and
  implementing `cast/4`. The single `use Skill` macro supplies the definition and
  registration; this module only declares the cast contract.

  `validate/4` is optional - the interpreter runs it only when the skill defines
  it - and lets a skill reject a cast (custom range/state checks) before SP is
  charged. Ground skills (`target_type: :ground`) get a `cast/4` auto-derived by
  `use Skill` that places the skill-unit, so they implement `Skill.Ground`
  instead of writing this callback by hand.

  `mob_cast/5` is optional and preferred by the mob executor when a skill exports
  it; see its callback doc for the raw-target and row contract.
  """
  alias Aesir.ZoneServer.Mmo.Combat.SkillAttack.PreparedHit
  alias Aesir.ZoneServer.Mmo.Skill.Cost
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Ref

  @typedoc "The resolved cast target handed to `cast/4`."
  @type target ::
          :self | {:unit, non_neg_integer() | Ref.t()} | {:ground, integer(), integer()}

  @typedoc "A player, mob, or Homunculus caster state."
  @type caster :: PlayerState.t() | MobState.t() | HomunculusState.t()

  @typedoc "An aggregate-local effect returned without messaging the owner process."
  @type local_effect ::
          {:homunculus | :player, tuple()}
          | {:mob, {:apply_heal, pos_integer(), non_neg_integer(), Ref.t()}}
          | {:owner_item_cost, pos_integer(), pos_integer()}

  @typedoc "A staged external hit delivered only after aggregate settlement succeeds."
  @type external_effect :: {:prepared_external_hit, PreparedHit.t()}

  @typedoc "An effect settled by the owning aggregate after the caster state commits."
  @type effect :: local_effect() | external_effect()

  @typedoc "The entry point that caused a skill effect to run."
  @type cast_origin :: :normal | :item | :auto | :mob | :homunculus | :direct

  @doc """
  Runs the skill's effect for a validated cast. Returns the updated caster state.

  A bare `{:ok, state}` consumes the skill's declared catalysts; `{:ok, state,
  :no_consume}` completes the cast (SP, cooldown, act delay) but spares the
  catalysts (rAthena `SKILL_NOCONSUME_REQ`, e.g. Stone Curse lv 6-10 on a failed
  petrify). `{:deferred, state, descriptor}` leaves all commitments to the
  caller that settles the descriptor.
  """
  @callback cast(caster(), target(), pos_integer(), Definition.t()) ::
              {:ok, caster()}
              | {:ok, caster(), :no_consume}
              | {:local_effects, caster(), [effect()]}
              | {:deferred, caster(), term()}
              | {:error, atom()}

  @doc """
  Optional origin-aware cast entry point.

  The origin records how the already-validated cast entered the runtime; it does
  not bypass or add validation. Skills without this callback continue through
  `cast/4` unchanged.
  """
  @callback cast_with_origin(caster(), target(), pos_integer(), Definition.t(), cast_origin()) ::
              {:ok, caster()}
              | {:ok, caster(), :no_consume}
              | {:local_effects, caster(), [effect()]}
              | {:deferred, caster(), term()}
              | {:error, atom()}

  @doc """
  Optional input-aware cast entry point.

  Input-capable skills receive validated input only after the ordinary cast
  requirements have been revalidated. Skills without this callback fall back to
  `cast/4`.
  """
  @callback cast_with_input(caster(), target(), pos_integer(), Definition.t(), term()) ::
              {:ok, caster()}
              | {:ok, caster(), :no_consume}
              | {:deferred, caster(), term()}
              | {:error, atom()}

  @doc "Optional pre-cast validation, run before SP is charged. Defaults to `:ok` when absent."
  @callback validate(caster(), target(), pos_integer(), Definition.t()) ::
              :ok | {:error, atom()}

  @doc """
  Optional deferred effect, run later inside the caster's session process.

  A skill schedules it with `Skill.defer/3`, which posts the effect back to the
  caster's session; the session then invokes this callback with the scheduled
  `payload` and the caster's live state. Its return value is discarded by the
  session (like today's fire-and-forget delayed impacts) - it exists for the
  skill's own tests and for symmetry with `cast/4`.
  """
  @callback deferred(payload :: term(), caster :: caster()) :: :ok | {:error, atom()}

  @doc """
  Optional mob-cast entry point, preferred by the mob executor over `cast/4`
  when a skill exports it.

  Receives the raw resolved target (unit-typed tuples like
  `{:unit, :player, id}` / `{:ground, x, y, area}` with the `around*` area code
  intact) instead of `cast/4`'s player-shaped adapted `target()`, plus the full
  mob-skill `row`, whose `condition.val1..val5` carry per-row data such as
  summon mob ids.
  """
  @callback mob_cast(
              caster :: MobState.t(),
              raw_target :: term(),
              level :: pos_integer(),
              definition :: Definition.t(),
              row :: map()
            ) :: :ok | {:error, term()}

  @doc "Optionally resolves a dynamic cost from the caster's current state."
  @callback dynamic_cost(caster(), target(), pos_integer(), Definition.t()) :: Cost.t()

  @doc "Optionally adjusts the definition's resolved base cast range for this caster."
  @callback effective_range(
              caster(),
              pos_integer(),
              Definition.t(),
              non_neg_integer()
            ) :: non_neg_integer()

  @doc """
  Optionally resolves this cast's timing from the caster's current state,
  overriding the definition's per-level table.

  Returns the base and fixed cast times in milliseconds the interpreter should
  use for this cast (e.g. `0`/`0` for an instant combo follow-up); the
  interpreter substitutes them for the cast level before computing the renewal
  cast time. A skill without it keeps its declared table verbatim, so every
  non-implementing skill stays on the constant-time default path.
  """
  @callback dynamic_cast_time(caster(), target(), pos_integer(), Definition.t()) ::
              %{cast_time: non_neg_integer(), fixed_cast_time: non_neg_integer()}

  @optional_callbacks cast_with_origin: 5,
                      cast_with_input: 5,
                      validate: 4,
                      deferred: 2,
                      mob_cast: 5,
                      dynamic_cost: 4,
                      effective_range: 4,
                      dynamic_cast_time: 4

  @doc """
  Resolves a cast target to a unit id.

  When the target is `:self`, returns the caster's player or world identity.
  When the target is `{:unit, id}`, returns `id` directly.
  """
  @spec resolve_target_id(map(), target()) :: non_neg_integer() | Ref.t()
  def resolve_target_id(%{character_id: caster_id}, :self), do: caster_id
  def resolve_target_id(%{world_gid: caster_id}, :self), do: caster_id
  def resolve_target_id(_caster, {:unit, id}), do: id
end
