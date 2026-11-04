defmodule Aesir.ZoneServer.Mmo.Skill.Unit.GroupLifecycle do
  @moduledoc """
  The atomic mutations of a stored group: registering it with its cells,
  shrinking, moving, damaging and tearing it down, each keeping the primary
  row, the cell indexes, the field-support bookkeeping and the observers'
  view in step.

  Every function runs inside `Skill.Unit.Manager`.
  """

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Cell
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Cells
  alias Aesir.ZoneServer.Mmo.Skill.Unit.FieldSupport
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Handler
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Publisher
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.Skill.Unit.TrapCombat
  alias Aesir.ZoneServer.Mmo.Skill.Unit.TrapState
  alias Aesir.ZoneServer.Mmo.Skill.Unit.TrapTransition
  alias Aesir.ZoneServer.Unit.SpatialIndex

  @typedoc "The unit that damaged a cell, or `nil` for decay."
  @type damage_source :: {atom(), integer()} | nil

  @doc "Stores a group, materializing its cells when it is visible."
  @spec register(Group.t()) :: {:ok, Group.t()} | {:error, term()}
  def register(%Group{} = group) do
    if Group.materialized?(group),
      do: register_visible(group),
      else: register_invisible(group)
  end

  @doc "Stores a group without cells, replacing any group under the same id."
  @spec register_invisible(Group.t()) :: {:ok, Group.t()}
  def register_invisible(%Group{} = group) do
    :ok = remove_replaced(group.group_id)
    :ok = Storage.insert(group)
    {:ok, group}
  end

  defp register_visible(%Group{} = group) do
    :ok = remove_replaced(group.group_id)
    :ok = Storage.insert(group)

    case Cells.materialize_visible(group, []) do
      {:ok, _cells} ->
        {:ok, group}

      {:error, _reason} = error ->
        Cells.rollback_visible(group.group_id)
        error
    end
  end

  defp remove_replaced(group_id) do
    case Storage.get(group_id) do
      nil ->
        :ok

      group ->
        module = Handler.or_nil(group)
        FieldSupport.overlap_removed(group, group.cells)
        FieldSupport.out(group, group.cells, &run_out_callback(group, module, &1))
        cells = Storage.get_cells_by_group(group_id)
        Enum.each(cells, &Cells.remove_indexes/1)
        :ok = Storage.delete(group_id)

        Publisher.group_despawn(
          group,
          Enum.map(cells, & &1.cell_id),
          :SKILL_UNIT_DESPAWN_REASON_CANCELED
        )
    end
  end

  @doc "Tears a group down as expired, resolving its handler."
  @spec cleanup(Group.t()) :: :ok
  def cleanup(%Group{} = group),
    do: cleanup(group, Handler.or_nil(group), :SKILL_UNIT_DESPAWN_REASON_EXPIRED)

  @doc "Tears a group down as expired with a known handler."
  @spec cleanup(Group.t(), module() | nil) :: :ok
  def cleanup(%Group{} = group, module),
    do: cleanup(group, module, :SKILL_UNIT_DESPAWN_REASON_EXPIRED)

  @doc "Tears a group down for `despawn_reason`, resolving its handler."
  @spec cleanup_with_reason(Group.t(), atom()) :: :ok
  def cleanup_with_reason(%Group{} = group, despawn_reason),
    do: cleanup(group, Handler.or_nil(group), despawn_reason)

  @doc """
  Tears a group down: occupants leave every cell, the cell indexes go, the
  handler's `on_expire` runs, the row is deleted and the despawn published.
  """
  @spec cleanup(Group.t(), module() | nil, atom()) :: :ok
  def cleanup(%Group{group_id: group_id} = group, module, despawn_reason) do
    FieldSupport.overlap_removed(group, group.cells)
    FieldSupport.out(group, group.cells, &run_out_callback(group, module, &1))
    cells = Storage.get_cells_by_group(group_id)
    Enum.each(cells, &Cells.remove_indexes/1)

    if module && function_exported?(module, :on_expire, 1) do
      case Handler.invoke(module, :on_expire, [group]) do
        {:ok, :ok} -> :ok
        {:ok, result} -> Handler.log_error(group, :on_expire, {:invalid_return, result})
        {:error, reason} -> Handler.log_error(group, :on_expire, reason)
      end
    end

    Storage.delete(group_id)
    Publisher.group_despawn(group, Enum.map(cells, & &1.cell_id), despawn_reason)
  end

  @doc "Logs a failed callback and tears the group down."
  @spec callback_failed(Group.t(), atom(), term(), module() | nil) :: :ok
  def callback_failed(group, callback, reason, module) do
    Handler.log_error(group, callback, reason)
    cleanup(group, module)
  end

  @doc """
  Removes the given coordinates from a group: nothing when it owns none of
  them, a full teardown when they are all it has, a shrink otherwise.
  """
  @spec remove_cells(Group.t(), MapSet.t(Group.cell())) :: :ok
  def remove_cells(%Group{} = group, coordinates) do
    case Enum.split_with(group.cells, &MapSet.member?(coordinates, &1)) do
      {[], _survivors} -> :ok
      {_removed, []} -> cleanup_with_reason(group, :SKILL_UNIT_DESPAWN_REASON_DESTROYED)
      {removed, _survivors} -> shrink(group, removed)
    end
  end

  defp shrink(%Group{} = group, removed) do
    coordinates = MapSet.new(removed)
    module = Handler.or_nil(group)

    FieldSupport.overlap_removed(group, removed)
    FieldSupport.out(group, removed, &run_out_callback(group, module, &1))

    cells =
      group.group_id
      |> Storage.get_cells_by_group()
      |> Enum.filter(&MapSet.member?(coordinates, {&1.x, &1.y}))

    Enum.each(cells, &Cells.remove/1)

    Storage.remove_cells(group, removed)

    Publisher.cells_despawn(group, Enum.map(cells, & &1.cell_id))
  end

  @doc """
  A RangedSingleUnit field goes whole when its centre cell is removed and
  keeps every other cell. A centre cell that was never laid (a wall, Land
  Protector at placement) leaves the field unremovable this way.
  """
  @spec remove_ranged_single_unit(Group.t(), MapSet.t(Group.cell())) :: :ok
  def remove_ranged_single_unit(%Group{} = group, area) do
    if centre_unit_in?(group, area),
      do: cleanup_with_reason(group, :SKILL_UNIT_DESPAWN_REASON_DESTROYED),
      else: :ok
  end

  @doc "Whether the group's centre lies in `area` and is one of its laid cells."
  @spec centre_unit_in?(Group.t(), MapSet.t(Group.cell())) :: boolean()
  def centre_unit_in?(%Group{center: center, cells: cells}, area),
    do: MapSet.member?(area, center) and center in cells

  @doc "Whether the group's skill is a RangedSingleUnit field."
  @spec ranged_single_unit?(Group.t()) :: boolean()
  def ranged_single_unit?(%Group{skill_id: skill_id}) do
    case Catalog.by_id(skill_id) do
      {:ok, definition} -> definition.ranged_single_unit
      :error -> false
    end
  end

  @doc """
  Shifts every cell by the displacement to `center`, keeping cell IDs. Each
  cell's terrain and target indexes follow it; occupants of vacated cells
  leave the field and occupants of newly covered cells are placed on it. A
  cell crossing into another map block becomes that block's newest unit.
  """
  @spec move(Group.t(), Group.cell()) :: :ok
  def move(%Group{center: {cx, cy}} = group, {x, y} = center) do
    shift = fn {cell_x, cell_y} -> {cell_x + x - cx, cell_y + y - cy} end

    moved = %{
      group
      | center: center,
        origin: center,
        cells: Enum.map(group.cells, shift),
        cell_entries: Map.new(group.cells, &moved_entry(group, &1, shift.(&1)))
    }

    vacated = group.cells -- moved.cells
    module = Handler.or_nil(group)

    FieldSupport.overlap_removed(group, vacated)
    FieldSupport.out(group, vacated, &run_out_callback(group, module, &1))
    :ok = Storage.update(moved)
    group.group_id |> Storage.get_cells_by_group() |> Enum.each(&move_cell(&1, shift))
    FieldSupport.place(moved, moved.cells -- group.cells)
    Publisher.move(moved)
  end

  defp moved_entry(group, {old_x, old_y} = old, {new_x, new_y} = new) do
    if SpatialIndex.block(old_x, old_y) == SpatialIndex.block(new_x, new_y),
      do: {new, Group.block_entry(group, old)},
      else: {new, System.unique_integer([:monotonic, :positive])}
  end

  defp move_cell(%Cell{} = cell, shift) do
    :ok = Cells.remove_indexes(cell)
    {x, y} = shift.({cell.x, cell.y})
    moved = %{cell | x: x, y: y}
    :ok = Storage.update_cell(moved)
    :ok = Cells.commit_terrain(moved)
    :ok = Cells.register_target(moved)
  end

  @doc """
  Applies `amount` damage to a cell. A destroyed cell is removed and, when it
  was the group's last, the group is torn down at once.
  """
  @spec damage_cell(non_neg_integer(), term(), term(), :damage | :decay) ::
          {:ok, Cell.t()} | {:destroyed, Cell.t()} | {:error, term()}
  def damage_cell(_cell_id, amount, _source, _reason)
      when not is_integer(amount) or amount <= 0,
      do: {:error, :invalid_damage}

  def damage_cell(cell_id, amount, nil, reason),
    do: damage_valid_cell(cell_id, amount, nil, reason)

  def damage_cell(cell_id, amount, {source_type, source_id} = source, reason)
      when source_type in [:player, :mob, :homunculus, :npc] and is_integer(source_id) and
             source_id >= 0 do
    damage_valid_cell(cell_id, amount, source, reason)
  end

  def damage_cell(_cell_id, _amount, _source, _reason), do: {:error, :invalid_source}

  defp damage_valid_cell(cell_id, amount, source, reason) do
    case Storage.get_cell(cell_id) do
      nil ->
        {:error, :not_found}

      %Cell{state: %{trap_target: true}} = cell ->
        damage_trap_cell(cell, amount, source, reason)

      %Cell{max_hp: 0} ->
        {:error, :not_destructible}

      %Cell{hp: hp} = cell when amount < hp ->
        updated = %{cell | hp: hp - amount}
        :ok = Storage.update_cell(updated)
        Publisher.cell_update(updated, -amount, source, reason)
        {:ok, updated}

      %Cell{hp: hp} = cell ->
        updated = %{cell | hp: 0}
        :ok = Cells.remove(cell)
        Publisher.cell_update(updated, -hp, source, reason)
        Publisher.cell_despawn(cell, :SKILL_UNIT_DESPAWN_REASON_DESTROYED)
        expire_if_empty(cell.group_id)
        {:destroyed, cell}
    end
  end

  defp damage_trap_cell(cell, amount, source, reason) do
    case TrapCombat.damage_mode(cell) do
      :ignore ->
        {:ok, cell}

      :durability ->
        updated = %{cell | hp: max(cell.hp - amount, 0)}
        :ok = Storage.update_cell(updated)
        Publisher.cell_update(updated, -min(amount, cell.hp), source, reason)
        {:ok, updated}
    end
  end

  # Destroying a group's last cell must expire the group immediately, matching
  # the structural-removal path (`remove_cells/2`); otherwise the empty group
  # lingers until the next interval tick reaps it.
  defp expire_if_empty(group_id) do
    with [] <- Storage.get_cells_by_group(group_id),
         %Group{} = group <- Storage.get(group_id) do
      cleanup_with_reason(group, :SKILL_UNIT_DESPAWN_REASON_DESTROYED)
    else
      _ -> :ok
    end
  end

  @doc "Runs the handler's `on_out` for a mover leaving the footprint, persisting its result."
  @spec run_out_callback(Group.t(), module() | nil, {atom(), integer()}) :: :ok
  def run_out_callback(%Group{} = group, module, mover) do
    if module && function_exported?(module, :on_out, 2),
      do: apply_out_result(group, Handler.invoke(module, :on_out, [group, mover]))

    :ok
  end

  defp apply_out_result(group, {:ok, {:ok, %Group{group_id: group_id} = updated}})
       when group_id == group.group_id do
    if Storage.get(group_id), do: persist_callback_update(group, updated)
    :ok
  end

  defp apply_out_result(_group, {:ok, _result}), do: :ok
  defp apply_out_result(group, {:error, reason}), do: Handler.log_error(group, :on_out, reason)

  @doc """
  Persists a group a callback updated: through the trap transition when both
  are traps, as a plain update when neither is, refused when they disagree.
  """
  @spec persist_callback_update(Group.t(), Group.t()) :: :ok | {:error, term()}
  def persist_callback_update(%Group{} = original, %Group{} = updated) do
    case {TrapTransition.from_group(original), TrapTransition.from_group(updated)} do
      {{:ok, %TrapState{}}, {:ok, %TrapState{}}} -> TrapTransition.persist(original, updated)
      {{:error, :unsupported_trap}, {:error, :unsupported_trap}} -> Storage.update(updated)
      _invalid -> {:error, :invalid_trap_state}
    end
  end

  @doc "Stores an interval result and then removes `cells` from the live group."
  @spec update_and_drop_cells(Group.t(), [Group.cell()], integer(), module() | nil) :: :ok
  def update_and_drop_cells(%Group{group_id: group_id} = updated, cells, now, module) do
    update_after_interval(updated, now, module)
    if live = Storage.get(group_id), do: remove_cells(live, MapSet.new(cells))
    :ok
  end

  @doc """
  Stores an interval result: the next tick is scheduled, decaying cells take
  their decay, a materialized group left without cells is torn down, and a
  portal that opened or closed is republished.
  """
  @spec update_after_interval(Group.t(), integer(), module() | nil) :: :ok
  def update_after_interval(%Group{} = updated, now, module) do
    updated = %{updated | next_tick_at: now + updated.interval}
    decay_cells(updated)

    case Storage.get(updated.group_id) do
      nil ->
        :ok

      %Group{} = live ->
        if Group.materialized?(updated) and Storage.get_cells_by_group(live.group_id) == [] do
          cleanup(live, module, :SKILL_UNIT_DESPAWN_REASON_DESTROYED)
        else
          Storage.update(updated)

          publish_opening_transition(live, updated)
        end
    end
  end

  defp publish_opening_transition(live, updated) do
    if Map.get(updated.state, :portal, false) and
         Map.get(live.state, :opened, false) != Map.get(updated.state, :opened, false) do
      Publisher.group_replacement(updated, Storage.get_cells_by_group(updated.group_id))
    end
  end

  defp decay_cells(%Group{state: %{cell_decay: amount}} = group)
       when is_integer(amount) and amount > 0 do
    group.group_id
    |> Storage.get_cells_by_group()
    |> Enum.each(&damage_cell(&1.cell_id, amount, nil, :decay))
  end

  defp decay_cells(_group), do: :ok
end
