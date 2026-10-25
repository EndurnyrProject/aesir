defmodule Aesir.ZoneServer.Mmo.Skill.Ground do
  @moduledoc """
  Capability behaviour for skills that place a persistent ground skill-unit
  (rAthena `skill_unit_group`).

  A skill opts in by declaring `@behaviour Skill.Ground` and implementing
  `on_place/1` and `on_interval/2`. The framework (storage, central tick,
  placement) stays skill-agnostic and dispatches through `Skill.Catalog`. Because
  these skills are `target_type: :ground`, `use Skill` auto-derives the active
  `cast/4` that places the unit, so the skill needs no separate cast module.

  `schedule/2`, `on_natural_expiry/1`, and `on_expire/1` are optional. The
  manager invokes `schedule/2` once, while serializing registration, when a
  skill needs a manager-owned randomized schedule. `on_natural_expiry/1` runs
  synchronously inside `Skill.Unit.Manager` only for an armed trap whose typed
  natural-expiry policy is `:become_used`, immediately before the manager
  persists its used phase. Implementations must never call Manager APIs: doing
  so self-calls the Manager process and deadlocks.

  `on_touch/2` and `on_out/2` are optional movement-pipeline hooks fired when a
  unit steps onto / off a footprint cell (Warp Portal, Fire Wall); the
  movement chokepoint invokes them only when the skill module exports them.

  ## Documented extension points (not part of this contract yet)

  This belongs to a later layer and is intentionally NOT declared as a callback
  (YAGNI):

    - cell-flag set/clear hooks (`walkable?` / block) - Safety Wall, Ice Wall,
      Pneuma, Land Protector.
  """

  alias Aesir.ZoneServer.Mmo.Skill.Unit.FieldSupport
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.LifecyclePolicy
  alias Aesir.ZoneServer.Unit.Ref

  @typedoc "A single map cell occupied by a skill-unit footprint."
  @type cell :: {integer(), integer()}

  @typedoc """
  An action a unit strike asks the manager to run at once, without invoking
  any group's own strike callbacks: Claymore Trap's spend command marks the
  armed traps in its blast area used, so detonations never recurse;
  `:remove_cells` deletes cells of the striking group itself (a Fire Wall cell
  whose hit budget ran out), running `on_out` for their occupants and ending
  the group with its last cell. `{:after_cell, command}` runs the command only
  once the striking cell has struck every unit it reaches this pass (a Grand
  Cross cell out of charges is deleted after its pass).
  """
  @type command ::
          {:spend_traps, String.t(), cell(), non_neg_integer()}
          | {:remove_cells, non_neg_integer(), [cell()]}
          | {:after_cell, command()}

  @typedoc "A movement callback result serialized and persisted by the skill-unit manager."
  @type trigger_result :: {:ok, Group.t()} | :expire

  @typedoc "The placement result: footprint, initial per-skill state, timing, and optional lifecycle policy."
  @type placement :: %{
          optional(:unit_range) => non_neg_integer(),
          optional(:no_overlap) => boolean(),
          optional(:lifecycle_policy) => LifecyclePolicy.t(),
          optional(:initial_delay) => non_neg_integer(),
          optional(:cell_attrs) => %{cell() => map()},
          optional(:path_check) => boolean(),
          optional(:visibility) => Group.visibility(),
          optional(:announce) => boolean(),
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
  Returning `{:expire, group}` ends the group early; `{:ok, group, {:remove_cells,
  cells}}` also drops those cells (each cell's leavers are released, and the
  group ends with its last cell).
  """
  @callback on_interval(Group.t(), now :: integer()) ::
              {:ok, Group.t()}
              | {:ok, Group.t(), {:remove_cells, [cell()]}}
              | {:expire, Group.t()}

  @doc "Builds manager-owned schedule state with the injected zero-based RNG. Optional."
  @callback schedule(Group.t(), rng :: (pos_integer() -> non_neg_integer())) :: {:ok, Group.t()}

  @doc "Runs an armed `:become_used` trap's optional natural-timeout effect before transition."
  @callback on_natural_expiry(Group.t()) :: :ok | {:error, term()}

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

  @doc """
  Keeps the units one footprint cell of a `unit_range` field may affect, in
  order, from those it reaches whose strike interval has run out.

  Required for a placement with `unit_range`. Return `[]` when the field acts
  on nobody (its caster is gone).
  """
  @callback unit_targets(Group.t(), cell(), [Ref.t()]) :: [Ref.t()]

  @doc """
  Strikes one unit from one footprint cell of a `unit_range` field.

  Required for a placement with `unit_range`. `{:expire, group}` ends the field
  after this cell's remaining strikes. A third element lists `command()`s the
  manager runs at once on other groups.
  """
  @callback on_unit_hit(Group.t(), cell(), Ref.t(), now :: integer()) ::
              {:ok, Group.t()}
              | {:expire, Group.t()}
              | {:ok | :expire, Group.t(), [command()]}

  @doc """
  The skill one footprint cell strikes as this pass: its skill id, strike
  interval and NoOverlap, which key the units' strike intervals and are what
  `unit_targets/3` and `on_unit_hit/4` see for that cell; `:none` when the cell
  does nothing this pass. Optional; without it every cell strikes as the group.
  """
  @callback cell_profile(Group.t(), cell()) ::
              %{skill_id: pos_integer(), interval: pos_integer(), no_overlap: boolean()} | :none

  @doc "Describes the source-owned status granted while a mover occupies the field."
  @callback field_support(Group.t()) :: FieldSupport.spec()

  @optional_callbacks schedule: 2,
                      on_natural_expiry: 1,
                      on_expire: 1,
                      on_touch: 2,
                      on_out: 2,
                      field_support: 1,
                      unit_targets: 3,
                      cell_profile: 2,
                      on_unit_hit: 4
end
