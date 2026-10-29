defmodule Aesir.ZoneServer.Unit.Mob.Handlers.MovementHandler do
  @moduledoc """
  Handles mob movement: pathfinding kickoff, per-tick stepping, blocked-path
  repathing, and the instant teleport reposition. Extracted from MobSession to
  improve modularity and maintainability.
  """

  alias Aesir.Net.Knockback
  alias Aesir.Net.MoveStop
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.Woe.Rules
  alias Aesir.ZoneServer.Pathfinding
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.ConfusedWalk
  alias Aesir.ZoneServer.Unit.HitStop
  alias Aesir.ZoneServer.Unit.Mob.AIStateMachine
  alias Aesir.ZoneServer.Unit.Mob.Handlers.AiHandler
  alias Aesir.ZoneServer.Unit.Mob.Handlers.CastingHandler
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Mob.Slaves
  alias Aesir.ZoneServer.Unit.Mob.SpawnView
  alias Aesir.ZoneServer.Unit.Mob.StateCommit
  alias Aesir.ZoneServer.Unit.Movement
  alias Aesir.ZoneServer.Unit.MovementEngine
  alias Aesir.ZoneServer.Unit.SpatialIndex

  @doc """
  Forces the mob to path toward `{x, y}`. A mob already walking keeps its
  pending step and takes the new path from the cell that step lands on.

  A request with a path stops the mob's attack, and a confused mob walks to a
  random cell instead (`ConfusedWalk`); a random cell it cannot path to leaves
  it where it is. A `chase: true` request (a chase, loot or follow walk) is
  refused only by the 14-step rule (`Pathfinding.rewalk_path/3`); any other
  request is a new walk, refused past 17 steps too (`Pathfinding.walk_path/3`).
  """
  @spec handle_move_to(MobState.t(), integer(), integer(), keyword()) ::
          {:noreply, MobState.t()}
  def handle_move_to(state, x, y, opts \\ []) do
    chase? = Keyword.get(opts, :chase, false)

    with {:ok, map_data} <- MapCache.get(state.map_name),
         {:ok, path} <-
           request_path(map_data, {state.x, state.y}, {x, y}, chase?) do
      state =
        MobState.stop_attack(%{
          state
          | walk_easy: false,
            chase_walk: chase? and state.loot_target_id == nil,
            chase_target: if(chase?, do: state.chase_target, else: nil)
        })

      {:noreply,
       walk_request(
         state,
         {x, y},
         path,
         &Pathfinding.rewalk_path(map_data, {state.x, state.y}, &1)
       )}
    else
      # No path found or map not loaded.
      _ -> {:noreply, state}
    end
  end

  @doc """
  Runs the mob away from `{from_x, from_y}` in a straight line, up to
  `distance` cells: along the 8-way sector of the mob's offset from that cell
  (east when they share it), stopping short of the first cell it cannot walk
  on. The walk paths in a straight line for its whole length. A mob already
  walking takes it from the cell its pending step lands on. Nothing happens
  when not even the first cell is walkable. Like any walk request it stops
  the mob's attack and is randomized under Confusion.
  """
  @spec escape(MobState.t(), {integer(), integer()}, pos_integer()) :: MobState.t()
  def escape(%MobState{x: x, y: y} = state, {from_x, from_y}, distance) do
    {dx, dy} = Geometry.sector_step(x - from_x, y - from_y)

    reach =
      Enum.find(1..distance, distance + 1, fn i ->
        not Cell.traversable?(state.map_name, x + i * dx, y + i * dy)
      end) - 1

    destination = {x + reach * dx, y + reach * dy}

    with true <- reach > 0,
         {:ok, map_data} <- MapCache.get(state.map_name),
         {:ok, path} <- Pathfinding.walk_path(map_data, {x, y}, destination, easy: true) do
      state = MobState.stop_attack(%{state | walk_easy: true, chase_walk: false})

      walk_request(
        state,
        destination,
        path,
        &Pathfinding.rewalk_path(map_data, {x, y}, &1, easy: true)
      )
    else
      _ -> state
    end
  end

  # A chase walk (`unit_walktobl`) is refused only by the 14-step rule; any
  # other request is a new walk with the 17-step refusal too.
  defp request_path(map_data, from, to, true), do: Pathfinding.rewalk_path(map_data, from, to)
  defp request_path(map_data, from, to, false), do: Pathfinding.walk_path(map_data, from, to)

  # Walks a request whose own destination has a path: a confused mob walks to
  # its random cell instead, re-pathed now unless it is already walking. The
  # random cell is a re-path of the walk (`rewalk_path`): only the 14-step rule
  # refuses it, whatever refused the requested cell.
  defp walk_request(state, destination, path, path_to) do
    from = {state.x, state.y}

    case ConfusedWalk.destination(:mob, state.instance_id, state.map_name, from, destination) do
      ^destination -> walk(state, destination, path)
      random -> walk_random(state, random, path_to)
    end
  end

  defp walk_random(%MobState{movement_state: :moving} = state, random, _path_to),
    do: walk(state, random, [])

  defp walk_random(state, random, path_to) do
    case path_to.(random) do
      {:ok, path} -> walk(state, random, path)
      _no_path -> state
    end
  end

  # A mob already walking redirects at the cell its pending step lands on; a
  # chase redirect puts it in its rush state at once.
  defp walk(%MobState{movement_state: :moving} = state, destination, _path),
    do: enter_chase(%{state | walk_target: destination})

  defp walk(state, _destination, []), do: state
  defp walk(state, _destination, path), do: start_walk(state, path)

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
    |> enter_chase()
    |> MobState.set_path(path)
    |> next_cell()
  end

  # A chase walk puts the mob in its rush state as its path starts, so the
  # first cell's skill check already sees it.
  defp enter_chase(%MobState{chase_walk: true} = state), do: MobState.set_state(state, :rush)
  defp enter_chase(state), do: state

  # Before each cell of a walk (its first included) the mob checks its skills
  # (`AiHandler.walk_skill_check/1`). A skill that stops the walk fixes the
  # mob's position on this cell, since clients were interpolating the cancelled
  # path; the mob then either stands here or walks the path the skill asked for.
  defp next_cell(state, progressed? \\ false) do
    case AiHandler.walk_skill_check(state) do
      {stop_or_continue, %MobState{walk_target: {_x, _y}} = redirected} ->
        redirected |> publish_position_fix(stop_or_continue) |> redirect_walk()

      {:continue, state} ->
        case AiHandler.walk_chase(state, progressed?, length(state.walk_path) == 1) do
          {:stop, state} -> stop_walk(%{state | chase_target: nil})
          {{:repath, destination}, state} -> refresh_chase_path(state, destination)
          {:continue, state} -> schedule_next_cell(state)
        end

      {:stop, state} ->
        state |> stop_walk() |> publish_position_fix(:stop)
    end
  end

  defp publish_position_fix(state, :stop) do
    packet = %MoveStop{gid: state.instance_id, x: state.x, y: state.y}
    Broadcast.to_in_range(state.map_name, state.x, state.y, Config.view_range(), packet)
    state
  end

  defp publish_position_fix(state, :continue), do: state

  defp schedule_next_cell(state) do
    [next | _rest] = state.walk_path

    schedule_step(
      state,
      MovementEngine.step_delay(state.calculated.speed, {state.x, state.y}, next)
    )
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
  Warps the mob to a random walkable cell on its map (`AL_TELEPORT`, Tarot):
  it leaves its map as `warp_to/3` describes. A no-op if no walkable cell is
  found.
  """
  @spec handle_teleport(MobState.t()) :: {:noreply, MobState.t()}
  def handle_teleport(state) do
    case Cell.random_traversable(state.map_name) do
      {:ok, {x, y}} -> {:noreply, warp_to(state, x, y)}
      {:error, _reason} -> {:noreply, state}
    end
  end

  @doc """
  Stops a walking mob that a damaging hit stopped (`HitStop`): it finishes the
  step it is taking when at most half of it is left and the step's checks
  let it, else it stays on its cell. The caller has already
  ruled out endure and an escape walk.
  """
  @spec handle_hit_stop(MobState.t()) :: MobState.t()
  def handle_hit_stop(%MobState{movement_state: :moving} = state) do
    HitStop.cancel(state.pending_step)
    state = %{state | walk_target: nil}

    with {:finish_step, [next | _rest]} <-
           {HitStop.plan(state.pending_step, HitStop.now()), state.walk_path},
         check when check != :blocked <- step_check(state, next) do
      if check == :step, do: step_mob(state, next, []), else: hold_on_icewall(state)
    else
      _stay -> stop_walk(state)
    end
  end

  def handle_hit_stop(%MobState{} = state), do: state

  @doc """
  Gives the mob a skill's walk delay of `duration` ms (Guard's block): it may
  not walk until the delay ends, and a walk in progress stops as a hit stop
  does, a chase resuming one millisecond after the delay. A status-immune mob
  ignores it, and a delay already running past `duration` is kept and stops
  nothing.
  """
  @spec handle_walk_delay(MobState.t(), pos_integer()) :: {:noreply, MobState.t()}
  def handle_walk_delay(%MobState{} = state, duration) do
    now = HitStop.now()

    if MobState.status_immune?(state) or MobState.walk_delayed?(state, now + duration) do
      {:noreply, state}
    else
      walking? = state.movement_state == :moving
      state = state |> MobState.apply_walk_delay(duration, now) |> handle_hit_stop()
      {:noreply, state |> resume_chase_after_delay(walking?, now) |> StateCommit.commit()}
    end
  end

  defp resume_chase_after_delay(%MobState{chase_target: target} = state, true, now)
       when target != nil do
    at = state.walk_delay_until + 1
    Process.send_after(self(), {:ai, {:chase_resume, at}}, at - now)
    %{state | chase_resume_at: at}
  end

  defp resume_chase_after_delay(state, _walking?, _now), do: state

  @doc "Shortens a walking mob's path to one cell, or two after crossing the step's midpoint."
  @spec stop_soon(MobState.t()) :: MobState.t()
  def stop_soon(%MobState{movement_state: :moving} = state) do
    remaining = if HitStop.plan(state.pending_step, HitStop.now()) == :finish_step, do: 2, else: 1
    state = %{state | walk_path: Enum.take(state.walk_path, remaining), walk_target: nil}
    Movement.set_position(:mob, state.instance_id, state, state.map_name)
    state
  end

  def stop_soon(state), do: state

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
  Re-targets a moving mob after a speed selection, as the source's
  `change_walk_target`: the pending step keeps its token, cost and deadline, and
  the new speed prices the steps that start once it lands. A standing mob is
  unchanged. This calculates nothing and publishes nothing itself.
  """
  @spec rewalk_after_speed_change(MobState.t()) :: MobState.t()
  def rewalk_after_speed_change(%MobState{movement_state: :moving, walk_path: [_ | _]} = state) do
    %{state | walk_target: state.walk_target || List.last(state.walk_path)}
  end

  def rewalk_after_speed_change(%MobState{} = state), do: state

  @doc """
  Warps the mob to `(x, y)` on `map_name`, including a boss: a living mob lands
  there when the cell is walkable, leaving its map as `warp_to/3` describes.
  """
  @spec handle_warp(MobState.t(), String.t(), integer(), integer()) :: {:noreply, MobState.t()}
  def handle_warp(state, map_name, x, y) do
    if Unit.living?(state) and map_name == state.map_name and Cell.traversable?(map_name, x, y) do
      {:noreply, warp_to(state, x, y)}
    else
      {:noreply, state}
    end
  end

  @doc """
  Removes the mob from its map and puts it back on `(x, y)`: its cast is
  cancelled, its walk and attack stop, its attack and walk delays end, its
  deferred work is invalidated, it drops its chase and attack orders, its
  attacked event and spotting players and goes idle (its target stays), it
  loses the statuses a unit leaving its map loses, leaves its ground units and
  vanishes with the teleport reason (`Movement.warp_position/4`), and appears
  on the new cell, the same cell included.
  """
  @spec warp_to(MobState.t(), integer(), integer()) :: MobState.t()
  def warp_to(%MobState{} = state, x, y) do
    state =
      state
      |> cancel_cast()
      |> MobState.stop_movement()
      |> MobState.leave_map()
      |> MobState.advance_deferred_epoch()

    StatusInterpreter.remove_on_map_change(:mob, state.instance_id)
    state = MobState.update_position(state, x, y)
    SpatialIndex.reenter_block(:mob, state.instance_id)
    Movement.warp_position(:mob, state.instance_id, state, state.map_name)
    SpawnView.notify_spawn(state)
    Slaves.recall(state)
    state
  end

  defp cancel_cast(%MobState{casting: nil} = state), do: state
  defp cancel_cast(state), do: CastingHandler.abort_cast(state)

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
      [next | rest] = walk_path ->
        case step_check(state, next) do
          :step ->
            step_mob(state, next, rest)

          :hold ->
            hold_on_icewall(state)

          :blocked ->
            handle_blocked_mob(
              %{state | walk_target: nil},
              state.walk_target || List.last(walk_path)
            )
        end
    end
  end

  @icewall_walk_block 75

  # A step re-checks only the cell it enters: the path already decided the
  # corners it may cut. A mob walks on into an icewall cell that blocks the way
  # when it steps east or north (when the cell holds it at all); on an icewall
  # cell it cannot step east or north until 75 such steps in a row have failed.
  # A status-immune mob is never held.
  defp step_check(state, next) do
    block = if MobState.status_immune?(state), do: 0, else: @icewall_walk_block

    cond do
      blocked_step?(state, next, block) -> :blocked
      held_on_icewall?(state, next, block) -> :hold
      true -> :step
    end
  end

  defp blocked_step?(state, {next_x, next_y}, block) do
    not Cell.traversable?(state.map_name, next_x, next_y) and
      (block == 0 or next_x < state.x or next_y < state.y or
         not Cell.icewall?(state.map_name, next_x, next_y))
  end

  defp held_on_icewall?(state, {next_x, next_y}, block) do
    state.walk_fail_count < block and (next_x > state.x or next_y > state.y) and
      Cell.icewall?(state.map_name, state.x, state.y)
  end

  # An icewall cell holding the mob ends its walk on its cell and drops its
  # target.
  defp hold_on_icewall(state) do
    %{state | walk_fail_count: state.walk_fail_count + 1}
    |> stop_walk()
    |> AIStateMachine.unlock_target(System.system_time(:millisecond))
  end

  defp step_mob(state, {next_x, next_y}, remaining_path) do
    HitStop.cancel(state.pending_step)
    # Facing toward the cell we are stepping into.
    dir = Geometry.calculate_direction(state.x, state.y, next_x, next_y)

    # Update mob state FIRST to maintain consistency
    updated_state =
      state
      |> MobState.update_position(next_x, next_y)
      |> MobState.update_direction(dir)
      |> Map.merge(%{walk_path: remaining_path, walk_fail_count: 0, pending_step: nil})

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

      # The next tick is priced by the step it will take, so entering each
      # cell lines up with the clients' per-cell interpolation.
      remaining_path != [] ->
        next_cell(updated_state, true)

      true ->
        finish_walk(updated_state)
    end
  end

  # Path completed: stop and broadcast the standing transition so the client's
  # last snapshot sample flips move_state back to idle. An escape walk ends here.
  defp finish_walk(state) do
    case AiHandler.walk_chase(state, true, true) do
      {{:repath, destination}, state} ->
        refresh_chase_path(state, destination)

      {:stop, state} ->
        settle_walk(%{state | chase_target: nil})

      {:continue, state} ->
        settle_walk(state)
    end
  end

  defp settle_walk(state) do
    stopped = %{MobState.stop_movement(state) | can_escape: false}
    Movement.set_position(:mob, stopped.instance_id, stopped, stopped.map_name)
    stopped
  end

  defp refresh_chase_path(state, destination) do
    case walk_path(state, destination) do
      {:ok, [_ | _] = path} ->
        start_walk(state, path)

      {:ok, []} ->
        settle_walk(state)

      _no_path ->
        if state.walk_path == [], do: settle_walk(state), else: schedule_next_cell(state)
    end
  end

  # A move request made while walking takes effect on the cell the step just
  # landed on: the new path starts there, and a target that cannot be reached
  # from it stops the walk.
  defp redirect_walk(state) do
    destination = state.walk_target
    state = %{state | walk_target: nil}

    case walk_path(state, destination) do
      {:ok, []} -> finish_walk(state)
      {:ok, path} -> start_walk(state, path)
      _no_path -> stop_walk(state)
    end
  end

  defp stop_walk(state) do
    HitStop.cancel(state.pending_step)
    stopped_state = MobState.stop_movement(state)
    Movement.set_position(:mob, stopped_state.instance_id, stopped_state, state.map_name)
    stopped_state
  end

  # A path for the walk's current mode: straight for an easy walk, else around
  # obstacles.
  defp walk_path(state, destination) do
    with {:ok, map_data} <- MapCache.get(state.map_name) do
      Pathfinding.rewalk_path(map_data, {state.x, state.y}, destination, easy: state.walk_easy)
    end
  end

  defp schedule_step(state, delay),
    do: %{state | pending_step: HitStop.schedule({:movement, :tick}, delay)}

  defp handle_blocked_mob(state, destination) do
    case walk_path(state, destination) do
      {:ok, [_ | _] = path} -> start_walk(state, path)
      _no_path -> stop_walk(state)
    end
  end
end
