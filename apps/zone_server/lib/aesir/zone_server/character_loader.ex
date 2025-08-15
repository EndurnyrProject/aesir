defmodule Aesir.ZoneServer.CharacterLoader do
  @moduledoc """
  Handles loading character data from the database for the Zone Server.
  Validates character ownership and prepares player data for the game session.
  """

  require Logger

  alias Aesir.Repo
  alias Aesir.Commons.Models.Character

  @doc """
  Loads a character from the database and validates ownership.
  Returns the Character model for use in PlayerSession.
  """
  def load_character(char_id, account_id) do
    with {:ok, character} <- get_character(char_id),
         :ok <- validate_ownership(character, account_id) do
      {:ok, character}
    else
      {:error, reason} ->
        Logger.error("Failed to load character #{char_id} for account #{account_id}: #{reason}")
        {:error, reason}
    end
  end

  defp get_character(char_id) do
    case Repo.get(Character, char_id) do
      nil ->
        {:error, :character_not_found}

      character ->
        {:ok, character}
    end
  end

  defp validate_ownership(character, account_id) do
    if character.account_id == account_id do
      :ok
    else
      Logger.warning("Character #{character.id} does not belong to account #{account_id}")
      {:error, :character_not_owned}
    end
  end
end

