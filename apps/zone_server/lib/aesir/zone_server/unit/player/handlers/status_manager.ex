defmodule Aesir.ZoneServer.Unit.Player.Handlers.StatusManager do
  @moduledoc """
  Handles player status effect operations including application, removal, and queries.
  Extracted from PlayerSession to improve modularity and maintainability.
  """

  require Logger

  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.Handlers.PacketHandler
  alias Aesir.ZoneServer.Unit.Player.Stats

  @doc """
  Handles applying a status effect to the player.

  ## Parameters
    - status_id: The status effect ID
    - val1-val4: Status effect parameters
    - tick: Tick duration
    - flag: Status flags
    - caster_id: ID of the entity that applied the status
    - state: The player session state
    
  ## Returns
    - {:reply, :ok, updated_state} - Success with stat recalculation
    - {:reply, {:error, reason}, state} - Failure (e.g., immunity)
  """
  def handle_apply_status(
        status_id,
        val1,
        val2,
        val3,
        val4,
        tick,
        flag,
        caster_id,
        %{character: character} = state
      ) do
    case Interpreter.apply_status(
           :player,
           character.id,
           status_id,
           val1,
           val2,
           val3,
           val4,
           tick,
           flag,
           caster_id
         ) do
      :ok ->
        # Recalculate stats with status effects
        updated_stats = Stats.calculate_stats(state.game_state.stats, character.id)
        updated_game_state = %{state.game_state | stats: updated_stats}

        # Send stat updates to client if they changed
        if updated_stats != state.game_state.stats do
          PacketHandler.send_stat_updates(state.connection_pid, updated_stats)
        end

        {:reply, :ok, %{state | game_state: updated_game_state}}

      {:error, reason} ->
        # Status application failed for some reason (e.g., immunity)
        {:reply, {:error, reason}, state}
    end
  end

  @doc """
  Handles removing a status effect from the player.

  ## Parameters
    - status_id: The status effect ID to remove
    - state: The player session state
    
  ## Returns
    - {:reply, :ok, updated_state} - Success with stat recalculation
  """
  def handle_remove_status(status_id, %{character: character} = state) do
    # Remove the status effect
    Interpreter.remove_status(:player, character.id, status_id)

    # Recalculate stats without this status effect
    updated_stats = Stats.calculate_stats(state.game_state.stats, character.id)
    updated_game_state = %{state.game_state | stats: updated_stats}

    # Send stat updates to client if they changed
    if updated_stats != state.game_state.stats do
      PacketHandler.send_stat_updates(state.connection_pid, updated_stats)
    end

    {:reply, :ok, %{state | game_state: updated_game_state}}
  end

  @doc """
  Handles getting all active status effects for the player.

  ## Parameters
    - state: The player session state
    
  ## Returns
    - {:reply, statuses, state} - Returns list of active statuses
  """
  def handle_get_active_statuses(%{character: character} = state) do
    statuses = StatusStorage.get_unit_statuses(:player, character.id)
    {:reply, statuses, state}
  end

  @doc """
  Handles checking if a player has a specific status effect.

  ## Parameters
    - status_id: The status effect ID to check
    - state: The player session state
    
  ## Returns
    - {:reply, has_status, state} - Returns boolean indicating presence
  """
  def handle_has_status(status_id, %{character: character} = state) do
    has_status = StatusStorage.has_status?(:player, character.id, status_id)
    {:reply, has_status, state}
  end
end
