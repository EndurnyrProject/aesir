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
  alias Aesir.ZoneServer.Pathfinding
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Movement
  alias Aesir.ZoneServer.Unit.MovementEngine

  @doc """
  Forces the mob to path toward `{x, y}`, or drops the request if the mob is
  already moving.
  """
  @spec handle_move_to(MobState.t(), integer(), integer()) :: {:noreply, MobState.t()}
  def handle_move_to(state, x, y) do
    if state.movement_state == :moving do
      {:noreply, state}
    else
      with {:ok, map_data} <- MapCache.get(state.map_name),
           {:ok, [_ | _] = path} <-
             Pathfinding.find_path(
               map_data,
               {state.x, state.y},
               {x, y},
               profile: :mob
             ) do
        updated_state = MobState.set_path(state, path)

        # The first tick fires after the first step's cost: a unit enters a
        # cell when the step completes, keeping the server position in
        # lockstep with the clients' interpolation instead of one cell ahead.
        first_delay = MovementEngine.step_delay(state.walk_speed, {state.x, state.y}, hd(path))
        Process.send_after(self(), {:movement, :tick}, first_delay)

        {:noreply, updated_state}
      else
        {:ok, []} ->
          # Already at destination
          {:noreply, state}

        {:error, _reason} ->
          # No path found or map not loaded
          {:noreply, state}
      end
    end
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
  its current target (`AL_TELEPORT` flee). Reuses the `{:movement,
  {:knocked_back, x, y}}` instant position-set path; a no-op if no walkable
  cell is found.
  """
  @spec handle_teleport(MobState.t()) :: {:noreply, MobState.t()}
  def handle_teleport(state) do
    # Instant flee reposition (AL_TELEPORT): reuse the {:movement,
    # {:knocked_back, x, y}} position-set path (spatial-index update +
    # delta-snapshot broadcast), not the walking move_to. A missing cache
    # entry or a fully-blocked map is a benign no-op.
    case Cell.random_traversable(state.map_name) do
      {:ok, {x, y}} ->
        updated_state =
          state
          |> MobState.advance_deferred_epoch()
          |> MobState.update_position(x, y)
          |> MobState.stop_movement()
          |> MobState.set_target(nil)
          |> MobState.set_ai_state(:idle)

        Movement.set_position(
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
  def handle_displacement(state, expected_x, expected_y, map_name, x, y) do
    if MobState.is_boss?(state) do
      {:noreply, state}
    else
      handle_relocation(state, expected_x, expected_y, map_name, x, y)
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
          handle_blocked_mob(state, List.last(walk_path))
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

    # Schedule the next tick priced by the step it will take, so entering each
    # cell lines up with the clients' per-cell interpolation.
    if remaining_path != [] do
      interval =
        MovementEngine.step_delay(state.walk_speed, {next_x, next_y}, hd(remaining_path))

      Process.send_after(self(), {:movement, :tick}, interval)
      updated_state
    else
      # Path completed: stop and broadcast the standing transition so the
      # client's last snapshot sample flips move_state back to idle.
      stopped_state = MobState.stop_movement(updated_state)

      Movement.set_position(
        :mob,
        stopped_state.instance_id,
        stopped_state,
        stopped_state.map_name
      )

      stopped_state
    end
  end

  defp handle_blocked_mob(state, destination) do
    with {:ok, map_data} <- MapCache.get(state.map_name),
         {:ok, [_ | _] = path} <-
           Pathfinding.find_path(map_data, {state.x, state.y}, destination, profile: :mob) do
      updated_state = MobState.set_path(state, path)

      first_delay = MovementEngine.step_delay(state.walk_speed, {state.x, state.y}, hd(path))
      Process.send_after(self(), {:movement, :tick}, first_delay)
      updated_state
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
