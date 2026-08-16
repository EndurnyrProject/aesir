defmodule Aesir.ZoneServer.Mmo.Woe.Persistence do
  @moduledoc """
  Durable projection of WoE castle ownership.

  `persist/2` asynchronously updates a `guild_castles` row keyed by `castle_id`
  (fire-and-forget, via the supervised `TaskSupervisor`), and `load_all/0` reads
  the occupied rows for boot-time `CastleStore.hydrate/1`.

  Ownership is authoritative in `CastleStore` during a live node; the row is
  the restart-durable copy. Only `guild_id` (and `updated_at`) is ever touched —
  `economy`/`defense` are Phase-2 placeholders that must survive writes.
  """

  require Logger

  import Ecto.Query

  alias Aesir.Commons.Models.GuildCastle
  alias Aesir.Repo

  @task_supervisor Aesir.ZoneServer.TaskSupervisor

  @doc """
  Asynchronously records `guild_id` as the owner of `castle_id` (`nil` releases).

  Fire-and-forget: returns `:ok` immediately and performs the update on the
  supervised task supervisor, never blocking the caller (a `PlayerSession` or
  `Woe.Server`). Update failures are logged, not raised.
  """
  @spec persist(non_neg_integer(), non_neg_integer() | nil) :: :ok
  def persist(castle_id, guild_id) do
    run_async(fn -> do_persist(castle_id, guild_id) end)
    :ok
  end

  # Synchronous write core: updates the `guild_castles` row keyed by `castle_id`,
  # setting only `guild_id`. Runs in the caller's process when the
  # `:inline_persistence` app env flag is set.
  @spec do_persist(non_neg_integer(), non_neg_integer() | nil) :: :ok
  defp do_persist(castle_id, guild_id) do
    case Repo.get_by(GuildCastle, castle_id: castle_id) do
      nil ->
        Logger.warning(
          "guild_castles row missing for castle_id=#{castle_id}; ownership not persisted"
        )

        :ok

      castle ->
        case Repo.update(GuildCastle.changeset(castle, %{guild_id: guild_id})) do
          {:ok, _updated} ->
            :ok

          {:error, reason} ->
            Logger.error("Failed to persist castle #{castle_id} ownership: #{inspect(reason)}")

            :ok
        end
    end
  end

  @doc """
  Returns `%{castle_id => guild_id}` for all occupied castles.

  Unoccupied castles (`guild_id` nil) are excluded; used at boot to hydrate
  `CastleStore`.
  """
  @spec load_all() :: %{non_neg_integer() => non_neg_integer()}
  def load_all do
    from(g in GuildCastle, where: not is_nil(g.guild_id), select: {g.castle_id, g.guild_id})
    |> Repo.all()
    |> Map.new()
  end

  defp run_async(fun) do
    if Application.get_env(:zone_server, :inline_persistence, false) do
      fun.()
    else
      Task.Supervisor.start_child(@task_supervisor, fun)
    end
  end
end
