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
  alias Aesir.ZoneServer.Mmo.Skill.Cost
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @typedoc "The resolved cast target handed to `cast/4`."
  @type target :: :self | {:unit, non_neg_integer()} | {:ground, integer(), integer()}

  @typedoc "A caster state, either a player or a mob."
  @type caster :: PlayerState.t() | MobState.t()

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
  @callback dynamic_cost(PlayerState.t(), target(), pos_integer(), Definition.t()) :: Cost.t()

  @optional_callbacks validate: 4, deferred: 2, mob_cast: 5, dynamic_cost: 4

  @doc """
  Resolves a cast target to a unit id.

  When the target is `:self`, returns the caster's own `character_id`.
  When the target is `{:unit, id}`, returns `id` directly.
  """
  @spec resolve_target_id(map(), target()) :: non_neg_integer()
  def resolve_target_id(%{character_id: caster_id}, :self), do: caster_id
  def resolve_target_id(_caster, {:unit, id}), do: id
end
