defmodule Aesir.ZoneServer.Mmo.SkillUnit.Behaviour do
  @moduledoc """
  Behaviour for ground skill-unit implementations (analogue of
  `StatusEffect.Definition`).

  Each ground skill provides a module implementing this behaviour; the framework
  (storage, central tick, placement) stays skill-agnostic and dispatches through
  the `SkillUnit.Behaviors` registry.

  `use SkillUnit.Behaviour` supplies a no-op `on_expire/1` and a trivial
  `on_place/1` (a single cell at the group's `center`), so simple skills override
  only what they need. Both are overridable.

  ## Documented extension points (not part of this contract yet)

  These belong to later layers and are intentionally NOT declared as callbacks
  (YAGNI):

    - `on_touch` / `on_out` — fired when a unit steps onto/off a footprint cell
      (layer 2, movement-pipeline hook: traps, Warp Portal, Fire Wall).
    - cell-flag set/clear hooks (`walkable?` / block) — layer 3 (Safety Wall,
      Ice Wall, Pneuma, Land Protector).
  """

  alias Aesir.ZoneServer.Mmo.SkillUnit.Group

  @typedoc "A single map cell occupied by a skill-unit footprint."
  @type cell :: {integer(), integer()}

  @typedoc "The placement result: footprint, initial per-skill state, and timing."
  @type placement :: %{
          cells: [cell()],
          state: map(),
          interval: pos_integer(),
          duration: pos_integer()
        }

  @doc "Returns the skill identifier atom this unit behaviour handles."
  @callback skill_name() :: atom()

  @doc "Invoked once at placement. Returns footprint, initial state, and timing."
  @callback on_place(Group.t()) :: {:ok, placement()}

  @doc """
  Invoked every `interval` ms while the group is alive.

  Runs the effect against units in the footprint and returns the updated group.
  Returning `{:expire, group}` ends the group early.
  """
  @callback on_interval(Group.t(), now :: integer()) ::
              {:ok, Group.t()} | {:expire, Group.t()}

  @doc "Invoked once when the group expires (or `:expire` is returned). Cleanup hook."
  @callback on_expire(Group.t()) :: :ok

  defmacro __using__(_opts) do
    quote do
      @behaviour Aesir.ZoneServer.Mmo.SkillUnit.Behaviour

      @impl true
      def on_place(%Aesir.ZoneServer.Mmo.SkillUnit.Group{center: center}) do
        {:ok, %{cells: [center], state: %{}, interval: 1_000, duration: 1_000}}
      end

      @impl true
      def on_expire(_group), do: :ok

      defoverridable on_place: 1, on_expire: 1
    end
  end
end
