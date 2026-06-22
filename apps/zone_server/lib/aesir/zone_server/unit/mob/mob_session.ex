defmodule Aesir.ZoneServer.Unit.Mob.MobSession do
  @moduledoc """
  GenServer managing a single mob's session and state.

  Similar to PlayerSession but for mobs with AI behavior, movement, and combat.
  Each mob instance runs as its own process with independent AI logic.
  """

  use GenServer

  alias Aesir.Net.UnitDespawn
  alias Aesir.Net.UnitHp
  alias Aesir.Net.UnitSpawn
  alias Aesir.ZoneServer.Constants.DespawnReason
  alias Aesir.ZoneServer.Constants.ObjectType
  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Pathfinding
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.AIStateMachine
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Movement
  alias Aesir.ZoneServer.Unit.MovementEngine
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Phoenix.PubSub

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
  Marks the mob as having been stolen from.
  """
  @spec mark_stolen(pid()) :: :ok
  def mark_stolen(pid) do
    GenServer.cast(pid, {:mark_stolen})
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

    # Send HP update packet to nearby players
    notify_hp_update(updated_mob)

    case status do
      :alive ->
        {:noreply, updated_mob}

      :dead ->
        handle_death(updated_mob, attacker_id)
    end
  end

  @impl GenServer
  def handle_cast({:heal, amount}, state) do
    updated_state = MobState.heal(state, amount)

    # Send HP update packet to nearby players
    notify_hp_update(updated_state)

    {:noreply, updated_state}
  end

  @impl GenServer
  def handle_cast({:move_to, x, y}, state) do
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
        updated_state = MobState.set_path(state, path)

        # Schedule first movement tick immediately to start movement
        Process.send_after(self(), :movement_tick, 0)

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

  @impl GenServer
  def handle_cast({:set_target, target_id}, state) do
    updated_state =
      state
      |> MobState.set_target(target_id)
      |> MobState.set_ai_state(if target_id, do: :combat, else: :idle)

    {:noreply, updated_state}
  end

  @impl GenServer
  def handle_cast({:mark_stolen}, state) do
    updated_state = MobState.mark_stolen(state)
    {:noreply, updated_state}
  end

  @impl GenServer
  def handle_cast({:knocked_back, x, y}, state) do
    updated_state =
      state
      |> MobState.update_position(x, y)
      |> MobState.stop_movement()

    Movement.set_position(:mob, updated_state.instance_id, updated_state, updated_state.map_name)

    {:noreply, updated_state}
  end

  @impl GenServer
  def handle_info(:ai_tick, state) do
    if state.is_dead do
      # Dead mobs don't process AI
      {:noreply, state}
    else
      # Process AI logic
      updated_state = process_ai(state)

      # Schedule next AI tick
      schedule_ai_tick()

      {:noreply, updated_state}
    end
  end

  @impl GenServer
  def handle_info(:movement_tick, state) do
    if state.is_dead do
      # Dead mobs don't move
      {:noreply, state}
    else
      # Process movement if mob is moving
      updated_state = process_movement_tick(state)
      {:noreply, updated_state}
    end
  end

  @impl GenServer
  def handle_info(:terminate, state) do
    {:stop, :normal, state}
  end

  @impl GenServer
  def terminate(_reason, state) do
    SpatialIndex.remove_unit(:mob, state.instance_id)
    Broadcast.publish_mob_despawn(state.map_name, state.instance_id)
    :ok
  end

  # Private Functions

  defp maybe_add_aggro(state, nil, _damage), do: state

  defp maybe_add_aggro(state, attacker_id, damage) do
    MobState.add_aggro(state, attacker_id, damage)
  end

  defp handle_death(state, attacker_id) do
    # Mark as dead
    updated_state = MobState.set_dead(state)

    # Notify nearby players of mob death
    notify_despawn(updated_state)

    announce_kill(state, attacker_id)

    # Notify coordinator of death for respawn scheduling
    Coordinator.mob_died(state.map_name, state.instance_id)

    # Schedule process termination after a brief delay to handle cleanup
    Process.send_after(self(), :terminate, 1000)

    {:noreply, updated_state}
  end

  # Publishes the kill so consumers (the killer's session for experience today,
  # drops/quests later) can react. The mob stays ignorant of who listens; an
  # absent killer simply has no subscriber.
  #
  # only the killing blow is credited. Add aggro-proportional and
  # party-shared rewards once parties exist.
  defp announce_kill(_state, nil), do: :ok

  defp announce_kill(%MobState{mob_data: mob_data}, attacker_id) do
    PubSub.broadcast(
      Aesir.PubSub,
      "player:#{attacker_id}",
      {:mob_killed,
       %{mob_id: mob_data.id, base_exp: mob_data.base_exp, job_exp: mob_data.job_exp}}
    )
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
    case state.walk_path do
      [{next_x, next_y} | _] = walk_path ->
        if next_cell_walkable?(state.map_name, next_x, next_y) do
          step_mob(state, {next_x, next_y}, tl(walk_path))
        else
          handle_blocked_mob(state, List.last(walk_path))
        end
    end
  end

  defp step_mob(state, {next_x, next_y}, remaining_path) do
    # Timer interval from the live walk_speed and the per-cell movement cost.
    interval =
      MovementEngine.step_delay(state.walk_speed, {state.x, state.y}, {next_x, next_y})

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

    # Schedule next movement tick with appropriate interval
    if remaining_path != [] do
      Process.send_after(self(), :movement_tick, interval)
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
           Pathfinding.find_path(map_data, {state.x, state.y}, destination) do
      updated_state = MobState.set_path(state, path)
      Process.send_after(self(), :movement_tick, 0)
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

  defp next_cell_walkable?(map_name, x, y) do
    case MapCache.get(map_name) do
      {:ok, map_data} -> MapData.walkable?(map_data, x, y)
      {:error, _} -> false
    end
  end

  # AI logic is now handled by AIStateMachine module

  defp schedule_ai_tick do
    Process.send_after(self(), :ai_tick, @ai_tick_interval)
  end

  # Mob Visibility Helper Functions

  defp notify_hp_update(%MobState{} = mob_state) do
    packet = %UnitHp{
      id: mob_state.instance_id,
      hp: max(0, mob_state.hp),
      max_hp: max(1, mob_state.max_hp)
    }

    broadcast_to_nearby_players(mob_state, packet)
    {:ok, packet}
  end

  defp notify_spawn(%MobState{} = mob_state) do
    packet = create_spawn_packet(mob_state)
    broadcast_to_nearby_players(mob_state, packet)
    {:ok, packet}
  end

  defp notify_despawn(%MobState{} = mob_state) do
    packet = %UnitDespawn{
      gid: mob_state.instance_id,
      reason: DespawnReason.died()
    }

    broadcast_to_nearby_players(mob_state, packet)
    {:ok, packet}
  end

  defp create_spawn_packet(%MobState{} = mob_state) do
    %UnitSpawn{
      object_type: ObjectType.mob(),
      aid: mob_state.instance_id,
      gid: mob_state.instance_id,
      speed: mob_state.walk_speed,
      body_state: 0,
      health_state: if(mob_state.is_dead, do: 1, else: 0),
      effect_state: 0,
      job: mob_state.mob_id,
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
  end

  # Broadcasting Helper Functions

  defp broadcast_to_nearby_players(%MobState{} = mob_state, packet) do
    Broadcast.to_in_range(
      mob_state.map_name,
      mob_state.x,
      mob_state.y,
      mob_state.view_range,
      packet
    )
  end
end
