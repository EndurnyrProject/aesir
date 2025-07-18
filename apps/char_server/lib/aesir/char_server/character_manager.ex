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

  alias Aesir.CharServer.Character
  alias Aesir.Commons.Models.Character, as: CharacterModel
  alias Aesir.Repo
  import Ecto.Query

  @doc """
  Creates a new character.
  """
  def create_character(account_id, char_data) do
    case Character.validate_creation(char_data) do
      {:ok, validated_data} ->
        # Check if name is available
        if name_available?(validated_data.name) do
          # Check if slot is available
          if slot_available?(account_id, validated_data.slot) do
            # Create character with database
            character_attrs = %{
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

            case %CharacterModel{}
                 |> CharacterModel.changeset(character_attrs)
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
          else
            {:error, :slot_taken}
          end
        else
          {:error, :name_taken}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Gets all characters for an account.
  """
  def get_characters_by_account(account_id) do
    characters =
      from(c in CharacterModel, where: c.account_id == ^account_id, order_by: c.char_num)
      |> Repo.all()

    {:ok, characters}
  end

  @doc """
  Gets a specific character by ID.
  """
  def get_character(char_id) do
    case Repo.get(CharacterModel, char_id) do
      nil -> {:error, :character_not_found}
      character -> {:ok, character}
    end
  end

  @doc """
  Gets a character by account_id and slot.
  """
  def get_character_by_slot(account_id, slot) do
    query = from(c in CharacterModel, where: c.account_id == ^account_id and c.char_num == ^slot)

    case Repo.one(query) do
      nil -> {:error, :character_not_found}
      character -> {:ok, character}
    end
  end

  @doc """
  Updates a character.
  """
  def update_character(char_id, updates) do
    case Repo.get(CharacterModel, char_id) do
      nil ->
        {:error, :character_not_found}

      character ->
        case character
             |> CharacterModel.changeset(updates)
             |> Repo.update() do
          {:ok, updated_character} -> {:ok, updated_character}
          {:error, changeset} -> {:error, changeset}
        end
    end
  end

  @doc """
  Deletes a character.
  """
  def delete_character(char_id) do
    case Repo.get(CharacterModel, char_id) do
      nil ->
        {:error, :character_not_found}

      character ->
        case Repo.delete(character) do
          {:ok, _deleted_character} ->
            Logger.info("Deleted character #{character.name} (ID: #{char_id})")
            :ok

          {:error, changeset} ->
            {:error, changeset}
        end
    end
  end

  @doc """
  Checks if a character name is available.
  """
  def name_available?(name) do
    query =
      from(c in CharacterModel, where: fragment("LOWER(?)", c.name) == ^String.downcase(name))

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
end
