defmodule Aesir.ZoneServer.Unit.Session.Adapter do
  @moduledoc """
  Per-unit-type seam for the shared `unit/session/` handlers (`Vitals`,
  `Motion`).

  The shared handlers own the game logic (HP/SP clamp math, knockback ordering)
  and stay unit-type agnostic; every place they must touch a concrete unit's
  state or push a concrete unit's side effect goes through an adapter callback.
  `Player.SessionAdapter` implements it against the player session map (whose
  `:game_state` carries a `PlayerState`), `Mob.SessionAdapter` against a raw
  `MobState`.

  Two flavours of callback:

  - **Accessors** (`get_vitals/1`, `put_vitals/2`, `stop_movement/1`): pure
    reads/writes of the unit's own state shape. `get_vitals`/`put_vitals`
    round-trip; they never clamp (that is the caller's job) and never emit side
    effects.
  - **Effect seams** (`notify_vitals/2`, `set_position/2`, `commit/3`): publish
    a change to shared runtime views or the client. For players these fan out
    through `StatusSync`/`StateCommit`; for mobs through the `UnitHp` broadcast
    and the unit registry. Both are told which vitals fields actually changed so
    a caller that only touched SP does not send an HP `ParamChange` or persist a
    stale HP - matching each op's exact wire/DB footprint.
  """

  @typedoc """
  The state a session process holds and the shared handlers thread through.

  A player session map (`%{game_state: PlayerState.t(), connection_pid: pid(),
  ...}`) or a `MobState.t()`. Opaque to the shared handlers; only the adapter
  interprets it.
  """
  @type state :: term()

  @typedoc "A unit's full HP/SP snapshot, as read by `get_vitals/1`."
  @type vitals :: %{
          hp: non_neg_integer(),
          sp: non_neg_integer(),
          max_hp: pos_integer(),
          max_sp: non_neg_integer()
        }

  @typedoc """
  A partial HP/SP write for `put_vitals/2`. Absent keys are left untouched, so a
  caller that only changed SP passes `%{sp: n}`.
  """
  @type vitals_update :: %{optional(:hp) => non_neg_integer(), optional(:sp) => non_neg_integer()}

  @typedoc "A map cell, `{x, y}`."
  @type position :: {non_neg_integer(), non_neg_integer()}

  @typedoc """
  The vitals fields a single operation changed, in `[:hp | :sp]`.

  Threaded into `notify_vitals/2` and `commit/3` so each op publishes and
  persists exactly the fields it touched (SP drain sends/persists only SP).
  """
  @type fields :: [:hp | :sp]

  @doc """
  Reads the unit's current HP/SP and their maxima.
  """
  @callback get_vitals(state()) :: vitals()

  @doc """
  Writes the given HP and/or SP into the unit's state and returns it.

  A pure accessor: it neither clamps the values nor publishes anything. Absent
  keys in the update are left as they were.
  """
  @callback put_vitals(state(), vitals_update()) :: state()

  @doc """
  Pushes the given `fields` of the unit's current vitals to whoever watches them.

  Players receive a `SP_HP`/`SP_SP` `ParamChange` per requested field on their
  own connection; mobs broadcast a `UnitHp` when `:hp` is requested. Mobs have
  no client-visible SP, so a `:sp`-only notify is a no-op for them.
  """
  @callback notify_vitals(state(), fields()) :: :ok

  @doc """
  Moves the unit to `position` through the world's position choke point.

  Writes the new cell into the unit's state and publishes it via
  `Aesir.ZoneServer.Unit.Movement.set_position/4` (spatial index, unit
  registry, dirty set, cell triggers), then returns the updated state.

  Because this publishes, any state change that must appear in the published
  snapshot (notably `stop_movement/1`) has to be applied to the state *before*
  it is passed here.
  """
  @callback set_position(state(), position()) :: state()

  @doc """
  Clears the unit's active movement (walk path and movement state) and returns
  the updated state. A pure accessor: it does not publish.
  """
  @callback stop_movement(state()) :: state()

  @doc """
  Commits a vitals change to the authoritative shared views.

  Takes the pre-change state and the post-change state (the shared handlers hold
  both), so the player path can diff for party/guild projection, plus the
  `fields` that changed so only those are persisted. Players commit through
  `StateCommit` (unit registry + party/guild sync) and persist just the given
  fields; mobs refresh their unit-registry snapshot (`fields` unused, they hold
  no durable row). Returns the committed state.
  """
  @callback commit(previous :: state(), updated :: state(), fields()) :: state()
end
