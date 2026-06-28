defmodule Aesir.ZoneServer.Mmo.Skill.Ground.Trigger do
  @moduledoc """
  Movement-pipeline hook that fires ground skill-unit `on_touch` callbacks.

  Invoked from the single `Aesir.ZoneServer.Unit.Movement.set_position/4`
  chokepoint after a unit's position changes, so both player and mob movers
  trigger ground units (traps, Warp Portal). For every group whose footprint
  covers the new cell and whose skill module exports `on_touch/2`, the callback
  is invoked with the mover and its result applied:

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

  @spec maybe_touch(Group.t(), mover()) :: :ok
  defp maybe_touch(%Group{skill_name: skill_name} = group, mover) do
    with {:ok, module} <- Catalog.ground_module_for(skill_name),
         true <- function_exported?(module, :on_touch, 2) do
      apply_touch(module, group, mover)
    else
      _ -> :ok
    end
  end

  @spec apply_touch(module(), Group.t(), mover()) :: :ok
  defp apply_touch(module, group, mover) do
    case module.on_touch(group, mover) do
      {:ok, %Group{} = updated} -> Storage.update(updated)
      :expire -> expire(module, group)
    end
  end

  # Mirrors the tick manager's expiry teardown: run the cleanup hook, then delete.
  @spec expire(module(), Group.t()) :: :ok
  defp expire(module, %Group{group_id: group_id} = group) do
    module.on_expire(group)
    Storage.delete(group_id)
  end
end
