defmodule Aesir.ZoneServer.Unit.Player.Handlers.MovementHandler do
  @moduledoc """
  Handles player movement operations including pathfinding, movement ticks, and broadcasting.
  Extracted from PlayerSession to improve modularity and maintainability.
  """

  require Logger

  alias Aesir.Net.ItemOnGround
  alias Aesir.Net.ItemVanished
  alias Aesir.Net.Knockback
  alias Aesir.Net.MoveStop
  alias Aesir.Net.SelfMove
  alias Aesir.Net.UnitDespawn
  alias Aesir.Net.UnitSpawn
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Constants.DespawnReason
  alias Aesir.ZoneServer.Constants.ObjectType
  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Mmo.ItemDrop.GroundItem
  alias Aesir.ZoneServer.Mmo.ItemDrop.GroundItemStore
  alias Aesir.ZoneServer.Mmo.Skill.Unit, as: SkillUnit
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager, as: SkillUnitManager
  alias Aesir.ZoneServer.Mmo.Skills.Sage.SaFreecast
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Basilica
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.StatusDisplay
  alias Aesir.ZoneServer.Mmo.WaitingRoom
  alias Aesir.ZoneServer.Mmo.Woe.Rules
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Npc.Packets, as: NpcPackets
  alias Aesir.ZoneServer.Npc.Placement
  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry
  alias Aesir.ZoneServer.Npc.Session, as: NpcSession
  alias Aesir.ZoneServer.Npc.Shop
  alias Aesir.ZoneServer.Npc.Shops
  alias Aesir.ZoneServer.Npc.Warp
  alias Aesir.ZoneServer.Npc.Warps
  alias Aesir.ZoneServer.Pathfinding
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Concealment
  alias Aesir.ZoneServer.Unit.ConfusedWalk
  alias Aesir.ZoneServer.Unit.HitStop
  alias Aesir.ZoneServer.Unit.Homunculus.SpawnView, as: HomunculusSpawnView
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Movement
  alias Aesir.ZoneServer.Unit.MovementEngine
  alias Aesir.ZoneServer.Unit.Player.Handlers.NavigationHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.SkillHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.StatusManager
  alias Aesir.ZoneServer.Unit.Player.Handlers.TouchHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.WaitingRoomHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.Player.StateCommit
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.StaticEntity
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @doc """
  Takes the walk step whose timer is `timer`, or drops it when it is not the
  player's recorded pending step: the walk it belonged to was stopped.
  """
  @spec handle_step(reference(), SessionState.t()) :: {:noreply, SessionState.t()}
  def handle_step(timer, %{game_state: game_state} = state) do
    if HitStop.current?(game_state.pending_step, timer),
      do: handle_movement_tick(state),
      else: {:noreply, state}
  end

  @doc """
  Handles movement tick processing for a walking player.

  ## Parameters
    - state: The player session state

  ## Returns
    - {:noreply, updated_state} - Updated state with new position/walking status
  """
  def handle_movement_tick(state)

  def handle_movement_tick(%{game_state: %{movement_state: :standing}} = state) do
    {:noreply, state}
  end

  def handle_movement_tick(%{game_state: %{movement_state: :moving, walk_path: []}} = state) do
    game_state = PlayerState.stop_walking(state.game_state)
    updated_state = %{state | game_state: game_state}

    # Send message to self for movement completion handling
    # This allows PlayerSession to orchestrate based on state
    send(self(), {:movement, :movement_completed})

    {:noreply, updated_state}
  end

  def handle_movement_tick(%{game_state: game_state} = state)
      when game_state.movement_state == :moving do
    if Interpreter.can_move?(:player, game_state.character_id) and
         not PlayerState.walk_delayed?(game_state, System.monotonic_time(:millisecond)) do
      step_walk_path(state, game_state)
    else
      stop_restricted_walk(state, game_state)
    end
  end

  defp step_walk_path(state, game_state) do
    case game_state.walk_path do
      [{next_x, next_y} | _] = walk_path ->
        if segment_traversable?(
             game_state.map_name,
             {game_state.x, game_state.y},
             {next_x, next_y}
           ) do
          step_player(state, game_state, {next_x, next_y}, tl(walk_path))
        else
          handle_blocked_player(
            state,
            %{game_state | walk_target: nil},
            game_state.walk_target || List.last(walk_path)
          )
        end
    end
  end

  @doc """
  How long, in milliseconds, this player's step from `from` to `to` takes.

  The delay is `MovementEngine.step_delay/3` of the player's current walk
  speed (`StatusManager.current_walk_speed/1`), which while a cast is in flight
  with Free Cast learned is the speed under Free Cast's rate. Each step reads
  it, so the remaining cells retime themselves when the cast starts or ends.
  """
  @spec step_delay(PlayerState.t(), {integer(), integer()}, {integer(), integer()}) ::
          non_neg_integer()
  def step_delay(game_state, from, to) do
    game_state
    |> StatusManager.current_walk_speed()
    |> MovementEngine.step_delay(from, to)
  end

  defp stop_restricted_walk(state, game_state) do
    stopped = %{state | game_state: PlayerState.stop_walking(game_state)}
    publish_stop(stopped)
    {:noreply, stopped}
  end

  defp publish_stop(%{game_state: game_state} = state) do
    packet = %MoveStop{gid: game_state.character_id, x: game_state.x, y: game_state.y}
    MessageRouter.send_to(state.connection_pid, packet)
    broadcast_stop_to_nearby(game_state, packet)
  end

  defp step_player(state, game_state, {next_x, next_y}, remaining_path) do
    # Facing toward the cell we are stepping into.
    dir = Geometry.calculate_direction(game_state.x, game_state.y, next_x, next_y)

    # Update game state with new position
    updated_game_state =
      game_state
      |> PlayerState.update_position(next_x, next_y)
      |> PlayerState.update_direction(dir)
      |> Map.put(:walk_path, remaining_path)

    # Route through the single choke point so the spatial index + registry
    # are synced and the unit is marked dirty for the per-map broadcaster.
    Movement.set_position(
      :player,
      updated_game_state.character_id,
      updated_game_state,
      updated_game_state.map_name
    )

    Basilica.sync_cell_status(updated_game_state)

    # Handle visibility updates
    updated_game_state = handle_visibility_update(updated_game_state)

    # Trigger areas the step left are dropped before the cell is checked, as
    # the reference does: a warp underfoot wins over every touch area.
    state = TouchHandler.leave_areas(%{state | game_state: updated_game_state})

    case maybe_trigger_warp(state.game_state) do
      {:warp_fired, marked_state} ->
        {:noreply, %{state | game_state: marked_state}}

      :no_warp ->
        touched_state =
          state
          |> TouchHandler.scan()
          |> NavigationHandler.on_moved()
          |> SkillHandler.schedule_step_action(half_step(updated_game_state, {next_x, next_y}))

        continue_walk(touched_state, {next_x, next_y})
    end
  end

  # The walk goes on from the state the touch and navigation hooks left: a
  # hook that stopped it schedules nothing; the next tick is priced by the
  # step it will take, so entering each cell lines up with the client's
  # per-cell interpolation.
  defp continue_walk(%{game_state: game_state} = state, from) do
    cond do
      game_state.movement_state != :moving -> {:noreply, state}
      game_state.walk_target != nil -> redirect_walk(state)
      game_state.walk_path == [] -> finish_walk(state)
      true -> schedule_next_step(state, from)
    end
  end

  # A remembered skill use is tried half a step after the cell is entered: half
  # the next step's time, or half a straight step at the end of the walk.
  defp half_step(%{walk_path: [next | _]} = game_state, cell),
    do: div(step_delay(game_state, cell, next), 2)

  defp half_step(game_state, {x, y}), do: div(step_delay(game_state, {x, y}, {x + 1, y}), 2)

  defp schedule_next_step(%{game_state: game_state} = state, from) do
    interval = step_delay(game_state, from, hd(game_state.walk_path))
    {:noreply, %{state | game_state: schedule_step(game_state, interval)}}
  end

  # Path completed: stop and broadcast the standing transition so the client's
  # last snapshot sample flips move_state back to idle.
  defp finish_walk(state) do
    game_state = PlayerState.stop_walking(state.game_state)
    Movement.set_position(:player, game_state.character_id, game_state, game_state.map_name)
    send(self(), {:movement, :movement_completed})
    {:noreply, %{state | game_state: game_state}}
  end

  # A move request made while walking takes effect on the cell the step just
  # landed on: the new path starts there, and a target that cannot be reached
  # from it stops the walk.
  defp redirect_walk(%{game_state: game_state} = state) do
    {dest_x, dest_y} = destination = game_state.walk_target
    game_state = %{game_state | walk_target: nil}

    with {:ok, map_data} <- MapCache.get(game_state.map_name),
         {:ok, path} <-
           Pathfinding.rewalk_path(map_data, {game_state.x, game_state.y}, destination) do
      case path do
        [] ->
          finish_walk(%{state | game_state: game_state})

        _ ->
          {:noreply, %{state | game_state: start_walk(state, game_state, path, dest_x, dest_y)}}
      end
    else
      _ ->
        stopped = %{state | game_state: PlayerState.stop_walking(game_state)}

        Movement.set_position(
          :player,
          game_state.character_id,
          stopped.game_state,
          game_state.map_name
        )

        publish_stop(stopped)
        {:noreply, stopped}
    end
  end

  # Starts a walk along `path`: the client is told, and the first step lands
  # after its own cost, keeping the server position in lockstep with the
  # client's interpolation instead of one cell ahead.
  defp start_walk(state, game_state, path, dest_x, dest_y) do
    game_state = PlayerState.set_path(game_state, path)

    MessageRouter.send_to(state.connection_pid, %SelfMove{
      start_time: System.monotonic_time(:millisecond),
      src_x: game_state.x,
      src_y: game_state.y,
      dst_x: dest_x,
      dst_y: dest_y
    })

    schedule_step(game_state, step_delay(game_state, {game_state.x, game_state.y}, hd(path)))
  end

  @doc """
  Re-runs the touch check of the cell the player stands on after an OnTouch
  status (Hiding, Cloaking, Chase Walk) ended there, or after an NPC whose
  area contains it became visible: the warp underfoot first, else the NPC
  trigger areas (`TouchHandler.scan/1`). Skipped while a warp or map load is
  pending, when the player has moved on since `{map, x, y}`, or when it is
  dead.
  """
  @spec recheck_touch(map(), {String.t(), integer(), integer()}) :: {:noreply, map()}
  def recheck_touch(%{game_state: %{map_name: map, x: x, y: y} = game_state} = state, {map, x, y})
      when game_state.action_state != :dead and is_nil(game_state.pending_map_load) do
    case maybe_trigger_warp(game_state) do
      {:warp_fired, marked_state} -> {:noreply, %{state | game_state: marked_state}}
      :no_warp -> {:noreply, TouchHandler.scan(state)}
    end
  end

  def recheck_touch(state, _position), do: {:noreply, state}

  # Fires when the player's cell sits inside a warp's area: cancel the
  # remaining walk and call `PlayerSession.warp/4` on the session. The
  # per-player re-trigger cooldown guards the same-map-destination instant
  # re-fire loop; within the cooldown this is a no-op and the walk continues.
  @spec maybe_trigger_warp(PlayerState.t()) :: {:warp_fired, PlayerState.t()} | :no_warp
  defp maybe_trigger_warp(game_state) do
    case TouchHandler.warp_underfoot(game_state) do
      %Warp{} = warp ->
        if PlayerState.within_warp_cooldown?(game_state) do
          :no_warp
        else
          marked =
            game_state
            |> PlayerState.mark_warp()
            |> PlayerState.stop_walking()

          Movement.set_position(:player, marked.character_id, marked, marked.map_name)

          PlayerSession.warp(self(), warp.to_map, warp.to_x, warp.to_y)

          {:warp_fired, marked}
        end

      nil ->
        :no_warp
    end
  end

  defp handle_blocked_player(state, game_state, {dest_x, dest_y} = destination) do
    with {:ok, map_data} <- MapCache.get(game_state.map_name),
         {:ok, [_ | _] = path} <-
           Pathfinding.rewalk_path(map_data, {game_state.x, game_state.y}, destination) do
      {:noreply, %{state | game_state: start_walk(state, game_state, path, dest_x, dest_y)}}
    else
      _ ->
        game_state = PlayerState.stop_walking(game_state)

        Movement.set_position(:player, game_state.character_id, game_state, game_state.map_name)

        packet = %MoveStop{gid: game_state.character_id, x: game_state.x, y: game_state.y}
        MessageRouter.send_to(state.connection_pid, packet)

        {:noreply, %{state | game_state: game_state}}
    end
  end

  defp schedule_step(game_state, delay),
    do: %{game_state | pending_step: HitStop.schedule({:movement, :movement_tick}, delay)}

  # A step re-checks only the cells it enters: the path already decided the
  # corners it may cut.
  defp segment_traversable?(_map_name, {x, y}, {x, y}), do: true

  defp segment_traversable?(map_name, {x, y}, {next_x, next_y}) do
    steps = max(abs(next_x - x), abs(next_y - y))
    dx = sign(next_x - x)
    dy = sign(next_y - y)

    Enum.all?(1..steps, fn step -> Cell.traversable?(map_name, x + dx * step, y + dy * step) end)
  end

  defp sign(n) when n > 0, do: 1
  defp sign(n) when n < 0, do: -1
  defp sign(_), do: 0

  @doc """
  Handles a movement request from the client.

  ## Parameters
    - state: The player session state
    - dest_x: Destination X coordinate
    - dest_y: Destination Y coordinate

  ## Returns
    - {:noreply, updated_state} - Updated state with movement path or error handling
  """
  def handle_request_move(state, dest_x, dest_y, opts \\ [])

  # Moving mid-cast. Free Cast turns the cast into an overlay: transition to
  # `:moving` keeping the `casting` descriptor, so the timer keeps running and the
  # skill fires mid-walk (`Mmo.Skills.Sage.SaFreecast`). Without it, moving is still a
  # hard cancel. An invalid transition can only mean the state machine and this
  # clause have drifted apart, so fall back to the cancel rather than walking with
  # a cast nothing will ever resolve. A player who stood up from a ground cast
  # started while seated is idle with the cast in flight, and moves the same way.
  def handle_request_move(
        %{game_state: %{action_state: action_state, casting: casting} = game_state} = state,
        dest_x,
        dest_y,
        opts
      )
      when action_state == :casting or (action_state == :idle and casting != nil) do
    with true <- SaFreecast.known?(game_state),
         {:ok, moving_game_state} <- PlayerState.transition_to(game_state, :moving) do
      handle_request_move(%{state | game_state: moving_game_state}, dest_x, dest_y, opts)
    else
      _ ->
        state
        |> SkillHandler.cancel_cast(:move)
        |> handle_request_move(dest_x, dest_y, opts)
    end
  end

  def handle_request_move(
        %{game_state: game_state, connection_pid: connection_pid} = state,
        dest_x,
        dest_y,
        opts
      ) do
    if Interpreter.can_move?(:player, game_state.character_id) and
         not PlayerState.walk_delayed?(game_state, System.monotonic_time(:millisecond)) do
      do_request_move(state, game_state, dest_x, dest_y, opts)
    else
      packet = %MoveStop{gid: game_state.character_id, x: game_state.x, y: game_state.y}
      MessageRouter.send_to(connection_pid, packet)
      {:noreply, state}
    end
  end

  @walk_delay_retry_window 2000

  @doc """
  Handles the client's walk request: a request while the walk delay has less
  than 2 s left is re-issued one millisecond after the delay ends
  (`{:movement, {:delayed_walk, x, y}}`, `handle_delayed_walk/3`); otherwise
  it is `handle_request_move/3`.
  """
  @spec handle_walk_request(map(), integer(), integer()) :: {:noreply, map()}
  def handle_walk_request(%{game_state: game_state} = state, dest_x, dest_y) do
    mono = System.monotonic_time(:millisecond)
    remaining = (game_state.walk_delay_until || 0) - mono

    if Interpreter.can_move?(:player, game_state.character_id) and
         PlayerState.walk_delayed?(game_state, mono) and remaining < @walk_delay_retry_window do
      Process.send_after(self(), {:movement, {:delayed_walk, dest_x, dest_y}}, remaining + 1)
      {:noreply, state}
    else
      handle_request_move(state, dest_x, dest_y)
    end
  end

  @doc """
  Walks a delayed walk request: the walk starts if the player may move now,
  else nothing happens.
  """
  @spec handle_delayed_walk(map(), integer(), integer()) :: {:noreply, map()}
  def handle_delayed_walk(%{game_state: game_state} = state, dest_x, dest_y) do
    if Interpreter.can_move?(:player, game_state.character_id) and
         not PlayerState.walk_delayed?(game_state, System.monotonic_time(:millisecond)),
       do: do_request_move(state, game_state, dest_x, dest_y, []),
       else: {:noreply, state}
  end

  # A vendor never walks.
  defp do_request_move(state, %PlayerState{vending_shop: shop}, _dest_x, _dest_y, _opts)
       when shop != nil,
       do: {:noreply, state}

  # A seated player never walks.
  defp do_request_move(state, %PlayerState{action_state: :sitting}, _dest_x, _dest_y, _opts),
    do: {:noreply, state}

  # A request with a path to its own destination stops the player's attack and
  # is walked, toward a random cell instead while the player is confused
  # (`ConfusedWalk`). A random cell the player cannot path to, like the player's
  # own cell, starts no walk.
  defp do_request_move(state, game_state, dest_x, dest_y, opts) do
    with {:ok, map_data} <- MapCache.get(game_state.map_name),
         {:ok, path} <-
           Pathfinding.walk_path(
             map_data,
             {game_state.x, game_state.y},
             {dest_x, dest_y}
           ) do
      {destination, path} = confused_request(game_state, map_data, {dest_x, dest_y}, path)
      walk_request(state, game_state, destination, path, opts)
    else
      {:error, reason} ->
        # An unreachable destination is ignored: nothing is sent and a walk
        # under way continues.
        Logger.debug("Movement refused for player #{game_state.character_id}: #{inspect(reason)}")
        {:noreply, state}
    end
  end

  defp confused_request(game_state, map_data, destination, path) do
    from = {game_state.x, game_state.y}

    case ConfusedWalk.destination(
           :player,
           game_state.character_id,
           game_state.map_name,
           from,
           destination
         ) do
      ^destination ->
        {destination, path}

      # The random cell is a re-path of the walk: only the 14-step rule refuses it.
      random ->
        case Pathfinding.rewalk_path(map_data, from, random) do
          {:ok, random_path} -> {random, random_path}
          {:error, _reason} -> {random, []}
        end
    end
  end

  defp walk_request(state, %{movement_state: movement_state} = game_state, _destination, [], opts)
       when movement_state != :moving,
       do:
         {:noreply, StateCommit.commit(state, maybe_clear_action_intent(game_state, opts, :idle))}

  defp walk_request(state, game_state, {dest_x, dest_y}, path, opts) do
    walking? = game_state.movement_state == :moving
    state = dispatch_movement_intent(state, game_state)

    # A manual move (no combat_initiated:/pickup_initiated: flag) while heading
    # to a target or item cancels that pending intent so the player can walk away.
    game_state = maybe_clear_action_intent(state.game_state, opts)

    # The full per-cell path is walked, never a simplified one: step_delay/3
    # prices one adjacent step, so hopping a collapsed straight segment in a
    # single tick would cross it at many times walk speed, racing far ahead of
    # the client's interpolation (and skipping over warp/trap cells). A walk
    # already under way is redirected when its pending step lands instead of
    # starting a second step chain.
    game_state =
      if walking?,
        do: %{game_state | walk_target: {dest_x, dest_y}},
        else: start_walk(state, game_state, path, dest_x, dest_y)

    {:noreply, StateCommit.commit(state, game_state)}
  end

  defp dispatch_movement_intent(state, game_state) do
    position = %{map: game_state.map_name, x: game_state.x, y: game_state.y}

    case Interpreter.on_movement_intent(:player, game_state.character_id, position) do
      :changed -> StatusManager.recalculate_after_status_change(state)
      :unchanged -> state
    end
  end

  # `next` is the action state left behind: `:moving` when the request starts
  # a walk, `:idle` when it does not.
  defp maybe_clear_action_intent(game_state, opts, next \\ :moving)

  defp maybe_clear_action_intent(%{action_state: :combat_moving} = game_state, opts, next) do
    if Keyword.get(opts, :combat_initiated, false) do
      game_state
    else
      Logger.debug("Player manually moving while in combat, clearing combat intent")
      clear_intent(game_state, &PlayerState.clear_combat_intent/1, next)
    end
  end

  defp maybe_clear_action_intent(%{action_state: :attacking} = game_state, opts, next) do
    if Keyword.get(opts, :combat_initiated, false) do
      game_state
    else
      Logger.debug("Player manually moving while attacking, clearing combat intent")
      clear_intent(game_state, &PlayerState.clear_combat_intent/1, next)
    end
  end

  defp maybe_clear_action_intent(%{action_state: :skill_moving} = game_state, opts, next) do
    if Keyword.get(opts, :skill_initiated, false) do
      game_state
    else
      Logger.debug(
        "Player manually moving while heading to a skill target, clearing skill intent"
      )

      clear_intent(game_state, &PlayerState.clear_skill_intent/1, next)
    end
  end

  defp maybe_clear_action_intent(%{action_state: :moving_to_item} = game_state, opts, next) do
    if Keyword.get(opts, :pickup_initiated, false) do
      game_state
    else
      Logger.debug("Player manually moving while heading to an item, clearing pickup intent")
      clear_intent(game_state, &PlayerState.clear_pickup_intent/1, next)
    end
  end

  defp maybe_clear_action_intent(game_state, _opts, _next), do: game_state

  defp clear_intent(game_state, clear_fun, next) do
    game_state
    |> clear_fun.()
    |> PlayerState.transition_to(next)
    |> case do
      {:ok, transitioned} -> transitioned
      _ -> game_state
    end
  end

  @doc """
  Stops a walking player that a damaging hit stopped (`HitStop`): it finishes
  the step it is taking when at most half of it is left, else it stays on its
  cell. The caller has already ruled out endure.
  """
  @spec handle_hit_stop(SessionState.t()) :: {:noreply, SessionState.t()}
  def handle_hit_stop(%{game_state: %{movement_state: :moving} = game_state} = state) do
    HitStop.cancel(game_state.pending_step)
    game_state = %{game_state | walk_target: nil}

    with {:finish_step, [next | _rest]} <-
           {HitStop.plan(game_state.pending_step, HitStop.now()), game_state.walk_path},
         true <- segment_traversable?(game_state.map_name, {game_state.x, game_state.y}, next) do
      {:noreply, stepped} = step_player(state, game_state, next, [])
      publish_stop(stepped)
      {:noreply, stepped}
    else
      _stay -> handle_force_stop_movement(state)
    end
  end

  def handle_hit_stop(state), do: {:noreply, state}

  @doc """
  Forces a player to stop moving immediately.

  ## Parameters
    - state: The player session state

  ## Returns
    - {:noreply, updated_state} - Updated state with stopped movement
  """
  def handle_force_stop_movement(%{game_state: game_state} = state) do
    if game_state.movement_state == :moving do
      publish_force_stop_movement(state)
      {:noreply, %{state | game_state: PlayerState.stop_walking(game_state)}}
    else
      {:noreply, state}
    end
  end

  @doc "Publishes the authoritative stop packet without mutating player state."
  @spec publish_force_stop_movement(SessionState.t()) :: :ok
  def publish_force_stop_movement(%{
        game_state: %{movement_state: :moving} = game_state,
        connection_pid: connection_pid
      }) do
    packet = %MoveStop{
      gid: game_state.character_id,
      x: game_state.x,
      y: game_state.y
    }

    MessageRouter.send_to(connection_pid, packet)
    broadcast_stop_to_nearby(game_state, packet)
  end

  def publish_force_stop_movement(%SessionState{}), do: :ok

  @doc """
  Rejects offensive knockback on current castle ground before displacement
  commit. A knockback that lands ends any skill use the player remembered.
  """
  @spec handle_knockback(
          integer(),
          integer(),
          String.t(),
          integer(),
          integer(),
          SessionState.t()
        ) :: {:noreply, SessionState.t()}
  def handle_knockback(expected_x, expected_y, map_name, x, y, %SessionState{} = state) do
    if Rules.ground?(state.game_state.map_name) do
      {:noreply, state}
    else
      handle_displacement(%{state | step_action: nil}, expected_x, expected_y, map_name, x, y)
    end
  end

  @doc """
  Commits displacement only when the live session still matches its expected
  cell. The landing cell is checked like a step: trigger areas left are
  dropped, then the warp underfoot or the NPC trigger areas fire.
  """
  @spec handle_displacement(
          SessionState.t(),
          integer(),
          integer(),
          String.t(),
          integer(),
          integer()
        ) :: {:noreply, SessionState.t()}
  def handle_displacement(state, expected_x, expected_y, map_name, x, y) do
    game_state = state.game_state

    if Unit.living?(game_state) and
         {game_state.x, game_state.y, game_state.map_name} == {expected_x, expected_y, map_name} and
         Cell.traversable?(map_name, x, y) do
      game_state =
        game_state
        |> PlayerState.stop_walking()
        |> PlayerState.update_position(x, y)

      Movement.set_position(:player, game_state.character_id, game_state, map_name)
      broadcast_displacement(game_state.character_id, map_name, x, y)

      state = TouchHandler.leave_areas(%{state | game_state: game_state})

      case maybe_trigger_warp(state.game_state) do
        {:warp_fired, marked_state} -> {:noreply, %{state | game_state: marked_state}}
        :no_warp -> {:noreply, TouchHandler.scan(state)}
      end
    else
      {:noreply, state}
    end
  end

  defp broadcast_displacement(unit_id, map_name, x, y) do
    packet = %Knockback{unit_id: unit_id, dst_x: x, dst_y: y}
    Broadcast.to_in_range(map_name, x, y, Config.view_range(), packet)
  end

  defp broadcast_stop_to_nearby(game_state, packet) do
    Broadcast.to_in_range(
      game_state.map_name,
      game_state.x,
      game_state.y,
      game_state.view_range,
      packet,
      exclude_id: game_state.character_id
    )
  end

  @doc """
  Updates visibility for nearby players when a player's position changes.
  This function is public so it can be used by PlayerSession for non-movement visibility updates.
  """
  def handle_visibility_update(game_state) do
    players_in_range =
      SpatialIndex.get_players_in_range(
        game_state.map_name,
        game_state.x,
        game_state.y,
        game_state.view_range
      )

    new_visible = MapSet.new(players_in_range)
    old_visible = game_state.visible_players

    # Find who entered and left view
    now_visible = MapSet.difference(new_visible, old_visible)
    now_hidden = MapSet.difference(old_visible, new_visible)

    # Send spawn packets for newly visible players
    Enum.each(now_visible, fn other_id ->
      if other_id != game_state.character_id do
        # Update visibility ETS
        SpatialIndex.update_visibility(game_state.character_id, other_id, true)

        # Send spawn packet to us about them
        send_spawn_packet_about(game_state.character_id, other_id)

        # Send spawn packet to them about us
        send_spawn_packet_about(other_id, game_state.character_id)
      end
    end)

    # Send despawn packets for now hidden players
    Enum.each(now_hidden, fn other_id ->
      if other_id != game_state.character_id do
        # Update visibility ETS
        SpatialIndex.update_visibility(game_state.character_id, other_id, false)

        # Send vanish packet to us
        send_vanish_packet_to(game_state.character_id, other_id)

        # Send vanish packet to them
        send_vanish_packet_to(other_id, game_state.character_id)
      end
    end)

    # Handle mob visibility - use consistent map naming
    # Both players and mobs should use the same map name format
    mobs_in_range =
      SpatialIndex.get_units_in_range(
        :mob,
        game_state.map_name,
        game_state.x,
        game_state.y,
        game_state.view_range
      )

    new_visible_mobs = MapSet.new(mobs_in_range)
    old_visible_mobs = game_state.visible_mobs

    # Find which mobs entered and left view
    now_visible_mobs = MapSet.difference(new_visible_mobs, old_visible_mobs)
    now_hidden_mobs = MapSet.difference(old_visible_mobs, new_visible_mobs)

    # Send spawn packets for newly visible mobs.
    broadcast_new_mob_spawns(game_state, now_visible_mobs)

    # Send despawn packets for now hidden mobs
    Enum.each(now_hidden_mobs, fn mob_id ->
      send_mob_vanish_packet_to(game_state.character_id, mob_id)
    end)

    homunculi_in_range =
      SpatialIndex.get_homunculi_in_range(
        game_state.map_name,
        game_state.x,
        game_state.y,
        game_state.view_range
      )

    new_visible_homunculi = MapSet.new(homunculi_in_range)

    new_visible_homunculi
    |> MapSet.difference(game_state.visible_homunculi)
    |> Enum.each(&send_homunculus_spawn_packet_to(game_state.character_id, &1))

    game_state.visible_homunculi
    |> MapSet.difference(new_visible_homunculi)
    |> Enum.each(&HomunculusSpawnView.send_despawn(game_state.character_id, &1))

    # Handle warp visibility — static NPC warp entities are not spatial-indexed
    # (few per map; held per-map in `Npc.Warps`). Diff against `visible_warps`
    # using the same view square as the mob path (`SpatialIndex.get_units_in_range`).
    warps_on_map =
      case Warps.for_map(game_state.map_name) do
        {:ok, list} -> list
        :error -> []
      end

    warps_in_range =
      Enum.filter(warps_on_map, fn warp ->
        Geometry.chebyshev_distance(game_state.x, game_state.y, warp.x, warp.y) <=
          game_state.view_range
      end)

    warps_by_id = Map.new(warps_in_range, &{Warp.Registry.entity_id(&1), &1})

    new_visible_warps =
      StaticEntity.diff_visibility(
        warps_by_id,
        game_state.visible_warps,
        &send_warp_spawn_packet_to(game_state.character_id, &1),
        &send_warp_vanish_packet_to(game_state.character_id, &1)
      )

    # Handle static NPC visibility — same model as warps: registered placements
    # are held statically (in `Npc.Registry`), not spatial-indexed, and diffed
    # against `visible_npcs` by the `view_range` square. A disabled
    # or hidden NPC (`Npc.Session.visible?/1`) is filtered out here, so the
    # diff never sends a spawn for one and drops it from `visible_npcs` (as a
    # vanish, if the player already had it visible) the moment it stops
    # qualifying — the flag flip itself is broadcast immediately by
    # `Npc.Session`, so a player standing still doesn't have to wait for this
    # diff to notice.
    npcs_in_range =
      Enum.filter(NpcRegistry.entries(), fn {_module, placement} ->
        placement.map == game_state.map_name and
          Geometry.chebyshev_distance(game_state.x, game_state.y, placement.x, placement.y) <=
            game_state.view_range and
          NpcSession.visible?(NpcRegistry.entity_id(placement))
      end)

    npcs_by_id =
      Map.new(npcs_in_range, fn {_module, placement} = entry ->
        {NpcRegistry.entity_id(placement), entry}
      end)

    new_visible_npcs =
      StaticEntity.diff_visibility(
        npcs_by_id,
        game_state.visible_npcs,
        &send_npc_spawn_packet_to(game_state.character_id, &1),
        &send_npc_vanish_packet_to(game_state.character_id, &1)
      )

    # Handle static shop visibility — same model as warps: shop placements are
    # held per-map in `Npc.Shops`, not spatial-indexed, and diffed against
    # `visible_shops` by the `view_range` square.
    shops_on_map =
      case Shops.for_map(game_state.map_name) do
        {:ok, list} -> list
        :error -> []
      end

    shops_in_range =
      Enum.filter(shops_on_map, fn shop ->
        Geometry.chebyshev_distance(game_state.x, game_state.y, shop.x, shop.y) <=
          game_state.view_range
      end)

    shops_by_id = Map.new(shops_in_range, &{Shop.Registry.entity_id(&1), &1})

    new_visible_shops =
      StaticEntity.diff_visibility(
        shops_by_id,
        game_state.visible_shops,
        &send_shop_spawn_packet_to(game_state.character_id, &1),
        &send_shop_vanish_packet_to(game_state.character_id, &1)
      )

    # Handle ground-item visibility — items live in the Coordinator-owned
    # `GroundItemStore` (clean map keying), not the spatial index, and are diffed
    # against `visible_items` so a player sees items already lying on the map when
    # they walk into range and stops seeing them when they leave.
    items_by_id =
      game_state.map_name
      |> GroundItemStore.query_in_range(game_state.x, game_state.y, game_state.view_range)
      |> Map.new(&{&1.id, &1})

    new_visible_items =
      StaticEntity.diff_visibility(
        items_by_id,
        game_state.visible_items,
        &send_item_spawn_packet_to(game_state.character_id, &1),
        &send_item_vanish_packet_to(game_state.character_id, &1)
      )

    new_visible_skill_units = update_skill_unit_visibility(game_state)

    # Update game state with new visibility info
    # Keep last_visibility_cell for potential optimization later
    current_cell = {div(game_state.x, 8), div(game_state.y, 8)}

    updated_game_state = %{
      game_state
      | visible_players: new_visible,
        visible_mobs: new_visible_mobs,
        visible_homunculi: new_visible_homunculi,
        visible_warps: new_visible_warps,
        visible_npcs: new_visible_npcs,
        visible_shops: new_visible_shops,
        visible_items: new_visible_items,
        visible_skill_units: new_visible_skill_units,
        last_visibility_cell: current_cell
    }

    UnitRegistry.update_unit_state(
      :player,
      updated_game_state.character_id,
      updated_game_state
    )

    updated_game_state
  end

  defp update_skill_unit_visibility(game_state) do
    visible_groups =
      game_state.map_name
      |> SkillUnit.in_range(
        game_state.x,
        game_state.y,
        game_state.view_range,
        game_state.character_id,
        game_state.party_id
      )
      |> MapSet.new(& &1.group_id)

    enter_ids = visible_groups |> MapSet.difference(game_state.visible_skill_units) |> Enum.sort()
    leave_ids = game_state.visible_skill_units |> MapSet.difference(visible_groups) |> Enum.sort()

    if enter_ids == [] and leave_ids == [] do
      visible_groups
    else
      SkillUnitManager.sync_view(game_state.character_id, enter_ids, leave_ids)
    end
  end

  defp send_spawn_packet_about(to_char_id, about_char_id) do
    # Get the player session for the target
    case UnitRegistry.get_player_pid(to_char_id) do
      {:ok, pid} ->
        PlayerSession.notify_entered_view(pid, about_char_id)

      {:error, :not_found} ->
        :ok
    end
  end

  defp send_vanish_packet_to(to_char_id, about_char_id) do
    # Get the player session for the target and the account_id of the vanishing player
    with {:ok, to_pid} <- UnitRegistry.get_player_pid(to_char_id),
         {:ok, {_about_pid, about_account_id}} <-
           UnitRegistry.get_player_with_account(about_char_id) do
      PlayerSession.notify_left_view(to_pid, about_char_id, about_account_id)
    else
      _ -> :ok
    end
  end

  # The observer is this session, so its intravision flag (reveal concealed mobs)
  # comes straight off game_state; only read it when there is a mob to spawn.
  defp broadcast_new_mob_spawns(game_state, now_visible_mobs) do
    if Enum.empty?(now_visible_mobs) do
      :ok
    else
      reveal_concealed? = PlayerState.intravision?(game_state)

      Enum.each(now_visible_mobs, fn mob_id ->
        send_mob_spawn_packet_to(game_state.character_id, mob_id, reveal_concealed?)
      end)
    end
  end

  defp send_mob_spawn_packet_to(to_char_id, mob_id, reveal_concealed?) do
    # Get the player session and mob data
    with {:ok, to_pid} <- UnitRegistry.get_player_pid(to_char_id),
         {:ok, {_module, mob_state, _pid}} <- UnitRegistry.get_unit(:mob, mob_id) do
      %{
        body_state: body_state,
        health_state: health_state,
        effect_state: effect_state,
        virtue: virtue
      } =
        StatusDisplay.spawn_state(:mob, mob_state.instance_id)

      # Create mob spawn packet
      mob_packet = %UnitSpawn{
        object_type: ObjectType.mob(),
        aid: mob_state.instance_id,
        gid: mob_state.instance_id,
        speed: mob_state.calculated.speed,
        body_state: body_state,
        health_state: health_state,
        effect_state: effect_state,
        virtue: virtue,
        # Mob sprite ID
        job: mob_state.mob_id,
        head: 0,
        weapon: 0,
        shield: 0,
        accessory: 0,
        accessory2: 0,
        accessory3: 0,
        head_palette: 0,
        body_palette: 0,
        head_dir: 0,
        robe: 0,
        guild_id: 0,
        sex: 0,
        x: mob_state.x,
        y: mob_state.y,
        dir: mob_state.dir,
        clevel: MobState.get_level(mob_state),
        max_hp: mob_state.calculated.max_hp,
        hp: mob_state.hp,
        is_boss: MobState.is_boss?(mob_state),
        name: mob_state.mob_data.name,
        moving: false
      }

      GenServer.cast(to_pid, {:send_packet, Concealment.reveal(mob_packet, reveal_concealed?)})

      :mob
      |> StatusDisplay.active_icons(mob_state.instance_id)
      |> Enum.each(&Broadcast.to_player(to_char_id, &1))
    else
      _ -> :ok
    end
  end

  defp send_homunculus_spawn_packet_to(to_char_id, gid) do
    case UnitRegistry.get_unit(:homunculus, gid) do
      {:ok, {_module, homunculus, _pid}} -> HomunculusSpawnView.send_spawn(to_char_id, homunculus)
      {:error, :not_found} -> :ok
    end
  end

  defp send_mob_vanish_packet_to(to_char_id, mob_id) do
    # Get the player session
    case UnitRegistry.get_player_pid(to_char_id) do
      {:ok, to_pid} ->
        vanish_packet = %UnitDespawn{
          gid: mob_id,
          reason: DespawnReason.out_of_sight()
        }

        GenServer.cast(to_pid, {:send_packet, vanish_packet})

      {:error, :not_found} ->
        :ok
    end
  end

  defp send_warp_spawn_packet_to(to_char_id, %Warp{} = warp) do
    case UnitRegistry.get_player_pid(to_char_id) do
      {:ok, to_pid} ->
        warp_entity_id = Warp.Registry.entity_id(warp)

        packet = %UnitSpawn{
          object_type: ObjectType.npc(),
          aid: warp_entity_id,
          gid: warp_entity_id,
          speed: 0,
          body_state: 0,
          health_state: 0,
          effect_state: 0,
          job: warp.sprite,
          head: 0,
          weapon: 0,
          shield: 0,
          accessory: 0,
          accessory2: 0,
          accessory3: 0,
          head_palette: 0,
          body_palette: 0,
          head_dir: 0,
          robe: 0,
          guild_id: 0,
          sex: 0,
          x: warp.x,
          y: warp.y,
          dir: 0,
          clevel: 0,
          max_hp: 0,
          hp: 0,
          is_boss: false,
          name: warp.name,
          moving: false
        }

        GenServer.cast(to_pid, {:send_packet, packet})

      {:error, :not_found} ->
        :ok
    end
  end

  defp send_warp_vanish_packet_to(to_char_id, warp_entity_id) do
    case UnitRegistry.get_player_pid(to_char_id) do
      {:ok, to_pid} ->
        vanish_packet = %UnitDespawn{
          gid: warp_entity_id,
          reason: DespawnReason.out_of_sight()
        }

        GenServer.cast(to_pid, {:send_packet, vanish_packet})

      {:error, :not_found} ->
        :ok
    end
  end

  defp send_npc_spawn_packet_to(to_char_id, {_module, %Placement{} = placement} = entry) do
    case UnitRegistry.get_player_pid(to_char_id) do
      {:ok, to_pid} ->
        GenServer.cast(to_pid, {:send_packet, NpcPackets.spawn_packet(entry)})

        with {:ok, room} <- WaitingRoom.get(NpcRegistry.entity_id(placement)),
             do: GenServer.cast(to_pid, {:send_packet, WaitingRoomHandler.info_packet(room)})

      {:error, :not_found} ->
        :ok
    end
  end

  defp send_npc_vanish_packet_to(to_char_id, npc_entity_id) do
    case UnitRegistry.get_player_pid(to_char_id) do
      {:ok, to_pid} ->
        GenServer.cast(to_pid, {:send_packet, NpcPackets.vanish_packet(npc_entity_id)})

      {:error, :not_found} ->
        :ok
    end
  end

  defp send_shop_spawn_packet_to(to_char_id, %Shop{} = shop) do
    case UnitRegistry.get_player_pid(to_char_id) do
      {:ok, to_pid} ->
        shop_entity_id = Shop.Registry.entity_id(shop)

        packet = %UnitSpawn{
          object_type: ObjectType.npc(),
          aid: shop_entity_id,
          gid: shop_entity_id,
          speed: 0,
          body_state: 0,
          health_state: 0,
          effect_state: 0,
          job: shop.sprite,
          head: 0,
          weapon: 0,
          shield: 0,
          accessory: 0,
          accessory2: 0,
          accessory3: 0,
          head_palette: 0,
          body_palette: 0,
          head_dir: 0,
          robe: 0,
          guild_id: 0,
          sex: 0,
          x: shop.x,
          y: shop.y,
          dir: shop.dir,
          clevel: 0,
          max_hp: 0,
          hp: 0,
          is_boss: false,
          name: shop.name,
          moving: false
        }

        GenServer.cast(to_pid, {:send_packet, packet})

      {:error, :not_found} ->
        :ok
    end
  end

  defp send_shop_vanish_packet_to(to_char_id, shop_entity_id) do
    case UnitRegistry.get_player_pid(to_char_id) do
      {:ok, to_pid} ->
        vanish_packet = %UnitDespawn{
          gid: shop_entity_id,
          reason: DespawnReason.out_of_sight()
        }

        GenServer.cast(to_pid, {:send_packet, vanish_packet})

      {:error, :not_found} ->
        :ok
    end
  end

  defp send_item_spawn_packet_to(to_char_id, %GroundItem{} = item) do
    case UnitRegistry.get_player_pid(to_char_id) do
      {:ok, to_pid} ->
        packet = %ItemOnGround{
          ground_id: item.id,
          nameid: item.nameid,
          amount: item.amount,
          x: item.x,
          y: item.y,
          sub_x: item.sub_x,
          sub_y: item.sub_y,
          identified: item.identified,
          is_falling: false
        }

        GenServer.cast(to_pid, {:send_packet, packet})

      {:error, :not_found} ->
        :ok
    end
  end

  # NOTE: leaving view is neither a pickup nor an expiry, but the frozen proto
  # only offers PICKED_UP/EXPIRED; EXPIRED is the silent-removal visual that
  # matches "walked out of range". Add a dedicated reason if the client ever
  # needs to distinguish them.
  defp send_item_vanish_packet_to(to_char_id, ground_id) do
    case UnitRegistry.get_player_pid(to_char_id) do
      {:ok, to_pid} ->
        GenServer.cast(
          to_pid,
          {:send_packet, %ItemVanished{ground_id: ground_id, reason: :EXPIRED}}
        )

      {:error, :not_found} ->
        :ok
    end
  end
end
