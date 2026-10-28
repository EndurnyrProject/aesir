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
  alias Aesir.ZoneServer.Npc.SkillCaster
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Ref
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @typedoc "The resolved cast target handed to `cast/4`."
  @type target ::
          :self | {:unit, non_neg_integer() | Ref.t()} | {:ground, integer(), integer()}

  @typedoc "A player, mob, Homunculus, or NPC caster state."
  @type caster :: PlayerState.t() | MobState.t() | HomunculusState.t() | SkillCaster.t()

  @typedoc "An aggregate-local effect returned without messaging the owner process."
  @type local_effect ::
          {:homunculus | :player, tuple()}
          | {:mob, {:apply_heal, pos_integer(), non_neg_integer(), Ref.t()}}
          | {:owner_item_cost, pos_integer(), pos_integer()}

  @typedoc "A staged external hit or heal delivered only after aggregate settlement succeeds."
  @type external_effect ::
          {:prepared_external_hit, PreparedHit.t()}
          | {:external_heal, Ref.t(), non_neg_integer(), Ref.t()}

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
  caller that settles the descriptor. `{:failed, state, reason}` is an effect
  that failed after the requirement was spent: the cast settles as a success
  (resources, catalysts, cooldown, act delay) but reports `reason` to the
  caster instead of showing the skill. `{:skipped, state, reason}` is an effect
  the reference refuses after the requirement is paid but before its cast-end
  tail (a dead target, an implementation's early return): the requirement and
  its pacing stay, the catalysts and the cast-end hooks do not, and the caster
  sees no failure. `{:failed, state, reason, :spare_items}` is the same reported
  failure with the catalysts spared, for an implementation the reference marks
  `SKILL_NOCONSUME_REQ` (classic Basilica on Land Protector).
  """
  @callback cast(caster(), target(), pos_integer(), Definition.t()) ::
              {:ok, caster()}
              | {:ok, caster(), :no_consume}
              | {:local_effects, caster(), [effect()]}
              | {:deferred, caster(), term()}
              | {:failed, caster(), atom()}
              | {:failed, caster(), atom(), :spare_items}
              | {:skipped, caster(), atom()}
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
  Optional skill-specific cast-end requirement, checked on a player's cast when
  it ends, before the generic HP, weapon, ammo and item requirements. Nothing is
  spent when it fails. Defaults to `:ok` when absent.
  """
  @callback castend_requirement(caster(), target(), pos_integer(), Definition.t()) ::
              :ok | {:error, atom()}

  @doc """
  Optional reaction to a player's cast end refused by a cast-end check (the
  target, range, placement or cast-end requirements). Returns the caster with
  whatever the skill does on such a failure, which the owner commits like a
  cast with no cooldown, delay or cast-end tail; `:none` keeps the ordinary
  silent refusal. An interrupted cast never reaches it.
  """
  @callback castend_failed(caster(), target(), pos_integer(), Definition.t()) ::
              {:ok, caster()} | :none

  @doc """
  Optional cast-begin condition: the skill's own cast-begin rows (its specific
  checks, then its required state and statuses). A player's cast runs it after
  the weight limit and before the weapon and the SP, zeny and sphere checks;
  an Encore attempt and other casters run it before the cost check (and
  preflight runs it too). It returns the caster carrying whatever the attempt's
  completion reads. Completion never runs it again.
  """
  @callback begin_attempt(caster(), target(), pos_integer(), Definition.t()) ::
              {:ok, caster()} | {:error, term()}

  @doc """
  Optional check a player's skill use makes before its cast-begin conditions,
  once the target is known to be on the caster's map and usable (the boss
  refusal of the charm songs, a full Devotion, an Encore with nothing to
  replay). A refusal carries the reason to report.
  """
  @callback skilluse_check(caster(), target(), pos_integer(), Definition.t()) ::
              :ok | {:error, term()}

  @doc """
  Optional check a player's skill use makes once its target is in range,
  before the cast starts (Resurrection on a living target).
  """
  @callback after_range_check(caster(), target(), pos_integer(), Definition.t()) ::
              :ok | {:error, term()}

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
  summon mob ids. A skill that changes its caster returns `{:ok, mob_state}`
  with the mob's new state, which the mob keeps.
  """
  @callback mob_cast(
              caster :: MobState.t(),
              raw_target :: term(),
              level :: pos_integer(),
              definition :: Definition.t(),
              row :: map()
            ) :: :ok | {:ok, MobState.t()} | {:error, term()}

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
  use for this cast; the interpreter substitutes them for the cast level before
  the late (status) cast-time stage. A `cast_time` of `-1` means the attempt has
  no cast at all (an instant combo follow-up, ending a toggle): it is instant and
  the late stage earns no reaction, so Suffragium and renewal Foresight are kept,
  while `0` is an ordinary zero-time cast that still spends them. The early stage
  always runs on the declared table. A skill without it keeps its declared table
  verbatim, so every non-implementing skill stays on the constant-time default
  path.
  """
  @callback dynamic_cast_time(caster(), target(), pos_integer(), Definition.t()) ::
              %{cast_time: -1 | non_neg_integer(), fixed_cast_time: non_neg_integer()}

  @doc """
  Optionally resolves this cast's base after-cast delay from the caster's state
  at cast completion, overriding the definition's per-level table entry.

  The returned base still goes through the ordinary delay pipeline (status
  reductions, equipment delay rate); `0` means no act delay for this cast. A
  skill without it keeps its declared table.
  """
  @callback dynamic_after_cast_delay(caster(), target(), pos_integer(), Definition.t()) ::
              non_neg_integer()

  @doc """
  Optionally resolves this cast's catalyst list from the caster's state,
  overriding the definition's `item_cost`. The player cast path checks and
  consumes the returned list instead (e.g. a recast that only ends an effect
  needs no catalysts). A skill without it keeps its declared `item_cost`.
  """
  @callback dynamic_item_cost(caster(), target(), pos_integer(), Definition.t()) :: [
              %{id: integer(), amount: pos_integer()}
            ]

  @doc """
  Optionally scales this cast's cast time after its early stage (the DEX and
  equipment stage) and before its status stage. Used by a skill whose cast
  time grows with the caster's state (Urgent Call with Leap). A skill without
  it keeps the early time.
  """
  @callback scale_cast_time(caster(), target(), pos_integer(), number()) :: number()

  @doc """
  Optionally rewrites the caster's cooldowns after the cast's own cooldown is
  armed, for a skill whose effect arms cooldowns itself (the guild skills). A
  skill without it keeps the generic cooldown only.
  """
  @callback rearm_cooldowns(caster(), pos_integer(), Definition.t(), integer()) :: caster()

  @optional_callbacks cast_with_origin: 5,
                      scale_cast_time: 4,
                      rearm_cooldowns: 4,
                      cast_with_input: 5,
                      validate: 4,
                      castend_requirement: 4,
                      castend_failed: 4,
                      begin_attempt: 4,
                      skilluse_check: 4,
                      after_range_check: 4,
                      deferred: 2,
                      mob_cast: 5,
                      dynamic_cost: 4,
                      effective_range: 4,
                      dynamic_cast_time: 4,
                      dynamic_after_cast_delay: 4,
                      dynamic_item_cost: 4

  @doc "Returns a caster's unit id. Accepts bare `%{character_id: _}` maps from test fixtures."
  @spec caster_unit_id(
          PlayerState.t()
          | MobState.t()
          | SkillCaster.t()
          | %{character_id: integer()}
        ) :: integer()
  def caster_unit_id(%PlayerState{character_id: id}), do: id
  def caster_unit_id(%MobState{instance_id: id}), do: id
  def caster_unit_id(%SkillCaster{npc_gid: id}), do: id
  def caster_unit_id(%{character_id: id}), do: id

  @doc """
  Resolves a cast target to a unit id.

  When the target is `:self`, returns the caster's player or world identity.
  When the target is `{:unit, id}`, returns `id` directly.
  """
  @spec resolve_target_id(map(), target()) :: non_neg_integer() | Ref.t()
  def resolve_target_id(%{character_id: caster_id}, :self), do: caster_id
  def resolve_target_id(%{world_gid: caster_id}, :self), do: caster_id
  def resolve_target_id(_caster, {:unit, id}), do: id

  @doc """
  Resolves a cast target to a fully qualified `{unit_type, unit_id}` reference.

  A status-applying support skill needs the target's type, not just its id, and
  the mob cast path does not carry one: `MobSkill.Executor` adapts a row target
  down to a bare `{:unit, id}`. Assuming `:player` for that shape made a mob's
  self-buff address a nonexistent player, so the type is recovered from the
  registry's ID index instead. An id no longer registered keeps the historical
  `:player` reading, leaving player-cast behaviour unchanged.
  """
  @spec target_unit_ref(map(), target()) :: {atom(), non_neg_integer() | Ref.t()}
  def target_unit_ref(%MobState{instance_id: caster_id}, :self), do: {:mob, caster_id}
  def target_unit_ref(%{character_id: caster_id}, :self), do: {:player, caster_id}
  def target_unit_ref(_caster, {:unit, {unit_type, unit_id}}), do: {unit_type, unit_id}

  def target_unit_ref(_caster, {:unit, target_id}) do
    case UnitRegistry.unit_type_for(target_id) do
      {:ok, unit_type} -> {unit_type, target_id}
      {:error, :not_found} -> {:player, target_id}
    end
  end
end
