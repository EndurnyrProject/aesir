defmodule Aesir.ZoneServer.Unit.Mob.MobSession do
  @moduledoc """
  GenServer managing a single mob's session and state.

  Similar to PlayerSession but for mobs with AI behavior, movement, and combat.
  Each mob instance runs as its own process with independent AI logic.
  """

  use GenServer
  require Logger

  alias Aesir.ZoneServer.Constants.ObjectType
  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Packets.ZcNotifyMoveentry
  alias Aesir.ZoneServer.Packets.ZcNotifyNewentry
  alias Aesir.ZoneServer.Packets.ZcNotifyVanish
  alias Aesir.ZoneServer.Pathfinding
  alias Aesir.ZoneServer.Unit.Mob.AIStateMachine
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.MovementEngine
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  # AI tick interval in milliseconds
  @ai_tick_interval 1000

  # Public API

  @doc """
  Starts a mob session.
  """
  @spec start_link(map()) :: GenServer.on_start()
  def start_link(%{state: _mob_state} = args) do
    GenServer.start_link(__MODULE__, args)
  end

  @doc """
  Applies damage to the mob.
  """
  @spec apply_damage(pid(), integer(), integer() | nil) :: :ok
  def apply_damage(pid, damage, attacker_id \\ nil) do
    GenServer.cast(pid, {:apply_damage, damage, attacker_id})
  end

  @doc """
  Heals the mob.
  """
  @spec heal(pid(), integer()) :: :ok
  def heal(pid, amount) do
    GenServer.cast(pid, {:heal, amount})
  end

  @doc """
  Gets the current mob state.
  """
  @spec get_state(pid()) :: MobState.t()
  def get_state(pid) do
    GenServer.call(pid, :get_state)
  end

  @doc """
  Forces the mob to move to a target position.
  """
  @spec move_to(pid(), integer(), integer()) :: :ok
  def move_to(pid, x, y) do
    GenServer.cast(pid, {:move_to, x, y})
  end

  @doc """
  Sets the mob's AI target.
  """
  @spec set_target(pid(), integer() | nil) :: :ok
  def set_target(pid, target_id) do
    GenServer.cast(pid, {:set_target, target_id})
  end

  @doc """
  Stops the mob session.
  """
  @spec stop(pid()) :: :ok
  def stop(pid) do
    GenServer.stop(pid, :normal)
  end

  # GenServer Callbacks

  @impl GenServer
  def init(%{state: mob_state}) do
    # Set this process as the mob's process
    updated_state = MobState.set_process_pid(mob_state, self())

    # Register in spatial index
    :ok =
      SpatialIndex.add_unit(
        :mob,
        updated_state.instance_id,
        updated_state.x,
        updated_state.y,
        updated_state.map_name
      )

    # Notify nearby players of mob spawn
    notify_spawn(updated_state)

    # Schedule first AI tick
    schedule_ai_tick()

    Logger.debug(
      "Started mob session for #{updated_state.mob_data.name} (ID: #{updated_state.instance_id})"
    )

    {:ok, updated_state}
  end

  @impl GenServer
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl GenServer
  def handle_cast({:apply_damage, damage, attacker_id}, state) do
    {updated_mob, status} = MobState.apply_damage(state, damage)
    current_time = System.system_time(:second)

    # Update last damage time and add aggro if attacker provided
    updated_mob =
      updated_mob
      |> Map.put(:last_damage_time, current_time)
      |> maybe_add_aggro(attacker_id, damage)
      |> AIStateMachine.handle_damage_reaction(attacker_id)

    case status do
      :alive ->
        {:noreply, updated_mob}

      :dead ->
        handle_death(updated_mob)
    end
  end

  @impl GenServer
  def handle_cast({:heal, amount}, state) do
    updated_state = MobState.heal(state, amount)
    {:noreply, updated_state}
  end

  @impl GenServer
  def handle_cast({:move_to, x, y}, state) do
    # Don't start new movement if already moving
    if state.movement_state == :moving do
      {:noreply, state}
    else
      with {:ok, map_data} <- MapCache.get(state.map_name),
           {:ok, [_ | _] = path} <-
             Pathfinding.find_path(
               map_data,
               {state.x, state.y},
               {x, y}
             ) do
        # Simplify path to reduce computation
        simplified_path = Pathfinding.simplify_path(path)

        # Set the movement path
        updated_state = MobState.set_path(state, simplified_path)

        # Schedule first movement tick
        Process.send_after(self(), :movement_tick, 100)

        {:noreply, updated_state}
      else
        {:ok, []} ->
          # Already at destination
          {:noreply, state}

        {:error, reason} ->
          # No path found or map not loaded
          Logger.warning(
            "Movement failed for mob #{state.mob_data.name} (ID: #{state.instance_id}): #{inspect(reason)}"
          )

          {:noreply, state}
      end
    end
  end

  @impl GenServer
  def handle_cast({:set_target, target_id}, state) do
    updated_state =
      state
      |> MobState.set_target(target_id)
      |> MobState.set_ai_state(if target_id, do: :combat, else: :idle)

    {:noreply, updated_state}
  end

  @impl GenServer
  def handle_info(:ai_tick, state) do
    unless state.is_dead do
      # Process AI logic
      updated_state = process_ai(state)

      # Schedule next AI tick
      schedule_ai_tick()

      {:noreply, updated_state}
    else
      # Dead mobs don't process AI
      {:noreply, state}
    end
  end

  @impl GenServer
  def handle_info(:movement_tick, state) do
    unless state.is_dead do
      # Process movement if mob is moving
      updated_state = process_movement_tick(state)
      {:noreply, updated_state}
    else
      # Dead mobs don't move
      {:noreply, state}
    end
  end

  @impl GenServer
  def terminate(_reason, state) do
    # Clean up spatial index registration
    SpatialIndex.remove_unit(:mob, state.instance_id)

    Logger.debug("Stopped mob session for #{state.mob_data.name} (ID: #{state.instance_id})")

    :ok
  end

  # Private Functions

  defp maybe_add_aggro(state, nil, _damage), do: state

  defp maybe_add_aggro(state, attacker_id, damage) do
    MobState.add_aggro(state, attacker_id, damage)
  end

  defp handle_death(state) do
    Logger.info("Mob #{state.mob_data.name} (ID: #{state.instance_id}) died")

    # Mark as dead
    updated_state = MobState.set_dead(state)

    # Notify nearby players of mob death
    notify_despawn(updated_state)

    # Notify coordinator of death for respawn scheduling
    Coordinator.mob_died(state.map_name, state.instance_id)

    # Schedule process termination after a brief delay to handle cleanup
    Process.send_after(self(), :terminate, 1000)

    {:noreply, updated_state}
  end

  defp process_ai(state) do
    AIStateMachine.process_ai(state)
  end

  defp process_movement_tick(%{movement_state: :standing} = state) do
    state
  end

  defp process_movement_tick(%{movement_state: :moving, walk_path: []} = state) do
    MobState.stop_movement(state)
  end

  defp process_movement_tick(%{movement_state: :moving} = state) do
    # Calculate movement budget like player system
    elapsed = System.system_time(:millisecond) - state.walk_start_time
    total_movement_budget = MovementEngine.calculate_movement_budget(elapsed, state.walk_speed)
    new_movement_budget = total_movement_budget - state.path_progress

    # Consume path based on movement budget
    {new_x, new_y, remaining_path, consumed} =
      MovementEngine.consume_path_with_budget(
        state.x,
        state.y,
        state.walk_path,
        new_movement_budget
      )

    # Update position and state if moved
    updated_state =
      if new_x != state.x or new_y != state.y do
        # Update spatial index
        :ok =
          SpatialIndex.update_unit_position(:mob, state.instance_id, new_x, new_y, state.map_name)

        # Update mob state
        updated_state =
          state
          |> MobState.update_position(new_x, new_y)
          |> Map.put(:walk_path, remaining_path)
          |> Map.put(:path_progress, state.path_progress + consumed)

        # Notify nearby players of movement
        notify_movement(updated_state, {state.x, state.y}, {new_x, new_y})
        updated_state
      else
        # No position change, just update path and progress
        state
        |> Map.put(:walk_path, remaining_path)
        |> Map.put(:path_progress, state.path_progress + consumed)
      end

    # Continue movement if more path remaining
    if remaining_path != [] do
      Process.send_after(self(), :movement_tick, 100)
      updated_state
    else
      # Path completed, stop movement
      MobState.stop_movement(updated_state)
    end
  end

  # AI logic is now handled by AIStateMachine module

  defp schedule_ai_tick do
    Process.send_after(self(), :ai_tick, @ai_tick_interval)
  end

  # Mob Visibility Helper Functions

  defp notify_spawn(%MobState{} = mob_state) do
    packet = create_spawn_packet(mob_state)
    broadcast_to_nearby_players(mob_state, packet)
    {:ok, packet}
  end

  defp notify_movement(%MobState{} = mob_state, {src_x, src_y}, {dst_x, dst_y}) do
    packet = create_movement_packet(mob_state, src_x, src_y, dst_x, dst_y)
    broadcast_to_nearby_players(mob_state, packet)
    {:ok, packet}
  end

  defp notify_despawn(%MobState{} = mob_state) do
    packet = %ZcNotifyVanish{
      gid: mob_state.instance_id,
      # 0 = died, 1 = logged out, 2 = teleported
      type: 0
    }

    broadcast_to_nearby_players(mob_state, packet)
    {:ok, packet}
  end

  defp create_spawn_packet(%MobState{} = mob_state) do
    %ZcNotifyNewentry{
      object_type: ObjectType.mob(),
      aid: mob_state.instance_id,
      gid: mob_state.instance_id,
      speed: mob_state.walk_speed,
      body_state: 0,
      health_state: if(mob_state.is_dead, do: 1, else: 0),
      effect_state: 0,
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
      guild_emblem_ver: 0,
      honor: 0,
      virtue: 0,
      is_pk_mode_on: 0,
      sex: 0,
      x: mob_state.x,
      y: mob_state.y,
      dir: mob_state.dir,
      x_size: 0,
      y_size: 0,
      clevel: mob_state.mob_data.level,
      font: 0,
      max_hp: mob_state.max_hp,
      hp: mob_state.hp,
      is_boss: if(MobState.is_boss?(mob_state), do: 1, else: 0),
      body: 0,
      name: mob_state.mob_data.name
    }
  end

  defp create_movement_packet(%MobState{} = mob_state, src_x, src_y, dst_x, dst_y) do
    %ZcNotifyMoveentry{
      object_type: ObjectType.mob(),
      aid: mob_state.instance_id,
      gid: mob_state.instance_id,
      speed: mob_state.walk_speed,
      body_state: 0,
      health_state: if(mob_state.is_dead, do: 1, else: 0),
      effect_state: 0,
      # Mob sprite ID
      job: mob_state.mob_id,
      head: 0,
      weapon: 0,
      shield: 0,
      accessory: 0,
      move_start_time: System.system_time(:millisecond),
      accessory2: 0,
      accessory3: 0,
      head_palette: 0,
      body_palette: 0,
      head_dir: 0,
      robe: 0,
      guild_id: 0,
      guild_emblem_ver: 0,
      honor: 0,
      virtue: 0,
      is_pk_mode_on: 0,
      sex: 0,
      src_x: src_x,
      src_y: src_y,
      dst_x: dst_x,
      dst_y: dst_y,
      x_size: 0,
      y_size: 0,
      clevel: mob_state.mob_data.level,
      font: 0,
      max_hp: mob_state.max_hp,
      hp: mob_state.hp,
      is_boss: if(MobState.is_boss?(mob_state), do: 1, else: 0),
      body: 0,
      name: mob_state.mob_data.name
    }
  end

  # Broadcasting Helper Functions

  defp broadcast_to_nearby_players(%MobState{} = mob_state, packet) do
    # Get players in range using the mob's map name
    # Map names should be normalized at load time to avoid inconsistencies
    nearby_players =
      SpatialIndex.get_players_in_range(
        mob_state.map_name,
        mob_state.x,
        mob_state.y,
        mob_state.view_range
      )

    Enum.each(nearby_players, &send_packet_to_player(&1, packet))
  end

  defp send_packet_to_player(char_id, packet) do
    case UnitRegistry.get_player_pid(char_id) do
      {:ok, pid} ->
        GenServer.cast(pid, {:send_packet, packet})

      {:error, :not_found} ->
        :ok
    end
  end
end
