defmodule Aesir.ZoneServer.Unit.Player.Handlers.StatsManager do
  @moduledoc """
  Handles player stats operations including calculations, updates, and client synchronization.
  Extracted from PlayerSession to improve modularity and maintainability.
  """

  require Logger

  alias Aesir.ZoneServer.Unit.Player.Handlers.PacketHandler
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @doc """
  Handles sending a single status update to the client.

  ## Parameters
    - param_id: The status parameter ID
    - value: The new value
    - state: The player session state
    
  ## Returns
    - {:noreply, state} - State unchanged
  """
  def handle_send_status_update(param_id, value, %{connection_pid: connection_pid} = state) do
    packet = PacketHandler.build_status_packet(param_id, value)
    send(connection_pid, {:send_packet, packet})
    {:noreply, state}
  end

  @doc """
  Handles sending multiple status updates to the client efficiently.

  ## Parameters
    - status_map: Map of param_id => value pairs
    - state: The player session state
    
  ## Returns
    - {:noreply, state} - State unchanged
  """
  def handle_send_status_updates(status_map, %{connection_pid: connection_pid} = state) do
    Enum.each(status_map, fn {param_id, value} ->
      packet = PacketHandler.build_status_packet(param_id, value)
      send(connection_pid, {:send_packet, packet})
    end)

    {:noreply, state}
  end

  @doc """
  Handles asynchronous stats recalculation.

  ## Parameters
    - state: The player session state
    
  ## Returns
    - {:noreply, updated_state} - Updated state with recalculated stats
  """
  def handle_recalculate_stats(%{character: character} = state) do
    # Recalculate stats with player ID for status effects
    updated_stats = Stats.calculate_stats(state.game_state.stats, character.id)

    # Only update and send changes if stats actually changed
    if updated_stats != state.game_state.stats do
      updated_game_state = %{state.game_state | stats: updated_stats}
      PacketHandler.send_stat_updates(state.connection_pid, updated_stats)

      {:noreply, update_game_state(state, updated_game_state)}
    else
      # No changes, skip update
      {:noreply, state}
    end
  end

  @doc """
  Handles updating a base stat and recalculating derived stats.

  ## Parameters
    - stat_name: The stat to update (:str, :agi, :vit, :int, :dex, :luk)
    - new_value: The new value for the stat
    - state: The player session state
    
  ## Returns
    - {:reply, :ok, updated_state} - Success with updated state
  """
  def handle_update_base_stat(stat_name, new_value, %{character: character} = state) do
    stats = state.game_state.stats
    updated_base_stats = Map.put(stats.base_stats, stat_name, new_value)
    updated_stats = %{stats | base_stats: updated_base_stats}
    updated_stats = Stats.calculate_stats(updated_stats, character.id)
    updated_game_state = %{state.game_state | stats: updated_stats}
    updated_state = %{state | game_state: updated_game_state}

    PacketHandler.send_stat_updates(state.connection_pid, updated_stats)

    {:reply, :ok, updated_state}
  end

  @doc """
  Handles synchronous stats recalculation.

  ## Parameters
    - state: The player session state
    
  ## Returns
    - {:reply, updated_stats, updated_state} - Returns recalculated stats
  """
  def handle_sync_recalculate_stats(%{character: character} = state) do
    updated_stats = Stats.calculate_stats(state.game_state.stats, character.id)
    updated_game_state = %{state.game_state | stats: updated_stats}
    updated_state = %{state | game_state: updated_game_state}

    PacketHandler.send_stat_updates(state.connection_pid, updated_stats)

    {:reply, updated_stats, updated_state}
  end

  @doc """
  Handles getting current stats.

  ## Parameters
    - state: The player session state
    
  ## Returns
    - {:reply, stats, state} - Returns current stats
  """
  def handle_get_current_stats(state) do
    {:reply, state.game_state.stats, state}
  end

  def update_game_state(state, new_game_state) do
    UnitRegistry.update_unit_state(:player, state.character.id, new_game_state)

    %{state | game_state: new_game_state}
  end
end
