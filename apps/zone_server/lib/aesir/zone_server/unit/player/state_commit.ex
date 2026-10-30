defmodule Aesir.ZoneServer.Unit.Player.StateCommit do
  @moduledoc """
  Publishes an authoritative player-state commit to shared runtime views.
  """

  require Logger

  alias Aesir.Commons.StatusParams
  alias Aesir.ZoneServer.Mmo.Skills.Sage.SaFreecast
  alias Aesir.ZoneServer.Unit.Player.GuildSync
  alias Aesir.ZoneServer.Unit.Player.Handlers.FameHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.StatusManager
  alias Aesir.ZoneServer.Unit.Player.PartySync
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.Player.StatusSync
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @doc """
  Commits `game_state` to the unit registry and party view, then returns the
  session carrying that state.

  Party and guild synchronization are best-effort and never roll back the
  authoritative session or registry state.

  A cast starting or ending for a player who knows Free Cast changes its
  current walk speed (`StatusManager.current_walk_speed/1`); the new speed is
  sent to the client when it differs.
  """
  @spec commit(SessionState.t(), PlayerState.t()) :: SessionState.t()
  def commit(%{game_state: %PlayerState{} = previous} = session, %PlayerState{} = game_state) do
    game_state = FameHandler.drain(Map.get(session, :connection_pid), game_state)
    UnitRegistry.update_unit_state(:player, game_state.character_id, game_state)
    sync_cast_speed(session, previous, game_state)

    case PartySync.sync(previous, game_state) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.warning(
          "Failed to synchronize party state for character #{game_state.character_id}: #{inspect(reason)}"
        )
    end

    case GuildSync.sync(previous, game_state) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.warning(
          "Failed to synchronize guild state for character #{game_state.character_id}: #{inspect(reason)}"
        )
    end

    %{session | game_state: game_state}
  end

  defp sync_cast_speed(session, %PlayerState{casting: before}, %PlayerState{casting: now} = state)
       when is_nil(before) != is_nil(now) do
    if SaFreecast.known?(state) do
      speed = StatusManager.current_walk_speed(state)
      before_speed = StatusManager.current_walk_speed(%{state | casting: before})

      if speed != before_speed,
        do: StatusSync.send_param(session.connection_pid, StatusParams.speed(), speed)
    end

    :ok
  end

  defp sync_cast_speed(_session, _previous, _game_state), do: :ok
end
