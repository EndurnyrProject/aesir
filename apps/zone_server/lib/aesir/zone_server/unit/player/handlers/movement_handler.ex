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
  alias Aesir.ZoneServer.Mmo.Skill.Unit.FieldSupport, as: SkillUnitFieldSupport
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager, as: SkillUnitManager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage, as: SkillUnitStorage
  alias Aesir.ZoneServer.Mmo.Skills.Sage.SaFreecast
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.StatusDisplay
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Npc.Events, as: NpcEvents
  alias Aesir.ZoneServer.Npc.Packets, as: NpcPackets
  alias Aesir.ZoneServer.Npc.Placement
  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry
  alias Aesir.ZoneServer.Npc.Session, as: NpcSession
  alias Aesir.ZoneServer.Npc.Shop
  alias Aesir.ZoneServer.Npc.Shops
  alias Aesir.ZoneServer.Npc.Warp
  alias Aesir.ZoneServer.Npc.Warps
  alias Aesir.ZoneServer.Pathfinding
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Concealment
  alias Aesir.ZoneServer.Unit.Homunculus.SpawnView, as: HomunculusSpawnView
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Movement
  alias Aesir.ZoneServer.Unit.MovementEngine
  alias Aesir.ZoneServer.Unit.Player.Handlers.NpcInteractionHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.SkillHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.StatusManager
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.StaticEntity
  alias Aesir.ZoneServer.Unit.UnitRegistry

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
          handle_blocked_player(state, game_state, List.last(walk_path))
        end
    end
  end

  @doc """
  How long, in milliseconds, this player's step from `from` to `to` takes.

  The base delay comes from the live `walk_speed` and the per-cell movement cost
  (`MovementEngine.step_delay/3`). A caster walking under Free Cast pays
  `SaFreecast.speed_rate/1` percent of that (rAthena `speed = speed * speed_rate / 100`,
  `status.cpp:8040-8044,8213`).

  The penalty is applied here, at the point of use, rather than folded into
  `walk_speed`: rAthena scopes it to the cast (`sd->ud.skilltimer != INVALID_TIMER`)
  rather than to a status, so there is no recalculation to trigger when a cast
  starts or ends, and the remaining cells retime themselves the moment the cast
  resolves.
  """
  @spec step_delay(PlayerState.t(), {integer(), integer()}, {integer(), integer()}) ::
          non_neg_integer()
  def step_delay(game_state, from, to) do
    base = MovementEngine.step_delay(game_state.walk_speed, from, to)

    case cast_speed_rate(game_state) do
      100 -> base
      rate -> div(base * rate, 100)
    end
  end

  # rAthena gates the rate on a cast being in flight *and* Free Cast being known
  # (`status.cpp:8040`) — the skill only ever grants the slow walk, never a plain
  # walk-speed penalty.
  defp cast_speed_rate(%{casting: nil}), do: 100

  defp cast_speed_rate(game_state) do
    case SaFreecast.level(game_state) do
      0 -> 100
      level -> SaFreecast.speed_rate(level)
    end
  end

  defp stop_restricted_walk(state, game_state) do
    stopped = PlayerState.stop_walking(game_state)

    packet = %MoveStop{gid: stopped.character_id, x: stopped.x, y: stopped.y}
    MessageRouter.send_to(state.connection_pid, packet)

    broadcast_stop_to_nearby(stopped, packet)

    {:noreply, %{state | game_state: stopped}}
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

    destination_groups =
      SkillUnitStorage.get_groups_at_cell(
        updated_game_state.map_name,
        updated_game_state.x,
        updated_game_state.y
      )

    if destination_groups != [] or
         SkillUnitFieldSupport.sources_for_unit(:player, updated_game_state.character_id) != [] do
      SkillUnitManager.reconcile_unit({:player, updated_game_state.character_id})
    end

    # Handle visibility updates
    updated_game_state = handle_visibility_update(updated_game_state)

    case maybe_trigger_warp(updated_game_state, next_x, next_y) do
      {:warp_fired, marked_state} ->
        {:noreply, %{state | game_state: marked_state}}

      :no_warp ->
        touched_state = maybe_trigger_touch(%{state | game_state: updated_game_state})

        # Schedule the next tick priced by the step it will take, so entering
        # each cell lines up with the client's per-cell interpolation.
        if remaining_path != [] do
          interval =
            step_delay(touched_state.game_state, {next_x, next_y}, hd(remaining_path))

          Process.send_after(self(), {:movement, :movement_tick}, interval)
          {:noreply, touched_state}
        else
          # Path completed: stop and broadcast the standing transition so the
          # client's last snapshot sample flips move_state back to idle.
          game_state = PlayerState.stop_walking(touched_state.game_state)

          Movement.set_position(
            :player,
            game_state.character_id,
            game_state,
            game_state.map_name
          )

          # Send completion message for PlayerSession to handle
          send(self(), {:movement, :movement_completed})
          {:noreply, %{touched_state | game_state: game_state}}
        end
    end
  end

  # On-touch warp trigger hook (rAthena `OnTouch`, cell-enter).
  #
  # Fires after the player has stepped onto `(x, y)`: if that cell sits inside a
  # warp's `xs/ys` area, cancel the remaining walk and call `PlayerSession.warp/4`
  # on the session — reusing the existing map-warp cast (zero new plumbing). The
  # per-player re-trigger cooldown guards the same-map-destination instant
  # re-fire loop; within the cooldown this is a no-op and the walk continues.
  @spec maybe_trigger_warp(PlayerState.t(), integer(), integer()) ::
          {:warp_fired, PlayerState.t()} | :no_warp
  defp maybe_trigger_warp(game_state, x, y) do
    warps_for_map =
      case Warps.for_map(game_state.map_name) do
        {:ok, list} -> list
        :error -> []
      end

    case Warp.Registry.hit?(warps_for_map, x, y) do
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

  # On-touch NPC trigger-area hook (rAthena `OnTouch`, cell-enter).
  #
  # Called only when the warp check above did not fire (a warp makes any
  # touch area on the map being left moot). Computes the set of touch rects
  # on the player's current map containing its (already updated) cell,
  # skipping any NPC that `Npc.Session.visible?/1` reports disabled/hidden, and
  # replaces `inside_npc_areas` with it — leaving a rect drops its gid so
  # re-entering fires again, and standing still (this only runs on an actual
  # step) never re-fires. Every gid newly present (not in the old set) fires:
  # a busy player (an active `interaction_lock`) skips the fire but still
  # counts the area as entered, matching rAthena's no-spam-while-busy rule.
  @spec maybe_trigger_touch(map()) :: map()
  defp maybe_trigger_touch(%{game_state: game_state} = state) do
    containing =
      game_state.map_name
      |> NpcRegistry.touch_rects()
      |> Enum.filter(fn {gid, xs, ys} ->
        game_state.x in xs and game_state.y in ys and NpcSession.visible?(gid)
      end)
      |> MapSet.new(fn {gid, _xs, _ys} -> gid end)

    entered = MapSet.difference(containing, game_state.inside_npc_areas)
    marked_state = %{state | game_state: %{game_state | inside_npc_areas: containing}}

    Enum.reduce(entered, marked_state, &fire_touch/2)
  end

  @spec fire_touch(non_neg_integer(), map()) :: map()
  defp fire_touch(gid, state) do
    if SessionState.interaction_blocked?(state) do
      state
    else
      case NpcRegistry.module_for_unit(gid) do
        {:ok, {module, _placement}} -> attach_or_fallback(gid, module, state)
        :error -> state
      end
    end
  end

  # Starts the module's `OnTouch` handler as an attached interaction; when the
  # module declares no `OnTouch` label, falls back to the click path's
  # `on_talk/1` start (rAthena warper behavior).
  @spec attach_or_fallback(non_neg_integer(), module(), map()) :: map()
  defp attach_or_fallback(gid, module, state) do
    base_ctx =
      state
      |> Ctx.from_session({:npc, module.npc_id()})
      |> Map.put(:npc_gid, gid)

    case NpcEvents.trigger_attached(gid, "OnTouch", base_ctx, self()) do
      {:ok, pid} ->
        ref = Process.monitor(pid)
        %{state | interaction_lock: {pid, ref, gid}}

      {:error, :no_handler} ->
        {:noreply, new_state} = NpcInteractionHandler.talk_to_npc(gid, state.game_state, state)
        new_state
    end
  end

  defp handle_blocked_player(state, game_state, destination) do
    with {:ok, map_data} <- MapCache.get(game_state.map_name),
         {:ok, [_ | _] = path} <-
           Pathfinding.find_path(map_data, {game_state.x, game_state.y}, destination) do
      game_state = PlayerState.set_path(game_state, path)

      first_delay = step_delay(game_state, {game_state.x, game_state.y}, hd(path))
      Process.send_after(self(), {:movement, :movement_tick}, first_delay)
      {:noreply, %{state | game_state: game_state}}
    else
      _ ->
        game_state = PlayerState.stop_walking(game_state)

        Movement.set_position(:player, game_state.character_id, game_state, game_state.map_name)

        packet = %MoveStop{gid: game_state.character_id, x: game_state.x, y: game_state.y}
        MessageRouter.send_to(state.connection_pid, packet)

        {:noreply, %{state | game_state: game_state}}
    end
  end

  defp segment_traversable?(_map_name, {x, y}, {x, y}), do: true

  defp segment_traversable?(map_name, {x, y}, {next_x, next_y}) do
    steps = max(abs(next_x - x), abs(next_y - y))
    dx = sign(next_x - x)
    dy = sign(next_y - y)

    Enum.all?(1..steps, fn step ->
      from = {x + dx * (step - 1), y + dy * (step - 1)}
      Cell.step_traversable?(map_name, from, {x + dx * step, y + dy * step})
    end)
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
  # a cast nothing will ever resolve.
  def handle_request_move(
        %{game_state: %{action_state: :casting} = game_state} = state,
        dest_x,
        dest_y,
        opts
      ) do
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
      do_request_move(state, game_state, connection_pid, dest_x, dest_y, opts)
    else
      packet = %MoveStop{gid: game_state.character_id, x: game_state.x, y: game_state.y}
      MessageRouter.send_to(connection_pid, packet)
      {:noreply, state}
    end
  end

  defp do_request_move(state, game_state, connection_pid, dest_x, dest_y, opts) do
    with {:ok, map_data} <- MapCache.get(game_state.map_name),
         {:ok, [_ | _] = path} <-
           Pathfinding.find_path(
             map_data,
             {game_state.x, game_state.y},
             {dest_x, dest_y}
           ) do
      state = dispatch_movement_intent(state, game_state)
      game_state = state.game_state

      # A manual move (no combat_initiated:/pickup_initiated: flag) while heading
      # to a target or item cancels that pending intent so the player can walk away.
      game_state = maybe_clear_action_intent(game_state, opts)

      # The full per-cell path is walked, never a simplified one: step_delay/3
      # prices one adjacent step, so hopping a collapsed straight segment in a
      # single tick would cross it at many times walk speed, racing far ahead of
      # the client's interpolation (and skipping over warp/trap cells).
      game_state = PlayerState.set_path(game_state, path)

      # Send movement confirmation to the client
      walk_start_time = System.monotonic_time(:millisecond)

      packet = %SelfMove{
        start_time: walk_start_time,
        src_x: game_state.x,
        src_y: game_state.y,
        dst_x: dest_x,
        dst_y: dest_y
      }

      MessageRouter.send_to(connection_pid, packet)

      # The first tick fires after the first step's cost, not immediately: a
      # unit enters a cell when the step completes, keeping the server position
      # in lockstep with the client's interpolation instead of one cell ahead.
      first_delay = step_delay(game_state, {game_state.x, game_state.y}, hd(path))
      Process.send_after(self(), {:movement, :movement_tick}, first_delay)

      {:noreply, %{state | game_state: game_state}}
    else
      {:ok, []} ->
        # Already at destination
        {:noreply, state}

      {:error, reason} ->
        # No path found or map not loaded
        Logger.error("Movement failed for player #{game_state.character_id}: #{inspect(reason)}")

        packet = %MoveStop{
          gid: game_state.character_id,
          x: game_state.x,
          y: game_state.y
        }

        MessageRouter.send_to(connection_pid, packet)

        {:noreply, state}
    end
  end

  defp dispatch_movement_intent(state, game_state) do
    position = %{map: game_state.map_name, x: game_state.x, y: game_state.y}

    case Interpreter.on_movement_intent(:player, game_state.character_id, position) do
      :changed -> StatusManager.recalculate_after_status_change(state)
      :unchanged -> state
    end
  end

  defp maybe_clear_action_intent(%{action_state: :combat_moving} = game_state, opts) do
    if Keyword.get(opts, :combat_initiated, false) do
      game_state
    else
      Logger.debug("Player manually moving while in combat, clearing combat intent")
      clear_intent_to_moving(game_state, &PlayerState.clear_combat_intent/1)
    end
  end

  defp maybe_clear_action_intent(%{action_state: :attacking} = game_state, opts) do
    if Keyword.get(opts, :combat_initiated, false) do
      game_state
    else
      Logger.debug("Player manually moving while attacking, clearing combat intent")
      clear_intent_to_moving(game_state, &PlayerState.clear_combat_intent/1)
    end
  end

  defp maybe_clear_action_intent(%{action_state: :skill_moving} = game_state, opts) do
    if Keyword.get(opts, :skill_initiated, false) do
      game_state
    else
      Logger.debug(
        "Player manually moving while heading to a skill target, clearing skill intent"
      )

      clear_intent_to_moving(game_state, &PlayerState.clear_skill_intent/1)
    end
  end

  defp maybe_clear_action_intent(%{action_state: :moving_to_item} = game_state, opts) do
    if Keyword.get(opts, :pickup_initiated, false) do
      game_state
    else
      Logger.debug("Player manually moving while heading to an item, clearing pickup intent")
      clear_intent_to_moving(game_state, &PlayerState.clear_pickup_intent/1)
    end
  end

  defp maybe_clear_action_intent(game_state, _opts), do: game_state

  defp clear_intent_to_moving(game_state, clear_fun) do
    game_state
    |> clear_fun.()
    |> PlayerState.transition_to(:moving)
    |> case do
      {:ok, transitioned} -> transitioned
      _ -> game_state
    end
  end

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
  Commits displacement only when the live session still matches its expected cell.
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
      {:noreply, %{state | game_state: game_state}}
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
    # using the same Manhattan-distance convention as the mob path
    # (`SpatialIndex.get_units_in_range`'s `distance/4`).
    warps_on_map =
      case Warps.for_map(game_state.map_name) do
        {:ok, list} -> list
        :error -> []
      end

    warps_in_range =
      Enum.filter(warps_on_map, fn warp ->
        manhattan(game_state.x, game_state.y, warp.x, warp.y) <= game_state.view_range
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
    # against `visible_npcs` by Manhattan distance vs `view_range`. A disabled
    # or hidden NPC (`Npc.Session.visible?/1`) is filtered out here, so the
    # diff never sends a spawn for one and drops it from `visible_npcs` (as a
    # vanish, if the player already had it visible) the moment it stops
    # qualifying — the flag flip itself is broadcast immediately by
    # `Npc.Session`, so a player standing still doesn't have to wait for this
    # diff to notice.
    npcs_in_range =
      Enum.filter(NpcRegistry.entries(), fn {_module, placement} ->
        placement.map == game_state.map_name and
          manhattan(game_state.x, game_state.y, placement.x, placement.y) <=
            game_state.view_range and
          NpcSession.visible?(NpcRegistry.entity_id(placement))
      end)

    npcs_by_id =
      Map.new(npcs_in_range, fn {_module, placement} ->
        {NpcRegistry.entity_id(placement), placement}
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
    # `visible_shops` by Manhattan distance vs `view_range`.
    shops_on_map =
      case Shops.for_map(game_state.map_name) do
        {:ok, list} -> list
        :error -> []
      end

    shops_in_range =
      Enum.filter(shops_on_map, fn shop ->
        manhattan(game_state.x, game_state.y, shop.x, shop.y) <= game_state.view_range
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

  defp manhattan(x1, y1, x2, y2), do: abs(x2 - x1) + abs(y2 - y1)

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
        speed: mob_state.walk_speed,
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
        clevel: mob_state.mob_data.level,
        max_hp: mob_state.max_hp,
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

  defp send_npc_spawn_packet_to(to_char_id, %Placement{} = placement) do
    case UnitRegistry.get_player_pid(to_char_id) do
      {:ok, to_pid} ->
        GenServer.cast(to_pid, {:send_packet, NpcPackets.spawn_packet(placement)})

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
