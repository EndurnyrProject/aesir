defmodule Aesir.CharServer.CharacterSession do
  @moduledoc """
  Service module for character session management workflows.

  This module handles session-related operations for character server
  including session validation, state transitions, and session updates
  during character operations.
  """

  require Logger

  alias Aesir.Commons.SessionManager

  @doc """
  Validates a character server session.

  Verifies that the provided login credentials match an active session
  and updates the session state for character server operations.
  """
  def validate_character_session(aid, login_id1, login_id2, sex) do
    case SessionManager.validate_session(aid, login_id1, login_id2) do
      {:ok, session} ->
        updated_session_data = %{
          account_id: aid,
          login_id1: login_id1,
          login_id2: login_id2,
          sex: sex,
          authenticated: true,
          username: session.username
        }

        SessionManager.set_user_online(aid, :char_server)

        Logger.debug("Character session validated for account: #{aid}")
        {:ok, updated_session_data}

      {:error, reason} ->
        Logger.warning("Character session validation failed for account #{aid}: #{reason}")
        {:error, reason}
    end
  end

  @doc """
  Updates session state when a character is selected.

  This prepares the session for zone server transfer by storing
  the selected character information and updating location data.
  """
  def update_session_for_character_selection(session_data, character) do
    updated_session =
      session_data
      |> Map.put(:selected_character, character)
      |> Map.put(:selected_character_id, character.id)
      |> Map.put(:last_map, character.last_map)
      |> Map.put(:last_position, {character.last_x || 0, character.last_y || 0})

    Logger.debug(
      "Session updated for character selection: #{character.name} (ID: #{character.id})"
    )

    {:ok, updated_session}
  end
end
