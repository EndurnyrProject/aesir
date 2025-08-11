defmodule Aesir.CharServer.CharacterManager do
  @moduledoc """
  Module for managing character data storage and operations.

  This module handles:
  - Character creation, retrieval, update, and deletion
  - Database operations for character storage
  - Character validation and business logic
  - Character lookup by account_id and char_id
  """

  require Logger

  alias Aesir.Commons.Models.Character
  alias Aesir.Repo

  import Ecto.Query

  @doc """
  Creates a new character.
  """
  def create_character(account_id, char_data) do
    with {:ok, validated_data} <- Character.validate_creation(char_data),
         :ok <- check_name_available(validated_data.name),
         :ok <- check_slot_available(account_id, validated_data.slot),
         character_attrs <- build_character_attrs(account_id, validated_data, char_data),
         {:ok, character} <- create_character_in_db(character_attrs, account_id) do
      {:ok, character}
    end
  end

  @doc """
  Gets all characters for an account.
  """
  def get_characters_by_account(account_id) do
    query = from c in Character, where: c.account_id == ^account_id, order_by: c.char_num

    {:ok, Repo.all(query)}
  end

  @doc """
  Gets a specific character by ID.
  """
  def get_character(char_id) do
    case Repo.get(Character, char_id) do
      nil -> {:error, :character_not_found}
      character -> {:ok, character}
    end
  end

  @doc """
  Gets a character by account_id and slot.
  """
  def get_character_by_slot(account_id, slot) do
    query = from c in Character, where: c.account_id == ^account_id and c.char_num == ^slot

    case Repo.one(query) do
      nil -> {:error, :character_not_found}
      character -> {:ok, character}
    end
  end

  @doc """
  Updates a character.
  """
  def update_character(char_id, updates) do
    with {:ok, character} <- get_character(char_id),
         {:ok, updated_character} <-
           character
           |> Character.changeset(updates)
           |> Repo.update() do
      {:ok, updated_character}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Deletes a character.
  """
  def delete_character(char_id) do
    with {:ok, character} <- get_character(char_id),
         {:ok, _deleted_character} <- Repo.delete(character) do
      Logger.info("Deleted character #{character.name} (ID: #{char_id})")
      :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Checks if a character name is available.
  """
  def name_available?(name) do
    query =
      from c in Character, where: fragment("LOWER(?)", c.name) == ^String.downcase(name)

    case Repo.one(query) do
      nil -> true
      _ -> false
    end
  end

  @doc """
  Checks if a character slot is available for an account.
  """
  def slot_available?(account_id, slot) do
    case get_character_by_slot(account_id, slot) do
      {:ok, _character} -> false
      {:error, :character_not_found} -> true
    end
  end

  # Private helper functions for create_character/2 refactor

  defp check_name_available(name) do
    if name_available?(name), do: :ok, else: {:error, :name_taken}
  end

  defp check_slot_available(account_id, slot) do
    if slot_available?(account_id, slot), do: :ok, else: {:error, :slot_taken}
  end

  defp build_character_attrs(account_id, validated_data, char_data) do
    %{
      account_id: account_id,
      char_num: validated_data.slot,
      name: validated_data.name,
      # Novice
      class: 0,
      str: validated_data.stats.str,
      agi: validated_data.stats.agi,
      vit: validated_data.stats.vit,
      int: validated_data.stats.int,
      dex: validated_data.stats.dex,
      luk: validated_data.stats.luk,
      hair: char_data[:hair] || 1,
      hair_color: char_data[:hair_color] || 1,
      clothes_color: char_data[:clothes_color] || 1
    }
  end

  defp create_character_in_db(character_attrs, account_id) do
    case %Character{}
         |> Character.changeset(character_attrs)
         |> Repo.insert() do
      {:ok, character} ->
        Logger.info(
          "Created character #{character.name} (ID: #{character.id}) for account #{account_id}"
        )

        {:ok, character}

      {:error, changeset} ->
        Logger.warning(
          "Failed to create character for account #{account_id}: #{inspect(changeset.errors)}"
        )

        {:error, :creation_failed}
    end
  end
end
