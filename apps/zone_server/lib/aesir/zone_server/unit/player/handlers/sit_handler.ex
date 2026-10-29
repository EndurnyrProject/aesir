defmodule Aesir.ZoneServer.Unit.Player.Handlers.SitHandler do
  @moduledoc """
  Sit and stand requests. A committed posture change is broadcast to the area,
  actor included, as a `DamageDealt` sit/stand action; clients only change
  posture on that broadcast. Standing up ends Tension Relax and restarts the
  sitting regeneration from nothing.
  """

  alias Aesir.Commons.Utils.ServerTick
  alias Aesir.Net.DamageDealt
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.Player.StateCommit
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  # e_damage_type DMG_SIT_DOWN / DMG_STAND_UP.
  @dmg_sit_down 2
  @dmg_stand_up 3

  @skill_id 223
  @status_id :sc_gangsterparadise
  @range 1

  def handle_sit(%{game_state: game_state} = state) do
    if Interpreter.can_sit?(game_state.character_id),
      do: transition(state, game_state, :sitting),
      else: {:noreply, state}
  end

  def handle_stand(%{game_state: game_state} = state) do
    if Interpreter.can_stand?(game_state.character_id),
      do: transition(state, game_state, :idle),
      else: {:noreply, state}
  end

  @doc """
  Stands a seated player up whatever keeps it seated, as Guard's block does.
  A player not sitting is left as it is.
  """
  @spec handle_force_stand(SessionState.t()) :: {:noreply, SessionState.t()}
  def handle_force_stand(%{game_state: %{action_state: :sitting} = game_state} = state),
    do: transition(state, game_state, :idle)

  def handle_force_stand(state), do: {:noreply, state}

  defp transition(state, game_state, action_state) do
    case PlayerState.transition_to(game_state, action_state) do
      {:ok, updated_game_state} ->
        state = state |> StateCommit.commit(updated_game_state) |> stood_up(action_state)
        broadcast_posture(updated_game_state)
        synchronize_gangster_paradise(updated_game_state)
        {:noreply, state}

      {:error, :invalid_transition} ->
        {:noreply, state}
    end
  end

  defp stood_up(%{game_state: %{character_id: id}, regen_timing: timing} = state, :idle) do
    :ok = Interpreter.remove_status(:player, id, :sc_tensionrelax, owner_refresh: :notify)
    %{state | regen_timing: %{timing | sitting_hp_acc: 0, sitting_sp_acc: 0}}
  end

  defp stood_up(state, _sitting), do: state

  defp broadcast_posture(%{character_id: id, map_name: map_name, x: x, y: y} = game_state) do
    type = if game_state.action_state == :sitting, do: @dmg_sit_down, else: @dmg_stand_up

    packet = %DamageDealt{
      src_id: id,
      target_id: 0,
      server_tick: ServerTick.now(),
      div: 0,
      type: type
    }

    Broadcast.to_in_range(map_name, x, y, Config.view_range(), packet)
  end

  defp synchronize_gangster_paradise(%{map_name: map_name, x: x, y: y}) do
    player_ids = SpatialIndex.get_players_in_range(map_name, x, y, @range)

    participants =
      player_ids
      |> Enum.flat_map(&player/1)
      |> Enum.filter(&gangster_sitting?/1)

    Enum.each(
      player_ids,
      &Interpreter.remove_status(:player, &1, @status_id, owner_refresh: :defer)
    )

    if length(participants) > 1 do
      Enum.each(participants, fn %{character_id: character_id} ->
        :ok = Interpreter.apply_status(:player, character_id, @status_id)
      end)
    end
  end

  defp player(character_id) do
    case UnitRegistry.get_unit(:player, character_id) do
      {:ok, {_module, player, _pid}} -> [player]
      {:error, :not_found} -> []
    end
  end

  defp gangster_sitting?(%{action_state: :sitting, stats: stats}) when is_map(stats),
    do: PlayerStats.skill_level(stats, @skill_id) > 0

  defp gangster_sitting?(_player), do: false
end
