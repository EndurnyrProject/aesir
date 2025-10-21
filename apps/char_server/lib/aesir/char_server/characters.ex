defmodule Aesir.CharServer.Characters do
  @moduledoc """
  Context module for character operations.

  This module handles the business logic for character management including
  creation, deletion, retrieval, and related operations. It uses atomic
  transactions to ensure data consistency and delegates to existing modules
  for validation and persistence.
  """
  require Logger

  import Ecto.Query

  alias Aesir.CharServer.Auth
  alias Aesir.Commons.InterServer.PubSub
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.SessionManager
  alias Aesir.Commons.Utils
  alias Aesir.Repo

  @doc """
  Creates a new character with atomic transaction handling.

  This function orchestrates the entire character creation workflow:
  1. Validates account permissions
  2. Checks character slot availability
  3. Validates character data
  4. Creates character in database
  5. Broadcasts creation event

  Returns {:ok, character} on success or {:error, reason} on failure.
  """
  def create_character(account_id, char_data) do
    Ecto.Multi.new()
    |> Ecto.Multi.run(:account_validation, fn _repo, _changes ->
      Auth.validate_account_permissions(account_id)
    end)
    |> Ecto.Multi.run(:character_count, fn _repo, _changes ->
      get_character_count(account_id)
    end)
    |> Ecto.Multi.run(:permission_check, fn _repo,
                                            %{account_validation: account, character_count: count} ->
      Auth.can_create_character?(account.id, count)
    end)
    |> Ecto.Multi.run(:character_validation, fn _repo, _changes ->
      Character.validate_creation(char_data)
    end)
    |> Ecto.Multi.run(:name_availability, fn _repo, %{character_validation: validated_data} ->
      check_name_availability(validated_data.name)
    end)
    |> Ecto.Multi.run(:slot_availability, fn _repo, %{character_validation: validated_data} ->
      check_slot_availability(account_id, validated_data.slot)
    end)
    |> Ecto.Multi.run(:character_creation, fn repo, %{character_validation: validated_data} ->
      create_character_record(repo, account_id, validated_data, char_data)
    end)
    |> Repo.transaction()
    |> handle_creation_result(account_id)
  end

  @doc """
  Requests character deletion with a timer (modern client behavior).

  Sets a deletion date instead of immediately deleting the character.
  The character will be deleted after the configured delay (default 24 hours).
  """
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  def request_character_deletion(char_id, account_id) do
    deletion_delay = Application.get_env(:char_server, :deletion_delay, 86_400)

    Ecto.Multi.new()
    |> Ecto.Multi.run(:character_lookup, fn _repo, _changes ->
      get_character(char_id)
    end)
    |> Ecto.Multi.run(:ownership_check, fn _repo, %{character_lookup: character} ->
      if character.account_id == account_id do
        {:ok, character}
      else
        {:error, :not_found}
      end
    end)
    |> Ecto.Multi.run(:deletion_check, fn _repo, %{character_lookup: character} ->
      cond do
        Character.marked_for_deletion?(character) ->
          {:error, :already_deleting}

        character.guild_id && character.guild_id > 0 ->
          {:error, :cannot_delete}

        character.party_id && character.party_id > 0 ->
          {:error, :cannot_delete}

        true ->
          {:ok, :can_delete}
      end
    end)
    |> Ecto.Multi.run(:set_deletion_date, fn repo, %{character_lookup: character} ->
      delete_date =
        NaiveDateTime.utc_now()
        |> NaiveDateTime.add(deletion_delay, :second)
        |> NaiveDateTime.truncate(:second)

      character
      |> Ecto.Changeset.change(delete_date: delete_date)
      |> repo.update()
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{set_deletion_date: character}} ->
        delete_timestamp =
          character.delete_date
          |> DateTime.from_naive!("Etc/UTC")
          |> DateTime.to_unix()

        Logger.info(
          "Character #{character.name} (ID: #{character.id}) marked for deletion at #{character.delete_date}"
        )

        {:ok, delete_timestamp}

      {:error, :character_lookup, _, _} ->
        {:error, :not_found}

      {:error, :ownership_check, reason, _} ->
        {:error, reason}

      {:error, :deletion_check, reason, _} ->
        {:error, reason}

      {:error, :set_deletion_date, _, _} ->
        {:error, :database_error}

      _ ->
        {:error, :database_error}
    end
  end

  @doc """
  Deletes a character with proper authorization and cleanup.

  Performs ownership verification and handles the deletion workflow atomically.
  """
  def delete_character(account_id, char_id) do
    Ecto.Multi.new()
    |> Ecto.Multi.run(:character_lookup, fn _repo, _changes ->
      get_character(char_id)
    end)
    |> Ecto.Multi.run(:ownership_check, fn _repo, %{character_lookup: character} ->
      Auth.verify_character_ownership(account_id, character.account_id)
    end)
    |> Ecto.Multi.run(:deletion_validation, fn _repo, %{character_lookup: character} ->
      validate_deletion_eligibility(character)
    end)
    |> Ecto.Multi.run(:character_deletion, fn _repo, %{character_lookup: character} ->
      delete_character_record(character)
    end)
    |> Repo.transaction()
    |> handle_deletion_result()
  end

  @doc """
  Retrieves characters for an account with session validation.
  """
  def list_characters(account_id, session_data) do
    case validate_session_for_account(account_id, session_data) do
      {:ok, _session} -> get_characters_by_account(account_id)
      error -> error
    end
  end

  @doc """
  Selects a character and prepares for zone transfer.
  """
  def select_character(account_id, slot) do
    with {:ok, character} <- get_character_by_slot(account_id, slot),
         :ok <- update_character_location(character),
         :ok <- broadcast_character_selected(account_id, character) do
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

  defp get_character_count(account_id) do
    count =
      from(c in Character, where: c.account_id == ^account_id, select: count(c.id))
      |> Repo.one()

    {:ok, count}
  end

  defp check_name_availability(name) do
    if name_available?(name) do
      {:ok, :available}
    else
      {:error, :name_taken}
    end
  end

  defp check_slot_availability(account_id, slot) do
    if slot_available?(account_id, slot) do
      {:ok, :available}
    else
      {:error, :slot_taken}
    end
  end

  defp create_character_record(repo, account_id, validated_data, char_data) do
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
      clothes_color: char_data[:clothes_color] || 1,
      sex: Utils.int_to_sex(char_data[:sex])
    }

    %Character{}
    |> Character.changeset(character_attrs)
    |> repo.insert()
  end

  defp validate_deletion_eligibility(character) do
    # TODO: Add additional validation checks:
    # - Guild membership
    # - Party membership
    # - Marriage status
    # - Pending mail/auctions
    # - Email verification if required

    cond do
      Character.banned?(character) ->
        {:error, :character_banned}

      character.guild_id && character.guild_id > 0 ->
        {:error, :character_in_guild}

      character.party_id && character.party_id > 0 ->
        {:error, :character_in_party}

      true ->
        {:ok, :eligible}
    end
  end

  defp delete_character_record(character) do
    case Repo.delete(character) do
      {:ok, deleted_character} ->
        Logger.info("Deleted character #{deleted_character.name} (ID: #{deleted_character.id})")
        {:ok, deleted_character}

      {:error, changeset} ->
        Logger.error("Failed to delete character: #{inspect(changeset.errors)}")
        {:error, :deletion_failed}
    end
  end

  defp validate_session_for_account(account_id, session_data) do
    case session_data do
      %{account_id: ^account_id, authenticated: true} ->
        {:ok, session_data}

      %{account_id: different_account_id} ->
        Logger.warning(
          "Session account mismatch: expected #{account_id}, got #{different_account_id}"
        )

        {:error, :session_account_mismatch}

      %{authenticated: false} ->
        {:error, :session_not_authenticated}

      _ ->
        {:error, :invalid_session}
    end
  end

  defp update_character_location(character) do
    SessionManager.update_character_location(
      character.id,
      character.account_id,
      character.last_map,
      {character.last_x || 0, character.last_y || 0}
    )

    :ok
  end

  defp broadcast_character_selected(account_id, character) do
    PubSub.broadcast_character_selected(account_id, character.id, character.name)
    :ok
  end

  defp handle_creation_result(transaction_result, account_id) do
    case transaction_result do
      {:ok, %{character_creation: character}} ->
        PubSub.broadcast_character_created(account_id, character.id, character.name)

        Logger.info(
          "Created character #{character.name} (ID: #{character.id}) for account #{account_id}"
        )

        {:ok, character}

      {:error, :account_validation, reason, _changes} ->
        Logger.warning("Character creation failed: account validation error - #{inspect(reason)}")
        {:error, reason}

      {:error, :permission_check, reason, _changes} ->
        Logger.warning("Character creation failed: permission check - #{inspect(reason)}")
        {:error, reason}

      {:error, :character_validation, reason, _changes} ->
        Logger.info("Character creation failed: validation error - #{inspect(reason)}")
        {:error, reason}

      {:error, :name_availability, reason, _changes} ->
        Logger.info("Character creation failed: name not available")
        {:error, reason}

      {:error, :slot_availability, reason, _changes} ->
        Logger.info("Character creation failed: slot not available")
        {:error, reason}

      {:error, :character_creation, reason, _changes} ->
        Logger.error("Character creation failed: database error - #{inspect(reason)}")
        {:error, :creation_failed}

      {:error, failed_operation, reason, _changes} ->
        Logger.error("Character creation failed at #{failed_operation}: #{inspect(reason)}")
        {:error, :creation_failed}
    end
  end

  defp handle_deletion_result(transaction_result) do
    case transaction_result do
      {:ok, %{character_deletion: character}} ->
        Logger.info("Successfully deleted character #{character.name} (ID: #{character.id})")
        :ok

      {:error, :character_lookup, reason, _changes} ->
        Logger.warning("Character deletion failed: character lookup - #{inspect(reason)}")
        {:error, reason}

      {:error, :ownership_check, reason, _changes} ->
        Logger.warning("Character deletion failed: ownership check - #{inspect(reason)}")
        {:error, reason}

      {:error, :deletion_validation, reason, _changes} ->
        Logger.info("Character deletion failed: validation - #{inspect(reason)}")
        {:error, reason}

      {:error, :character_deletion, reason, _changes} ->
        Logger.error("Character deletion failed: database error - #{inspect(reason)}")
        {:error, :deletion_failed}

      {:error, failed_operation, reason, _changes} ->
        Logger.error("Character deletion failed at #{failed_operation}: #{inspect(reason)}")
        {:error, :deletion_failed}
    end
  end
end
