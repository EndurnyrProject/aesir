defmodule Aesir.ZoneServer.Mmo.Skill.Ground.Trigger do
  @moduledoc """
  Movement-pipeline hook that fires ground skill-unit `on_touch`/`on_out`
  callbacks.

  Invoked from the single `Aesir.ZoneServer.Unit.Movement.set_position/4`
  chokepoint after a unit's cell changes, so both player and mob movers
  trigger ground units (Warp Portal, Pneuma). Traps and Fire Pillar act only on
  the skill-unit timer, never on a step or an arrival. `on_step/7` runs the
  whole step as one manager pass (`Manager.step/3`): the old cell's groups
  leave the mover, the new cell's groups place it (`on_touch/2`), and the
  fields the mover is no longer placed on end their statuses; `on_out/2` fires
  once per footprint the mover stepped off entirely (moving between cells of
  the same footprint does not count). `on_appear/4` places a unit that appears
  on a cell without stepping onto it (a mob spawn, a homunculus call);
  `on_removed/1` runs the leave events of every group on the cell of a unit
  removed from play (a warp, a logout, a despawn, a vaporize, a death). Spider
  Web never acts on a step or an arrival: it catches only the units standing on
  its cell when it is placed. All only invoke modules that export the matching
  callback, and apply its result:

    - `{:ok, updated_group}` - the updated group is persisted.
    - `:expire` - the group is torn down with the manager's normal cleanup.

  The callback itself decides hostility (owner/ally exclusion); this trigger only
  invokes it for every mover and applies the result.
  """

  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.Skill.Unit.TrapState
  alias Aesir.ZoneServer.Unit.SpatialIndex

  @typedoc "The unit that entered the cell: `{unit_type, unit_id}`."
  @type mover :: {atom(), integer()}

  # Spider Web and classic Basilica never act on a unit's step: an interval
  # unit without DualMode acts only on its own timer.
  @never_on_move [:pf_spiderweb, :hp_basilica]

  # Ground units with an interval and no DualMode flag (Lullaby aside) act on
  # their own timer, never on a unit's arrival. Hunter traps carry trap state.
  @timer_units [:wz_firepillar, :hp_basilica, :ba_dissonance, :dc_uglydance]

  @doc """
  Runs a step from `(old_x, old_y)` on `old_map` to `(new_x, new_y)` on
  `new_map` as one manager pass. Returns `:ok`; a step between two bare cells
  costs two cell lookups.
  """
  @spec on_step(mover(), String.t(), integer(), integer(), String.t(), integer(), integer()) ::
          :ok
  def on_step(mover, old_map, old_x, old_y, new_map, new_x, new_y),
    do: Manager.step(mover, {old_map, old_x, old_y}, {new_map, new_x, new_y})

  @doc "Whether a ground unit acts on a unit's step at all (Spider Web and classic Basilica never do)."
  @spec acts_on_step?(Group.t()) :: boolean()
  def acts_on_step?(%Group{skill_name: skill_name}), do: skill_name not in @never_on_move

  @doc """
  Fires `on_touch` for a unit appearing on `(x, y)` without stepping onto it.

  Only units that act on arrival qualify: traps and other interval units wait
  for their own timer, and Spider Web never acts on an arrival. Returns `:ok`.
  """
  @spec on_appear(mover(), String.t(), integer(), integer()) :: :ok
  def on_appear(mover, map_name, x, y) do
    map_name
    |> Storage.get_groups_at_cell(x, y)
    |> Enum.filter(&acts_on_arrival?/1)
    |> Enum.each(&maybe_touch(&1, mover))
  end

  @doc """
  Runs the leave events (`on_out`, then the field's `onleft`) of every ground
  unit covering the mover's cell when it is removed from play: a map removal
  (call it before the mover leaves the spatial index) or a death (the source's
  `skill_unit_move` flag 4, with no step bookkeeping). A unit without an
  indexed position runs nothing. Returns `:ok`.
  """
  @spec on_removed(mover()) :: :ok
  def on_removed({unit_type, unit_id} = mover) do
    case SpatialIndex.get_unit_position(unit_type, unit_id) do
      {:ok, {x, y, map_name}} ->
        map_name
        |> Storage.get_groups_at_cell(x, y)
        |> Enum.reject(&(&1.skill_name in @never_on_move))
        |> Enum.each(&maybe_dispatch(&1, mover, :on_removed))

      {:error, _not_placed} ->
        :ok
    end
  end

  @doc """
  Recenters every group anchored to the mover (a pre-renewal song or dance
  field) on the mover's cell `(x, y)` on `map_name`.

  Units without an anchored group cost one caster-index lookup. Returns `:ok`.
  """
  @spec on_caster_moved(mover(), String.t(), integer(), integer()) :: :ok
  def on_caster_moved({unit_type, unit_id}, map_name, x, y) do
    unit_type
    |> Storage.get_groups_by_caster(unit_id)
    |> Enum.filter(&Group.follows_caster?/1)
    |> Enum.each(&Manager.follow_caster(&1.group_id, map_name, {x, y}))
  end

  @spec acts_on_arrival?(Group.t()) :: boolean()
  defp acts_on_arrival?(%Group{state: %{trap: %TrapState{}}}), do: false

  defp acts_on_arrival?(%Group{skill_name: skill_name}),
    do: skill_name not in @never_on_move and skill_name not in @timer_units

  @spec maybe_touch(Group.t(), mover()) :: :ok
  defp maybe_touch(group, mover), do: maybe_dispatch(group, mover, :on_touch)

  @spec maybe_dispatch(Group.t(), mover(), atom()) :: :ok
  defp maybe_dispatch(%Group{group_id: group_id}, mover, callback) do
    Manager.trigger(group_id, mover, callback)
  end
end
