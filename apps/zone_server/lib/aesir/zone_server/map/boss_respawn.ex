defmodule Aesir.ZoneServer.Map.BossRespawn do
  @moduledoc """
  Durable shadow of a boss monster's in-memory respawn timer.

  `Coordinator` writes a row when a boss dies, alongside the live
  `Process.send_after` timer, and deletes it when the boss respawns. The
  timer is the sole live driver of the respawn; this table is never
  consulted while the server is running and exists only so a restart does
  not silently reset a camped boss's deadline (reconciled at boot).

  `write/3` never raises: a repo failure (validation or connection loss) is
  logged and swallowed, because losing durability for a single boss must not
  take down the coordinator or block the in-memory respawn that already
  drives the game.
  """

  import Ecto.Query

  require Logger

  alias Aesir.Commons.Models.BossRespawn, as: Row
  alias Aesir.Repo

  @doc """
  Writes the pending deadline row for a boss that just died.
  """
  @spec write(String.t(), integer(), DateTime.t()) :: :ok
  def write(map_name, mob_id, respawn_at) do
    attrs = %{
      map_name: map_name,
      mob_id: mob_id,
      respawn_at: DateTime.truncate(respawn_at, :second)
    }

    %Row{}
    |> Row.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, _row} ->
        :ok

      {:error, changeset} ->
        Logger.error(
          "Failed to persist boss respawn for #{map_name}/#{mob_id}: #{inspect(changeset.errors)}"
        )

        :ok
    end
  rescue
    error ->
      Logger.error(
        "Boss respawn persistence unavailable for #{map_name}/#{mob_id}: #{Exception.message(error)}"
      )

      :ok
  end

  @doc """
  Deletes the pending deadline row(s) for a boss that just respawned.

  A no-op, not an error, when no row matches -- the caller does not need to
  know whether a row existed.
  """
  @spec delete(String.t(), integer()) :: :ok
  def delete(map_name, mob_id) do
    Repo.delete_all(pending_query(map_name, mob_id))
    :ok
  rescue
    error ->
      Logger.error(
        "Failed to delete boss respawn row for #{map_name}/#{mob_id}: #{Exception.message(error)}"
      )

      :ok
  end

  @doc """
  Lists every pending boss respawn row, for boot reconciliation.
  """
  @spec list_pending() :: [Row.t()]
  def list_pending do
    Repo.all(Row)
  end

  defp pending_query(map_name, mob_id) do
    from(r in Row, where: r.map_name == ^map_name and r.mob_id == ^mob_id)
  end
end
