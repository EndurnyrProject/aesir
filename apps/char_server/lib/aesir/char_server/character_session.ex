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

        Logger.info("Character session validated for account: #{aid}")
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

  @doc """
  Validates that a session belongs to the specified account.

  This is used to prevent session hijacking and ensure that
  operations are performed by the correct account holder.
  """
  def validate_session_ownership(session_data, expected_account_id) do
    case session_data do
      %{account_id: ^expected_account_id, authenticated: true} ->
        {:ok, session_data}

      %{account_id: different_account_id} ->
        Logger.warning(
          "Session ownership validation failed: expected account #{expected_account_id}, got #{different_account_id}"
        )

        {:error, :session_account_mismatch}

      %{authenticated: false} ->
        Logger.warning("Session not authenticated for account #{expected_account_id}")
        {:error, :session_not_authenticated}

      _ ->
        Logger.warning("Invalid session data for account #{expected_account_id}")
        {:error, :invalid_session}
    end
  end

  @doc """
  Prepares session data for zone server transfer.

  Creates the session state that will be passed to the zone server
  when a character enters the game world.
  """
  def prepare_zone_transfer_session(session_data, character) do
    zone_session = %{
      account_id: session_data.account_id,
      character_id: character.id,
      character_name: character.name,
      login_id1: session_data.login_id1,
      login_id2: session_data.login_id2,
      last_map: character.last_map,
      last_x: character.last_x || 0,
      last_y: character.last_y || 0,
      sex: session_data.sex,
      transferred_at: DateTime.utc_now()
    }

    Logger.debug("Zone transfer session prepared for character #{character.name}")
    {:ok, zone_session}
  end

  @doc """
  Cleans up session state when a user disconnects from character server.
  """
  def cleanup_character_session(account_id) do
    SessionManager.end_session(account_id)
    Logger.debug("Character session cleaned up for account: #{account_id}")
    :ok
  end

  @doc """
  Gets current session status for an account.
  """
  def get_session_status(account_id) do
    case SessionManager.get_session(account_id) do
      {:ok, _session} ->
        {:ok, :online}

      {:error, :not_found} ->
        {:ok, :offline}

      {:error, _reason} ->
        {:ok, :offline}
    end
  end

  @doc """
  Validates session state for character operations.

  Ensures the session is in a valid state to perform character
  operations like creation, deletion, or selection.
  """
  def validate_session_for_operations(session_data) do
    required_fields = [:account_id, :authenticated, :username]

    missing_fields =
      required_fields
      |> Enum.reject(fn field -> Map.has_key?(session_data, field) end)

    case missing_fields do
      [] ->
        if session_data.authenticated do
          {:ok, session_data}
        else
          {:error, :session_not_authenticated}
        end

      fields ->
        Logger.warning("Session validation failed: missing fields #{inspect(fields)}")
        {:error, :incomplete_session}
    end
  end
end
