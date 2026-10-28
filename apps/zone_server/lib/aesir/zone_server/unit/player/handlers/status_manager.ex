defmodule Aesir.ZoneServer.Unit.Player.Handlers.StatusManager do
  @moduledoc """
  Handles player status effect operations including application, removal, and queries.
  Extracted from PlayerSession to improve modularity and maintainability.
  """

  alias Aesir.Commons.StatusParams
  alias Aesir.ZoneServer.Mmo.Skill.Passives
  alias Aesir.ZoneServer.Mmo.Skills.Sage.SaFreecast
  alias Aesir.ZoneServer.Mmo.Skills.Thief.TfMiss
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Mmo.WalkSpeed
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.StateCommit
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Calculator
  alias Aesir.ZoneServer.Unit.Player.StatusSync

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
    Interpreter.remove_status(:player, game_state.character_id, status_id, owner_refresh: :defer)
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
    updated_stats = Calculator.calculate_stats(game_state.stats, game_state.character_id)
    updated_walk_speed = walk_speed_for(updated_stats)

    if Stats.changed?(updated_stats, game_state.stats) do
      StatusSync.send_stat_updates(state.connection_pid, updated_stats)
    end

    if updated_walk_speed != game_state.walk_speed do
      StatusSync.send_param(state.connection_pid, StatusParams.speed(), updated_walk_speed)
    end

    updated_game_state = %{game_state | stats: updated_stats, walk_speed: updated_walk_speed}
    StateCommit.commit(state, updated_game_state)
  end

  @doc """
  The player's walk speed (ms per straight cell) for a stats snapshot, through
  `WalkSpeed.calculate/3` from the base 150.

  The player terms: Tunnel Drive's slow while hidden, the Improve Dodge haste,
  and the item speed. The item speed is the strongest bonus speed rate (from
  equipment or a status such as a speed potion, never below 0) plus the summed
  additive speed rate. `cast_speed_rate` is Free Cast's speed rate while a
  cast is in flight, 0 otherwise.
  """
  @spec walk_speed_for(Stats.t(), non_neg_integer()) :: pos_integer()
  def walk_speed_for(stats, cast_speed_rate \\ 0) do
    WalkSpeed.calculate(PlayerState.base_walk_speed(), stats.modifiers.status_effects, %{
      tunnel_drive_slow: tunnel_drive_slow(stats),
      item_speed: item_speed(stats),
      improve_dodge_haste: TfMiss.move_haste(stats),
      cast_speed_rate: cast_speed_rate
    })
  end

  @doc """
  The player's walk speed right now: `walk_speed`, or while a cast is in
  flight with Free Cast learned, the speed under Free Cast's rate.
  """
  @spec current_walk_speed(PlayerState.t()) :: pos_integer()
  def current_walk_speed(%PlayerState{casting: nil} = game_state), do: game_state.walk_speed

  def current_walk_speed(%PlayerState{} = game_state) do
    case SaFreecast.level(game_state) do
      0 -> game_state.walk_speed
      level -> walk_speed_for(game_state.stats, SaFreecast.speed_rate(level))
    end
  end

  defp tunnel_drive_slow(stats) do
    if Stats.get_status_flag(stats, :hiding), do: Passives.hidden_move_speed(stats), else: 0
  end

  defp item_speed(stats) do
    speed_rate =
      stats
      |> Stats.get_equipment_modifier(:movement_speed)
      |> max(Stats.get_status_modifier(stats, :speed_rate_bonus))
      |> max(0)

    speed_rate + Stats.get_equipment_modifier(stats, :movement_speed_add)
  end
end
