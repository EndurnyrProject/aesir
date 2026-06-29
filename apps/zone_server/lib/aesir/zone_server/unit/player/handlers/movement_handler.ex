defmodule Aesir.ZoneServer.Unit.Player.Handlers.MovementHandler do
  @moduledoc """
  Handles player movement operations including pathfinding, movement ticks, and broadcasting.
  Extracted from PlayerSession to improve modularity and maintainability.
  """

  require Logger

  alias Aesir.Net.MoveStop
  alias Aesir.Net.SelfMove
  alias Aesir.Net.UnitDespawn
  alias Aesir.Net.UnitSpawn
  alias Aesir.ZoneServer.Constants.DespawnReason
  alias Aesir.ZoneServer.Constants.ObjectType
  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.StatusDisplay
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Npc.Placement
  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry
  alias Aesir.ZoneServer.Npc.Shop
  alias Aesir.ZoneServer.Npc.Shops
  alias Aesir.ZoneServer.Npc.Warp
  alias Aesir.ZoneServer.Npc.Warps
  alias Aesir.ZoneServer.Pathfinding
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Movement
  alias Aesir.ZoneServer.Unit.MovementEngine
  alias Aesir.ZoneServer.Unit.Player.Handlers.SkillHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
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
    send(self(), :movement_completed)

    {:noreply, updated_state}
  end

  def handle_movement_tick(%{game_state: game_state} = state)
      when game_state.movement_state == :moving do
    if Interpreter.can_move?(:player, game_state.character_id) do
      step_walk_path(state, game_state)
    else
      stop_restricted_walk(state, game_state)
    end
  end

  defp step_walk_path(state, game_state) do
    case game_state.walk_path do
      [{next_x, next_y} | _] = walk_path ->
        if next_cell_walkable?(game_state.map_name, next_x, next_y) do
          step_player(state, game_state, {next_x, next_y}, tl(walk_path))
        else
          handle_blocked_player(state, game_state, List.last(walk_path))
        end
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
    # Timer interval from the live walk_speed and the per-cell movement cost.
    interval =
      MovementEngine.step_delay(
        game_state.walk_speed,
        {game_state.x, game_state.y},
        {next_x, next_y}
      )

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

    # Handle visibility updates
    updated_game_state = handle_visibility_update(updated_game_state)

    case maybe_trigger_warp(updated_game_state, next_x, next_y) do
      {:warp_fired, marked_state} ->
        {:noreply, %{state | game_state: marked_state}}

      :no_warp ->
        # Schedule next movement tick with appropriate interval
        if remaining_path != [] do
          Process.send_after(self(), :movement_tick, interval)
          {:noreply, %{state | game_state: updated_game_state}}
        else
          # Path completed: stop and broadcast the standing transition so the
          # client's last snapshot sample flips move_state back to idle.
          game_state = PlayerState.stop_walking(updated_game_state)

          Movement.set_position(
            :player,
            game_state.character_id,
            game_state,
            game_state.map_name
          )

          # Send completion message for PlayerSession to handle
          send(self(), :movement_completed)
          {:noreply, %{state | game_state: game_state}}
        end
    end
  end

  # On-touch warp trigger hook (rAthena `OnTouch`, cell-enter).
  #
  # Fires after the player has stepped onto `(x, y)`: if that cell sits inside a
  # warp's `xs/ys` area, cancel the remaining walk and cast `{:warp, …}` to the
  # session — reusing the existing map-warp cast (zero new plumbing). The
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

          GenServer.cast(self(), {:warp, warp.to_map, warp.to_x, warp.to_y})

          {:warp_fired, marked}
        end

      nil ->
        :no_warp
    end
  end

  defp handle_blocked_player(state, game_state, destination) do
    with {:ok, map_data} <- MapCache.get(game_state.map_name),
         {:ok, [_ | _] = path} <-
           Pathfinding.find_path(map_data, {game_state.x, game_state.y}, destination) do
      game_state = PlayerState.set_path(game_state, Pathfinding.simplify_path(path))
      Process.send_after(self(), :movement_tick, 0)
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

  defp next_cell_walkable?(map_name, x, y) do
    case MapCache.get(map_name) do
      {:ok, map_data} -> MapData.walkable?(map_data, x, y)
      {:error, _} -> false
    end
  end

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

  def handle_request_move(%{game_state: %{action_state: :casting}} = state, dest_x, dest_y, opts) do
    state
    |> SkillHandler.cancel_cast(:move)
    |> handle_request_move(dest_x, dest_y, opts)
  end

  def handle_request_move(
        %{game_state: game_state, connection_pid: connection_pid} = state,
        dest_x,
        dest_y,
        opts
      ) do
    if Interpreter.can_move?(:player, game_state.character_id) do
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
      # Simplify path to reduce network traffic
      simplified_path = Pathfinding.simplify_path(path)

      # Check if we're in combat_moving state and this is a player-initiated move
      # Only clear combat intent if this is NOT a combat-initiated movement
      is_combat_initiated = Keyword.get(opts, :combat_initiated, false)

      game_state = maybe_clear_combat_intent(game_state, is_combat_initiated)

      # Update game state with new path
      game_state = PlayerState.set_path(game_state, simplified_path)

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

      # Schedule first movement tick immediately to start movement
      Process.send_after(self(), :movement_tick, 0)

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

  defp maybe_clear_combat_intent(%{action_state: :combat_moving} = game_state, false) do
    Logger.debug("Player manually moving while in combat, clearing combat intent")

    game_state
    |> PlayerState.clear_combat_intent()
    |> PlayerState.transition_to(:moving)
    |> case do
      {:ok, transitioned} -> transitioned
      _ -> game_state
    end
  end

  defp maybe_clear_combat_intent(game_state, _is_combat_initiated), do: game_state

  @doc """
  Forces a player to stop moving immediately.

  ## Parameters
    - state: The player session state
    
  ## Returns
    - {:noreply, updated_state} - Updated state with stopped movement
  """
  def handle_force_stop_movement(
        %{game_state: game_state, connection_pid: connection_pid} = state
      ) do
    if game_state.movement_state == :moving do
      game_state = PlayerState.stop_walking(game_state)

      packet = %MoveStop{
        gid: game_state.character_id,
        x: game_state.x,
        y: game_state.y
      }

      MessageRouter.send_to(connection_pid, packet)

      broadcast_stop_to_nearby(game_state, packet)

      {:noreply, %{state | game_state: game_state}}
    else
      {:noreply, state}
    end
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

    # Send spawn packets for newly visible mobs
    Enum.each(now_visible_mobs, fn mob_id ->
      send_mob_spawn_packet_to(game_state.character_id, mob_id)
    end)

    # Send despawn packets for now hidden mobs
    Enum.each(now_hidden_mobs, fn mob_id ->
      send_mob_vanish_packet_to(game_state.character_id, mob_id)
    end)

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
    # against `visible_npcs` by Manhattan distance vs `view_range`.
    npcs_in_range =
      Enum.filter(NpcRegistry.entries(), fn {_module, placement} ->
        placement.map == game_state.map_name and
          manhattan(game_state.x, game_state.y, placement.x, placement.y) <=
            game_state.view_range
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

    # Update game state with new visibility info
    # Keep last_visibility_cell for potential optimization later
    current_cell = {div(game_state.x, 8), div(game_state.y, 8)}

    %{
      game_state
      | visible_players: new_visible,
        visible_mobs: new_visible_mobs,
        visible_warps: new_visible_warps,
        visible_npcs: new_visible_npcs,
        visible_shops: new_visible_shops,
        last_visibility_cell: current_cell
    }
  end

  defp manhattan(x1, y1, x2, y2), do: abs(x2 - x1) + abs(y2 - y1)

  defp send_spawn_packet_about(to_char_id, about_char_id) do
    # Get the player session for the target
    case UnitRegistry.get_player_pid(to_char_id) do
      {:ok, pid} ->
        GenServer.cast(pid, {:player_entered_view, about_char_id})

      {:error, :not_found} ->
        :ok
    end
  end

  defp send_vanish_packet_to(to_char_id, about_char_id) do
    # Get the player session for the target and the account_id of the vanishing player
    with {:ok, to_pid} <- UnitRegistry.get_player_pid(to_char_id),
         {:ok, {_about_pid, about_account_id}} <-
           UnitRegistry.get_player_with_account(about_char_id) do
      GenServer.cast(to_pid, {:player_left_view, about_char_id, about_account_id})
    else
      _ -> :ok
    end
  end

  defp send_mob_spawn_packet_to(to_char_id, mob_id) do
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

      GenServer.cast(to_pid, {:send_packet, mob_packet})

      :mob
      |> StatusDisplay.active_icons(mob_state.instance_id)
      |> Enum.each(&Broadcast.to_player(to_char_id, &1))
    else
      _ -> :ok
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
        npc_entity_id = NpcRegistry.entity_id(placement)

        packet = %UnitSpawn{
          object_type: ObjectType.npc(),
          aid: npc_entity_id,
          gid: npc_entity_id,
          speed: 0,
          body_state: 0,
          health_state: 0,
          effect_state: 0,
          job: placement.sprite,
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
          x: placement.x,
          y: placement.y,
          dir: placement.dir,
          clevel: 0,
          max_hp: 0,
          hp: 0,
          is_boss: false,
          name: placement.name,
          moving: false
        }

        GenServer.cast(to_pid, {:send_packet, packet})

      {:error, :not_found} ->
        :ok
    end
  end

  defp send_npc_vanish_packet_to(to_char_id, npc_entity_id) do
    case UnitRegistry.get_player_pid(to_char_id) do
      {:ok, to_pid} ->
        vanish_packet = %UnitDespawn{
          gid: npc_entity_id,
          reason: DespawnReason.out_of_sight()
        }

        GenServer.cast(to_pid, {:send_packet, vanish_packet})

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
end
