defmodule Aesir.CharServer.Auth do
  @moduledoc """
  Authentication and authorization functions for the character server.
  Validates account permissions and character ownership.
  """

  require Logger

  alias Aesir.Commons.Models.Account
  alias Aesir.Repo

  @doc """
  Validate that an account has permissions to perform character operations.
  Checks account status, bans, and other restrictions.
  """
  def validate_account_permissions(account_id) do
    with {:ok, account} <- get_account(account_id),
         :ok <- validate_account_status(account) do
      {:ok, account}
    else
      {:error, reason} ->
        Logger.warning("Account validation failed for #{account_id}: #{reason}")
        {:error, reason}
    end
  end

  @doc """
  Check if an account can create a character.
  Validates character slots and account permissions.
  """
  def can_create_character?(account_id, current_character_count) do
    with {:ok, account} <- validate_account_permissions(account_id),
         {:ok, max_characters} <- get_max_character_slots(account),
         :ok <- check_slot_availability(current_character_count, max_characters) do
      {:ok,
       %{
         account_id: account_id,
         remaining_slots: max_characters - current_character_count,
         max_slots: max_characters
       }}
    end
  end

  @doc """
  Verify that a character belongs to an account.
  """
  def verify_character_ownership(account_id, character_account_id) do
    case validate_ownership(account_id, character_account_id) do
      :ok ->
        :ok
      {:error, reason} ->
        Logger.warning(
          "Character ownership verification failed: character belongs to #{character_account_id}, not #{account_id}"
        )

        {:error, reason}
    end
  end

  defp get_account(account_id) do
    case Repo.get(Account, account_id) do
      nil -> {:error, :account_not_found}
      account -> {:ok, account}
    end
  end

  defp validate_account_status(account) do
    case account.state do
      5 ->
        {:error, :account_banned}

      1 ->
        {:error, :account_not_confirmed}

      2 ->
        {:error, :account_suspended}

      0 ->
        :ok

      state ->
        Logger.warning("Unknown account state: #{state} for account #{account.id}")
        {:error, :unknown_account_state}
    end
  end

  defp get_max_character_slots(account) do
    base_slots = 3
    additional_slots = Map.get(account, :character_slots, 0)
    max_slots = 9

    {:ok, min(base_slots + additional_slots, max_slots)}
  end

  defp check_slot_availability(current_count, max_characters) do
    if current_count >= max_characters do
      {:error, :character_slots_full}
    else
      :ok
    end
  end

  defp validate_ownership(account_id, character_account_id) do
    if account_id == character_account_id do
      :ok
    else
      {:error, :not_owner}
    end
  end
end
