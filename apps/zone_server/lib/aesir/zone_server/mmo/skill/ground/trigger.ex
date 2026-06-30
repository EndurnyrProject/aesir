defmodule Aesir.ZoneServer.Mmo.Skill.Ground.Trigger do
  @moduledoc """
  Movement-pipeline hook that fires ground skill-unit `on_touch`/`on_out`
  callbacks.

  Invoked from the single `Aesir.ZoneServer.Unit.Movement.set_position/4`
  chokepoint after a unit's position changes, so both player and mob movers
  trigger ground units (traps, Warp Portal, Pneuma). `on_enter_cell/4` fires
  `on_touch/2` for every group covering the new cell; `on_leave_cell/7` fires
  `on_out/2` for every group whose footprint covered the old cell but not the new
  one (i.e. the mover stepped off the footprint entirely — moving between cells of
  the same footprint does not count). Both only invoke modules that export the
  matching callback, and apply its result:

    - `{:ok, updated_group}` - the updated group is persisted.
    - `:expire` - the group is torn down with the same teardown the central tick
      manager uses for expiry (`on_expire` cleanup hook, then delete).

  The callback itself decides hostility (owner/ally exclusion); this trigger only
  invokes it for every mover and applies the result.
  """

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage

  @typedoc "The unit that entered the cell: `{unit_type, unit_id}`."
  @type mover :: {atom(), integer()}

  @doc """
  Fires `on_touch` for every ground unit whose footprint covers `(x, y)`.

  Returns `:ok`. When no ground unit covers the cell the lookup returns `[]`
  cheaply, so the common case is a no-op.
  """
  @spec on_enter_cell(mover(), String.t(), integer(), integer()) :: :ok
  def on_enter_cell(mover, map_name, x, y) do
    map_name
    |> Storage.get_groups_at_cell(x, y)
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

  @spec still_inside?(Group.t(), String.t(), integer(), integer()) :: boolean()
  defp still_inside?(%Group{map_name: map_name, cells: cells}, new_map, new_x, new_y) do
    new_map == map_name and {new_x, new_y} in cells
  end

  @spec maybe_touch(Group.t(), mover()) :: :ok
  defp maybe_touch(group, mover), do: maybe_dispatch(group, mover, :on_touch)

  @spec maybe_out(Group.t(), mover()) :: :ok
  defp maybe_out(group, mover), do: maybe_dispatch(group, mover, :on_out)

  @spec maybe_dispatch(Group.t(), mover(), atom()) :: :ok
  defp maybe_dispatch(%Group{skill_name: skill_name} = group, mover, callback) do
    with {:ok, module} <- Catalog.ground_module_for(skill_name),
         true <- function_exported?(module, callback, 2) do
      apply_result(apply(module, callback, [group, mover]), module, group)
    else
      _ -> :ok
    end
  end

  @spec apply_result({:ok, Group.t()} | :expire, module(), Group.t()) :: :ok
  defp apply_result({:ok, %Group{} = updated}, _module, _group), do: Storage.update(updated)
  defp apply_result(:expire, module, group), do: expire(module, group)

  # Mirrors the tick manager's expiry teardown: run the cleanup hook, then delete.
  @spec expire(module(), Group.t()) :: :ok
  defp expire(module, %Group{group_id: group_id} = group) do
    module.on_expire(group)
    Storage.delete(group_id)
  end
end
