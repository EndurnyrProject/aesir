defmodule Aesir.ZoneServer.Mmo.Skill.Ground.Trigger do
  @moduledoc """
  Movement-pipeline hook that fires ground skill-unit `on_touch`/`on_out`
  callbacks.

  Invoked from the single `Aesir.ZoneServer.Unit.Movement.set_position/4`
  chokepoint after a unit's cell changes, so both player and mob movers
  trigger ground units (Warp Portal, Pneuma). Traps and Fire Pillar act only on
  the skill-unit timer, never on a step or an arrival. `on_enter_cell/4` fires
  `on_touch/2` for every group covering the new cell; `on_leave_cell/7` fires
  `on_out/2` for every group whose footprint covered the old cell but not the new
  one (i.e. the mover stepped off the footprint entirely — moving between cells of
  the same footprint does not count). `on_appear/4` places a unit that appears
  on a cell without stepping onto it (a mob spawn, a homunculus call). Spider
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

  @typedoc "The unit that entered the cell: `{unit_type, unit_id}`."
  @type mover :: {atom(), integer()}

  @never_on_move [:pf_spiderweb]

  # Ground units with an interval and no DualMode flag (Lullaby aside) act on
  # their own timer, never on a unit's arrival. Hunter traps carry trap state.
  @timer_units [:wz_firepillar, :hp_basilica, :ba_dissonance, :dc_uglydance]

  @doc """
  Fires `on_touch` for every ground unit whose footprint covers `(x, y)`.

  Returns `:ok`. When no ground unit covers the cell the lookup returns `[]`
  cheaply, so the common case is a no-op.
  """
  @spec on_enter_cell(mover(), String.t(), integer(), integer()) :: :ok
  def on_enter_cell(mover, map_name, x, y) do
    map_name
    |> Storage.get_groups_at_cell(x, y)
    |> Enum.reject(&(&1.skill_name in @never_on_move))
    |> Enum.each(&maybe_touch(&1, mover))
  end

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
  Fires `on_out` for every ground unit the mover stepped off.

  A group qualifies when its footprint covered `(old_x, old_y)` but does not cover
  the mover's new cell `(new_x, new_y)` on `new_map` - so moving between cells of
  the same footprint is not a leave. Returns `:ok`.
  """
  @spec on_leave_cell(mover(), String.t(), integer(), integer(), String.t(), integer(), integer()) ::
          :ok
  def on_leave_cell(mover, old_map, old_x, old_y, new_map, new_x, new_y) do
    old_map
    |> Storage.get_groups_at_cell(old_x, old_y)
    |> Enum.reject(&still_inside?(&1, new_map, new_x, new_y))
    |> Enum.each(&maybe_out(&1, mover))
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

  @spec still_inside?(Group.t(), String.t(), integer(), integer()) :: boolean()
  defp still_inside?(%Group{map_name: map_name, cells: cells}, new_map, new_x, new_y) do
    new_map == map_name and {new_x, new_y} in cells
  end

  @spec maybe_touch(Group.t(), mover()) :: :ok
  defp maybe_touch(group, mover), do: maybe_dispatch(group, mover, :on_touch)

  @spec maybe_out(Group.t(), mover()) :: :ok
  defp maybe_out(group, mover), do: maybe_dispatch(group, mover, :on_out)

  @spec maybe_dispatch(Group.t(), mover(), atom()) :: :ok
  defp maybe_dispatch(%Group{group_id: group_id}, mover, callback) do
    Manager.trigger(group_id, mover, callback)
  end
end
