defmodule Aesir.ZoneServer.Unit.Mob.Handlers.MovementHandler do
  @moduledoc """
  Handles mob movement: pathfinding kickoff, per-tick stepping, blocked-path
  repathing, and the instant teleport reposition. Extracted from MobSession to
  improve modularity and maintainability.
  """

  alias Aesir.Net.Knockback
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Mmo.Woe.Rules
  alias Aesir.ZoneServer.Pathfinding
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.HitStop
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Movement
  alias Aesir.ZoneServer.Unit.MovementEngine
  alias Aesir.ZoneServer.Unit.SpatialIndex

  @doc """
  Forces the mob to path toward `{x, y}`. A mob already walking keeps its
  pending step and takes the new path from the cell that step lands on.
  """
  @spec handle_move_to(MobState.t(), integer(), integer()) :: {:noreply, MobState.t()}
  def handle_move_to(state, x, y), do: handle_move_to(state, x, y, false)

  @doc """
  Like `handle_move_to/3`. An escape request (`escape?`) makes the mob
  unstoppable by damage whether or not it starts a walk, until a walk ends.
  """
  @spec handle_move_to(MobState.t(), integer(), integer(), boolean()) ::
          {:noreply, MobState.t()}
  def handle_move_to(state, x, y, escape?) do
    state = if escape?, do: %{state | can_escape: true}, else: state

    walking? = state.movement_state == :moving

    with {:ok, map_data} <- MapCache.get(state.map_name),
         {:ok, path} when path != [] or walking? <-
           Pathfinding.find_path(map_data, {state.x, state.y}, {x, y}, profile: :mob) do
      if walking?,
        do: {:noreply, %{state | walk_target: {x, y}}},
        else: {:noreply, start_walk(state, path)}
    else
      # Already at destination, no path found or map not loaded.
      _ -> {:noreply, state}
    end
  end

  @doc """
  Takes the walk step whose timer is `timer`, or drops it when it is not the
  mob's recorded pending step: the walk it belonged to was stopped.
  """
  @spec handle_step(reference(), MobState.t()) :: {:noreply, MobState.t()}
  def handle_step(timer, %MobState{} = state) do
    if HitStop.current?(state.pending_step, timer),
      do: handle_movement_tick(state),
      else: {:noreply, state}
  end

  # The first tick fires after the first step's cost: a unit enters a cell when
  # the step completes, keeping the server position in lockstep with the
  # clients' interpolation instead of one cell ahead.
  defp start_walk(state, path) do
    state
    |> MobState.set_path(path)
    |> schedule_step(MovementEngine.step_delay(state.walk_speed, {state.x, state.y}, hd(path)))
  end

  @doc """
  Processes a `{:movement, :tick}` for a live mob: steps it along its path,
  repaths around a newly blocked cell, or drops the tick if the mob is dead.
  """
  @spec handle_movement_tick(MobState.t()) :: {:noreply, MobState.t()}
  def handle_movement_tick(state) do
    if state.is_dead do
      # Dead mobs don't move
      {:noreply, state}
    else
      # Process movement if mob is moving
      updated_state = process_movement_tick(state)
      {:noreply, updated_state}
    end
  end

  @doc """
  Instantly relocates the mob to a random walkable cell on its map and drops
  its current target (`AL_TELEPORT` flee). The move is a warp
  (`Movement.warp_position/4`): the mob leaves the ground units of its old cell
  and appears on the new one. A no-op if no walkable cell is found.
  """
  @spec handle_teleport(MobState.t()) :: {:noreply, MobState.t()}
  def handle_teleport(state) do
    case Cell.random_traversable(state.map_name) do
      {:ok, {x, y}} ->
        updated_state =
          state
          |> MobState.advance_deferred_epoch()
          |> MobState.update_position(x, y)
          |> MobState.stop_movement()
          |> MobState.leave_map()

        SpatialIndex.reenter_block(:mob, updated_state.instance_id)

        Movement.warp_position(
          :mob,
          updated_state.instance_id,
          updated_state,
          updated_state.map_name
        )

        {:noreply, updated_state}

      {:error, _reason} ->
        {:noreply, state}
    end
  end

  @doc """
  Stops a walking mob that a damaging hit stopped (`HitStop`): it finishes the
  step it is taking when at most half of it is left, else it stays on its cell.
  The caller has already ruled out endure and an escape walk.
  """
  @spec handle_hit_stop(MobState.t()) :: MobState.t()
  def handle_hit_stop(%MobState{movement_state: :moving} = state) do
    HitStop.cancel(state.pending_step)
    state = %{state | walk_target: nil}

    with {:finish_step, [next | _rest]} <-
           {HitStop.plan(state.pending_step, HitStop.now()), state.walk_path},
         true <-
           Cell.step_traversable?(state.map_name, {state.x, state.y}, next, profile: :mob) do
      step_mob(state, next, [])
    else
      _stay ->
        stopped_state = MobState.stop_movement(state)
        Movement.set_position(:mob, stopped_state.instance_id, stopped_state, state.map_name)
        stopped_state
    end
  end

  def handle_hit_stop(%MobState{} = state), do: state

  @doc "Rejects offensive knockback on current castle ground before displacement commit."
  @spec handle_knockback(
          integer(),
          integer(),
          String.t(),
          integer(),
          integer(),
          MobState.t()
        ) :: {:noreply, MobState.t()}
  def handle_knockback(expected_x, expected_y, map_name, x, y, %MobState{} = state) do
    if Rules.ground?(state.map_name) do
      {:noreply, state}
    else
      handle_displacement(state, expected_x, expected_y, map_name, x, y)
    end
  end

  @doc """
  Commits displacement only when the live session still matches its expected cell.
  """
  @spec handle_displacement(
          MobState.t(),
          integer(),
          integer(),
          String.t(),
          integer(),
          integer()
        ) :: {:noreply, MobState.t()}
  def handle_displacement(state, expected_x, expected_y, map_name, x, y),
    do: handle_relocation(state, expected_x, expected_y, map_name, x, y)

  @doc """
  Warps the mob to `(x, y)` on `map_name`, including a boss: a living mob lands
  there when the cell is walkable, leaving the ground units of its old cell
  and appearing on the new one (`Movement.warp_position/4`).
  """
  @spec handle_warp(MobState.t(), String.t(), integer(), integer()) :: {:noreply, MobState.t()}
  def handle_warp(state, map_name, x, y) do
    if Unit.living?(state) and map_name == state.map_name and Cell.traversable?(map_name, x, y) do
      state =
        state
        |> MobState.stop_movement()
        |> MobState.leave_map()
        |> MobState.update_position(x, y)

      Movement.warp_position(:mob, state.instance_id, state, map_name)

      packet = %Knockback{unit_id: state.instance_id, dst_x: x, dst_y: y}
      Broadcast.to_in_range(map_name, x, y, Config.view_range(), packet)
      {:noreply, state}
    else
      {:noreply, state}
    end
  end

  @doc """
  Commits an authoritative self-relocation, including for boss mobs.
  """
  @spec handle_relocation(
          MobState.t(),
          integer(),
          integer(),
          String.t(),
          integer(),
          integer()
        ) :: {:noreply, MobState.t()}
  def handle_relocation(state, expected_x, expected_y, map_name, x, y) do
    if Unit.living?(state) and
         {state.x, state.y, state.map_name} == {expected_x, expected_y, map_name} and
         Cell.traversable?(map_name, x, y) do
      state =
        state
        |> MobState.stop_movement()
        |> MobState.update_position(x, y)

      Movement.set_position(:mob, state.instance_id, state, map_name)

      packet = %Knockback{unit_id: state.instance_id, dst_x: x, dst_y: y}
      Broadcast.to_in_range(map_name, x, y, Config.view_range(), packet)
      {:noreply, state}
    else
      {:noreply, state}
    end
  end

  defp process_movement_tick(%{} = state) do
    if MobState.walk_delayed?(state, System.monotonic_time(:millisecond)) do
      MobState.stop_movement(state)
    else
      process_unblocked_movement_tick(state)
    end
  end

  defp process_unblocked_movement_tick(%{movement_state: :standing} = state) do
    state
  end

  defp process_unblocked_movement_tick(%{movement_state: :moving, walk_path: []} = state) do
    MobState.stop_movement(state)
  end

  defp process_unblocked_movement_tick(%{movement_state: :moving} = state) do
    case state.walk_path do
      [{next_x, next_y} | _] = walk_path ->
        if Cell.step_traversable?(state.map_name, {state.x, state.y}, {next_x, next_y},
             profile: :mob
           ) do
          step_mob(state, {next_x, next_y}, tl(walk_path))
        else
          handle_blocked_mob(
            %{state | walk_target: nil},
            state.walk_target || List.last(walk_path)
          )
        end
    end
  end

  defp step_mob(state, {next_x, next_y}, remaining_path) do
    # Facing toward the cell we are stepping into.
    dir = Geometry.calculate_direction(state.x, state.y, next_x, next_y)

    # Update mob state FIRST to maintain consistency
    updated_state =
      state
      |> MobState.update_position(next_x, next_y)
      |> MobState.update_direction(dir)
      |> Map.put(:walk_path, remaining_path)

    # Route through the single choke point so the spatial index + registry
    # are synced and the unit is marked dirty for the per-map broadcaster.
    Movement.set_position(
      :mob,
      updated_state.instance_id,
      updated_state,
      updated_state.map_name
    )

    cond do
      updated_state.walk_target != nil ->
        redirect_walk(updated_state)

      # Schedule the next tick priced by the step it will take, so entering
      # each cell lines up with the clients' per-cell interpolation.
      remaining_path != [] ->
        interval =
          MovementEngine.step_delay(state.walk_speed, {next_x, next_y}, hd(remaining_path))

        schedule_step(updated_state, interval)

      true ->
        finish_walk(updated_state)
    end
  end

  # Path completed: stop and broadcast the standing transition so the client's
  # last snapshot sample flips move_state back to idle. An escape walk ends here.
  defp finish_walk(state) do
    stopped_state = %{MobState.stop_movement(state) | can_escape: false}
    Movement.set_position(:mob, stopped_state.instance_id, stopped_state, stopped_state.map_name)
    stopped_state
  end

  # A move request made while walking takes effect on the cell the step just
  # landed on: the new path starts there, and a target that cannot be reached
  # from it stops the walk.
  defp redirect_walk(state) do
    destination = state.walk_target
    state = %{state | walk_target: nil}

    with {:ok, map_data} <- MapCache.get(state.map_name),
         {:ok, path} <-
           Pathfinding.find_path(map_data, {state.x, state.y}, destination, profile: :mob) do
      case path do
        [] -> finish_walk(state)
        _ -> start_walk(state, path)
      end
    else
      _ ->
        stopped_state = MobState.stop_movement(state)
        Movement.set_position(:mob, stopped_state.instance_id, stopped_state, state.map_name)
        stopped_state
    end
  end

  defp schedule_step(state, delay),
    do: %{state | pending_step: HitStop.schedule({:movement, :tick}, delay)}

  defp handle_blocked_mob(state, destination) do
    with {:ok, map_data} <- MapCache.get(state.map_name),
         {:ok, [_ | _] = path} <-
           Pathfinding.find_path(map_data, {state.x, state.y}, destination, profile: :mob) do
      start_walk(state, path)
    else
      _ ->
        stopped_state = MobState.stop_movement(state)

        Movement.set_position(
          :mob,
          stopped_state.instance_id,
          stopped_state,
          stopped_state.map_name
        )

        stopped_state
    end
  end
end
