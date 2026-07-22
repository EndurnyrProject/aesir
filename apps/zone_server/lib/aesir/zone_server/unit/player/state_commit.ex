defmodule Aesir.ZoneServer.Unit.Player.StateCommit do
  @moduledoc """
  Publishes an authoritative player-state commit to shared runtime views.
  """

  require Logger

  alias Aesir.ZoneServer.Unit.Player.GuildSync
  alias Aesir.ZoneServer.Unit.Player.PartySync
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @doc """
  Commits `game_state` to the unit registry and party view, then returns the
  session carrying that state.

  Party and guild synchronization are best-effort and never roll back the
  authoritative session or registry state.
  """
  @spec commit(SessionState.t(), PlayerState.t()) :: SessionState.t()
  def commit(%{game_state: %PlayerState{} = previous} = session, %PlayerState{} = game_state) do
    UnitRegistry.update_unit_state(:player, game_state.character_id, game_state)

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
end
