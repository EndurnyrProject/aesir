defmodule Aesir.ZoneServer.CharacterPersistence do
  @moduledoc """
  Handles persisting character data changes to the database from zone server events.

  This module provides a generic interface for updating character data in the database,
  with support for both synchronous and asynchronous updates. It's designed to be used
  by various zone server systems (movement, combat, stats, etc.) to persist character
  state changes.

  ## Features
  - Generic update function that accepts any character fields
  - Convenience functions for common update patterns
  - Async (fire-and-forget) and sync update modes
  - Only updates provided fields, leaves others unchanged
  - Proper error handling and logging

  ## Examples

      # Async position update (fire-and-forget)
      CharacterPersistence.update_position(char_id, 100, 200, "prontera", async: true)

      # Sync stats update (waits for completion)
      CharacterPersistence.update_character(char_id, %{hp: 100, sp: 50})

      # Update experience
      CharacterPersistence.update_exp(char_id, 1000, 500, async: true)
  """

  require Logger

  alias Aesir.Commons.Models.Character
  alias Aesir.Repo

  @type update_fields :: %{optional(atom()) => any()}
  @type update_option :: {:async, boolean()}
  @type update_options :: [update_option()]

  @doc """
  Updates character fields in the database.

  ## Parameters
  - character_id: The ID of the character to update
  - fields: Map of field names to new values
  - opts: Options for the update
    - `:async` - If true, update asynchronously (default: false)

  ## Returns
  - `{:ok, character}` - Successfully updated (sync mode only)
  - `{:error, reason}` - Failed to update (sync mode only)
  - `:ok` - Async task started (async mode only)

  ## Examples

      # Sync update
      CharacterPersistence.update_character(1, %{hp: 100, max_hp: 150})

      # Async update
      CharacterPersistence.update_character(1, %{hp: 100}, async: true)
  """
  @spec update_character(integer(), update_fields(), update_options()) ::
          {:ok, Character.t()} | {:error, term()} | :ok
  def update_character(character_id, fields, opts \\ []) when is_map(fields) do
    async = Keyword.get(opts, :async, false)

    if async do
      Task.start(fn -> do_async_update(character_id, fields) end)
      :ok
    else
      do_update_character(character_id, fields)
    end
  end

  @doc """
  Updates character position (last_x, last_y, last_map).

  ## Parameters
  - character_id: The ID of the character
  - x: New X coordinate
  - y: New Y coordinate
  - map_name: Map name
  - opts: Options for the update (see `update_character/3`)

  ## Examples

      # Async position update
      CharacterPersistence.update_position(1, 100, 200, "prontera", async: true)

      # Sync position update
      CharacterPersistence.update_position(1, 100, 200, "prontera")
  """
  @spec update_position(integer(), integer(), integer(), String.t(), update_options()) ::
          {:ok, Character.t()} | {:error, term()} | :ok
  def update_position(character_id, x, y, map_name, opts \\ []) do
    update_character(
      character_id,
      %{
        last_x: x,
        last_y: y,
        last_map: map_name
      },
      opts
    )
  end

  @doc """
  Updates character stats (HP, SP, etc.).

  ## Parameters
  - character_id: The ID of the character
  - stats: Map of stat fields to update (e.g., %{hp: 100, sp: 50})
  - opts: Options for the update (see `update_character/3`)

  ## Examples

      CharacterPersistence.update_stats(1, %{hp: 100, sp: 50, max_hp: 150})
  """
  @spec update_stats(integer(), update_fields(), update_options()) ::
          {:ok, Character.t()} | {:error, term()} | :ok
  def update_stats(character_id, stats, opts \\ []) when is_map(stats) do
    update_character(character_id, stats, opts)
  end

  @doc """
  Updates character experience (base_exp and/or job_exp).

  ## Parameters
  - character_id: The ID of the character
  - base_exp: New base experience value (optional)
  - job_exp: New job experience value (optional)
  - opts: Options for the update (see `update_character/3`)

  ## Examples

      # Update both exp types
      CharacterPersistence.update_exp(1, 1000, 500)

      # Update only base exp
      CharacterPersistence.update_exp(1, 1000, nil)
  """
  @spec update_exp(integer(), integer() | nil, integer() | nil, update_options()) ::
          {:ok, Character.t()} | {:error, term()} | :ok
  def update_exp(character_id, base_exp, job_exp, opts \\ []) do
    fields =
      %{}
      |> maybe_put(:base_exp, base_exp)
      |> maybe_put(:job_exp, job_exp)

    update_character(character_id, fields, opts)
  end

  defp do_async_update(character_id, fields) do
    case do_update_character(character_id, fields) do
      {:ok, _character} ->
        Logger.debug(
          "Character #{character_id} updated successfully: #{inspect(Map.keys(fields))}"
        )

      {:error, reason} ->
        Logger.error(
          "Failed to update character #{character_id}: #{inspect(reason)}, fields: #{inspect(fields)}"
        )
    end
  end

  defp do_update_character(_character_id, fields) when map_size(fields) == 0 do
    {:error, :no_fields_to_update}
  end

  defp do_update_character(character_id, fields) do
    case Repo.get(Character, character_id) do
      nil ->
        {:error, :character_not_found}

      character ->
        character
        |> Character.changeset(fields)
        |> Repo.update()
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
