defmodule Aesir.ZoneServer.Mmo.Skill.Ground do
  @moduledoc """
  Capability behaviour for skills that place a persistent ground skill-unit
  (rAthena `skill_unit_group`).

  A skill opts in by declaring `@behaviour Skill.Ground` and implementing
  `on_place/1` and `on_interval/2`. The framework (storage, central tick,
  placement) stays skill-agnostic and dispatches through `Skill.Catalog`. Because
  these skills are `target_type: :ground`, `use Skill` auto-derives the active
  `cast/4` that places the unit, so the skill needs no separate cast module.

  `on_expire/1` is optional - the tick manager invokes it only when defined.

  ## Documented extension points (not part of this contract yet)

  These belong to later layers and are intentionally NOT declared as callbacks
  (YAGNI):

    - `on_touch` / `on_out` - fired when a unit steps onto/off a footprint cell
      (movement-pipeline hook: traps, Warp Portal, Fire Wall).
    - cell-flag set/clear hooks (`walkable?` / block) - Safety Wall, Ice Wall,
      Pneuma, Land Protector.
  """

  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group

  @typedoc "A single map cell occupied by a skill-unit footprint."
  @type cell :: {integer(), integer()}

  @typedoc "The placement result: footprint, initial per-skill state, and timing."
  @type placement :: %{
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

  @doc "Invoked once when the group expires (or `:expire` is returned). Optional cleanup hook."
  @callback on_expire(Group.t()) :: :ok

  @optional_callbacks on_expire: 1
end
