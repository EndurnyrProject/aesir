defmodule Aesir.ZoneServer.Mmo.Skill.Ground do
  @moduledoc """
  Capability behaviour for skills that place a persistent ground skill-unit
  (rAthena `skill_unit_group`).

  A skill opts in by declaring `@behaviour Skill.Ground` and implementing
  `on_place/1` and `on_interval/2`. The framework (storage, central tick,
  placement) stays skill-agnostic and dispatches through `Skill.Catalog`. Because
  these skills are `target_type: :ground`, `use Skill` auto-derives the active
  `cast/4` that places the unit, so the skill needs no separate cast module.

  `schedule/2` and `on_expire/1` are optional. The manager invokes `schedule/2`
  once, while serializing registration, when a skill needs a manager-owned
  randomized schedule.

  `on_touch/2` and `on_out/2` are optional movement-pipeline hooks fired when a
  unit steps onto / off a footprint cell (traps, Warp Portal, Fire Wall); the
  movement chokepoint invokes them only when the skill module exports them.

  ## Documented extension points (not part of this contract yet)

  This belongs to a later layer and is intentionally NOT declared as a callback
  (YAGNI):

    - cell-flag set/clear hooks (`walkable?` / block) - Safety Wall, Ice Wall,
      Pneuma, Land Protector.
  """

  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.LifecyclePolicy

  @typedoc "A single map cell occupied by a skill-unit footprint."
  @type cell :: {integer(), integer()}

  @typedoc "A movement callback result serialized and persisted by the skill-unit manager."
  @type trigger_result :: {:ok, Group.t()} | :expire

  @typedoc "The placement result: footprint, initial per-skill state, timing, and optional lifecycle policy."
  @type placement :: %{
          optional(:lifecycle_policy) => LifecyclePolicy.t(),
          optional(:initial_delay) => non_neg_integer(),
          optional(:cell_attrs) => %{cell() => map()},
          optional(:path_check) => boolean(),
          optional(:visible?) => boolean(),
          cells: [cell()],
          state: map(),
          interval: pos_integer(),
          duration: pos_integer()
        }

  @doc "Invoked once at placement. Returns footprint, initial state, and timing."
  @callback on_place(Group.t()) :: {:ok, placement()}

  @doc """
  Invoked every `interval` ms while the group is alive.

  Runs the effect against units in the footprint and returns the updated group.
  Returning `{:expire, group}` ends the group early.
  """
  @callback on_interval(Group.t(), now :: integer()) ::
              {:ok, Group.t()} | {:expire, Group.t()}

  @doc "Builds manager-owned schedule state with the injected zero-based RNG. Optional."
  @callback schedule(Group.t(), rng :: (pos_integer() -> non_neg_integer())) :: {:ok, Group.t()}

  @doc "Invoked once when the group expires (or `:expire` is returned). Optional cleanup hook."
  @callback on_expire(Group.t()) :: :ok

  @doc """
  Invoked when `mover` steps onto a footprint cell (movement-pipeline hook).

  Optional - implemented by traps/portals (Land Mine, Warp Portal). Returns the
  updated group, or `:expire` to consume the unit after firing once.
  """
  @callback on_touch(Group.t(), mover :: {atom(), integer()}) :: trigger_result()

  @doc """
  Invoked when `mover` steps off a footprint cell (movement-pipeline hook).

  Optional. Returns the updated group, or `:expire` to end it.
  """
  @callback on_out(Group.t(), mover :: {atom(), integer()}) :: trigger_result()

  @doc "Describes the source-owned status granted while a mover occupies the field."
  @callback field_support(Group.t()) :: %{
              status_type: atom(),
              params: keyword() | map() | (atom(), integer() -> keyword() | map()),
              target?: ({atom(), integer()} -> boolean())
            }

  @optional_callbacks schedule: 2, on_expire: 1, on_touch: 2, on_out: 2, field_support: 1
end
