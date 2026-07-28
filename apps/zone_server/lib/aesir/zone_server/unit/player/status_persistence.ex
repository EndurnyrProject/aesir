defmodule Aesir.ZoneServer.Unit.Player.StatusPersistence do
  @moduledoc """
  Saves a player's active statuses at logout and restores them at login,
  mirroring rAthena's `sc_data` table.

  Only statuses whose definition does not set `no_save` are written. The
  in-memory `expires_at` is a monotonic timestamp that cannot survive the VM,
  so what persists is the remaining duration in milliseconds (`nil` for
  permanent statuses); entries that already expired are skipped. Rows are
  consumed on restore (loaded then deleted, as rAthena does with `sc_data`)
  and re-applied through `StatusManager` with the `loaded` flag so the
  immunity/conflict/resistance gates are not re-rolled. Runtime `state` and
  `phase` are not persisted; the effect's `on_apply` rebuilds them.
  """

  import Ecto.Query

  require Logger

  alias Aesir.Commons.Models.CharacterStatus
  alias Aesir.Repo
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.Handlers.StatusManager

  @doc """
  Persists the player's current statuses, replacing any previously saved rows.
  """
  @spec save_statuses(integer()) :: :ok
  def save_statuses(char_id) do
    now_ms = System.monotonic_time(:millisecond)
    inserted_at = NaiveDateTime.utc_now(:second)

    rows =
      :player
      |> StatusStorage.get_unit_statuses(char_id)
      |> Enum.flat_map(&row_for(&1, char_id, now_ms))
      |> Enum.map(&Map.merge(&1, %{inserted_at: inserted_at, updated_at: inserted_at}))

    {:ok, _result} =
      Repo.transaction(fn ->
        Repo.delete_all(saved_statuses_query(char_id))
        Repo.insert_all(CharacterStatus, rows)
      end)

    :ok
  end

  @doc """
  Restores the statuses persisted at logout, consuming the saved rows.

  Takes and returns the session `state` map; runs inside `PlayerSession.init/1`
  after registration, so each row re-applies through `StatusManager` exactly
  like a live apply (modifier recalc included). A row whose status no longer
  exists in the registry is dropped with a warning.
  """
  @spec restore_on_spawn(map()) :: map()
  def restore_on_spawn(%{game_state: game_state} = state) do
    game_state.character_id
    |> consume_saved_statuses()
    |> Enum.reduce(state, &restore_status/2)
  end

  defp consume_saved_statuses(char_id) do
    query = saved_statuses_query(char_id)
    rows = Repo.all(query)
    Repo.delete_all(query)
    rows
  end

  defp restore_status(%CharacterStatus{} = row, state) do
    case Registry.get_definition_by_name(row.status_type) do
      nil ->
        Logger.warning("Dropping persisted status with unknown type #{row.status_type}")
        state

      definition ->
        restore_known_status(row, definition, state)
    end
  end

  defp restore_known_status(row, definition, state) do
    if valid_restore_duration?(definition, row.remaining_ms) do
      params = [
        val1: row.val1,
        val2: row.val2,
        val3: row.val3,
        val4: row.val4,
        tick: row.tick,
        flag: row.flag,
        caster_id: row.source_id,
        duration: row.remaining_ms,
        loaded: true
      ]

      case StatusManager.handle_apply_status(definition.id, params, state) do
        {:reply, :ok, applied} ->
          applied

        {:reply, {:error, reason}, unchanged} ->
          Logger.warning("Status restore of #{row.status_type} failed: #{inspect(reason)}")
          unchanged
      end
    else
      Logger.warning(
        "Dropping persisted finite status #{row.status_type} with invalid remaining duration: #{inspect(row.remaining_ms)}"
      )

      state
    end
  end

  defp valid_restore_duration?(%{permanent: true}, _remaining_ms), do: true

  defp valid_restore_duration?(_definition, remaining_ms),
    do: is_integer(remaining_ms) and remaining_ms > 0

  defp row_for(%StatusEntry{} = entry, char_id, now_ms) do
    with definition when definition != nil <- Registry.get_definition(entry.type),
         false <- definition.no_save,
         {:ok, remaining_ms} <- remaining_ms(entry, now_ms),
         :ok <- validate_saved_duration(definition, entry, remaining_ms) do
      [
        %{
          char_id: char_id,
          status_type: Atom.to_string(entry.type),
          val1: entry.val1,
          val2: entry.val2,
          val3: entry.val3,
          val4: entry.val4,
          tick: entry.tick,
          flag: entry.flag,
          source_id: entry.source_id,
          remaining_ms: remaining_ms
        }
      ]
    else
      _no_save_or_expired -> []
    end
  end

  defp validate_saved_duration(%{permanent: true}, _entry, _remaining_ms), do: :ok

  defp validate_saved_duration(_definition, _entry, remaining_ms)
       when is_integer(remaining_ms) and remaining_ms > 0,
       do: :ok

  defp validate_saved_duration(_definition, %StatusEntry{type: type}, nil) do
    Logger.warning("Dropping non-permanent status #{type} without a finite expiry")
    :invalid_duration
  end

  defp validate_saved_duration(_definition, _entry, _remaining_ms), do: :invalid_duration

  defp remaining_ms(%StatusEntry{expires_at: nil}, _now_ms), do: {:ok, nil}

  defp remaining_ms(%StatusEntry{expires_at: expires_at}, now_ms)
       when is_integer(expires_at) and expires_at > now_ms,
       do: {:ok, expires_at - now_ms}

  defp remaining_ms(%StatusEntry{}, _now_ms), do: :expired

  defp saved_statuses_query(char_id) do
    from(cs in CharacterStatus, where: cs.char_id == ^char_id)
  end
end
