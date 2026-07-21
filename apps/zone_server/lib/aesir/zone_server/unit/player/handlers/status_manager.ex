defmodule Aesir.ZoneServer.Unit.Player.Handlers.StatusManager do
  @moduledoc """
  Handles player status effect operations including application, removal, and queries.
  Extracted from PlayerSession to improve modularity and maintainability.
  """

  alias Aesir.Commons.StatusParams
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.StateCommit
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.StatusSync

  @base_walk_speed 150
  @min_walk_speed 20
  @max_walk_speed 1_000
  @min_speed_rate 40

  @doc """
  Handles applying a status effect to the player.

  ## Parameters
    - status_id: The status effect ID
    - status_params: Keyword list containing status parameters
    - state: The player session state
    
  ## Returns
    - {:reply, :ok, updated_state} - Success with stat recalculation
    - {:reply, {:error, reason}, state} - Failure (e.g., immunity)
  """
  @spec handle_apply_status(atom(), keyword(), map()) ::
          {:reply, :ok | {:error, term()}, map()}
  def handle_apply_status(status_id, status_params, %{game_state: game_state} = state) do
    case Interpreter.apply_status(:player, game_state.character_id, status_id, status_params) do
      :ok ->
        {:reply, :ok, recalculate_after_status_change(state)}

      {:error, reason} ->
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
  @spec handle_remove_status(atom(), map()) :: {:reply, :ok, map()}
  def handle_remove_status(status_id, %{game_state: game_state} = state) do
    Interpreter.remove_status(:player, game_state.character_id, status_id)
    {:reply, :ok, recalculate_after_status_change(state)}
  end

  @doc """
  Handles getting all active status effects for the player.

  ## Parameters
    - state: The player session state
    
  ## Returns
    - {:reply, statuses, state} - Returns list of active statuses
  """
  def handle_get_active_statuses(%{game_state: game_state} = state) do
    statuses = StatusStorage.get_unit_statuses(:player, game_state.character_id)
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
  def handle_has_status(status_id, %{game_state: game_state} = state) do
    has_status = StatusStorage.has_status?(:player, game_state.character_id, status_id)
    {:reply, has_status, state}
  end

  @doc """
  Recomputes the player's stats and walk speed from the now-current set of
  active statuses and pushes any change to the client. Shared by the apply and
  remove paths, and by `ItemHandler` after an item-use script whose effect
  started or ended a status, so the recalc logic lives in one place.
  """
  @spec recalculate_after_status_change(map()) :: map()
  def recalculate_after_status_change(%{game_state: game_state} = state) do
    updated_stats = Stats.calculate_stats(game_state.stats, game_state.character_id)
    updated_walk_speed = walk_speed_for(updated_stats)

    if updated_stats != game_state.stats do
      StatusSync.send_stat_updates(state.connection_pid, updated_stats)
    end

    if updated_walk_speed != game_state.walk_speed do
      StatusSync.send_param(state.connection_pid, StatusParams.speed(), updated_walk_speed)
    end

    updated_game_state = %{game_state | stats: updated_stats, walk_speed: updated_walk_speed}
    StateCommit.commit(state, updated_game_state)
  end

  @doc """
  The player's walk speed (ms per straight cell) for a stats snapshot.

  The status-sourced `:movement_speed` modifier is a percentage adjustment to
  the speed rate (positive = slower, negative = faster). The equipment-sourced
  one uses the opposite, non-stackable convention of the `bonus bSpeedRate`
  vocabulary — positive = faster — so it is subtracted, and only the strongest
  equipped source contributes (the max-merge happens when the equipment
  modifiers are folded).

  The rate is floored at 40 and the resulting walk speed is clamped to the
  engine's MIN/MAX walk-speed bounds. With no speed modifier from either source
  the speed stays exactly the base 150.
  """
  @spec walk_speed_for(Stats.t()) :: pos_integer()
  def walk_speed_for(stats) do
    speed_delta =
      Stats.get_status_modifier(stats, :movement_speed) -
        Stats.get_equipment_modifier(stats, :movement_speed)

    speed_rate = max(100 + speed_delta, @min_speed_rate)

    calculated_walk_speed =
      @base_walk_speed
      |> Kernel.*(speed_rate)
      |> div(100)
      |> max(@min_walk_speed)
      |> min(@max_walk_speed)

    Map.get(stats.modifiers.status_effects, :walk_speed_override, calculated_walk_speed)
  end
end
