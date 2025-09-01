defmodule Aesir.ZoneServer.Unit.Mob.MobSession do
  @moduledoc """
  GenServer managing a single mob's session and state.

  Similar to PlayerSession but for mobs with AI behavior, movement, and combat.
  Each mob instance runs as its own process with independent AI logic.
  """

  use GenServer
  require Logger

  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Unit.Mob.AIStateMachine
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.SpatialIndex

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

    # Schedule first AI tick
    schedule_ai_tick()

    Logger.debug(
      "Started mob session for #{updated_state.mob_data.sprite_name} (ID: #{updated_state.instance_id})"
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
    # Simple direct movement - in future this could use pathfinding
    path = [{x, y}]

    updated_state =
      state
      |> MobState.set_path(path)
      |> MobState.update_position(x, y)

    # Update spatial index
    :ok = SpatialIndex.update_unit_position(:mob, state.instance_id, x, y, state.map_name)

    {:noreply, updated_state}
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
  def terminate(_reason, state) do
    # Clean up spatial index registration
    SpatialIndex.remove_unit(:mob, state.instance_id)

    Logger.debug(
      "Stopped mob session for #{state.mob_data.sprite_name} (ID: #{state.instance_id})"
    )

    :ok
  end

  # Private Functions

  defp maybe_add_aggro(state, nil, _damage), do: state

  defp maybe_add_aggro(state, attacker_id, damage) do
    MobState.add_aggro(state, attacker_id, damage)
  end

  defp handle_death(state) do
    Logger.info("Mob #{state.mob_data.sprite_name} (ID: #{state.instance_id}) died")

    # Mark as dead
    updated_state = MobState.set_dead(state)

    # Notify coordinator of death for respawn scheduling
    Coordinator.mob_died(state.map_name, state.instance_id)

    # Schedule process termination after a brief delay to handle cleanup
    Process.send_after(self(), :terminate, 1000)

    {:noreply, updated_state}
  end

  defp process_ai(state) do
    AIStateMachine.process_ai(state)
  end

  # AI logic is now handled by AIStateMachine module

  defp schedule_ai_tick do
    Process.send_after(self(), :ai_tick, @ai_tick_interval)
  end
end
