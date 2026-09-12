defmodule Aesir.ZoneServer.Mmo.Woe.Persistence do
  @moduledoc """
  Durable projection of WoE castle ownership, economy, and guardian state.

  `persist/2` asynchronously updates a `guild_castles` row's `guild_id`
  (ownership only, leaving economy/defense/investment/guardian/kafra fields
  untouched); `persist_economy/2` asynchronously writes the economy, defense,
  and the two daily investment counters; `persist_guardians/2` asynchronously
  writes the sorted list of hired guardian slots; `persist_kafra/2`
  asynchronously writes whether the castle's Kafra is hired. All are
  fire-and-forget, via the supervised `TaskSupervisor`. `load_all/0` reads
  every castle's full row for boot-time `CastleStore.hydrate/1`.

  Ownership, economy, guardian, and Kafra state are authoritative in
  `CastleStore` during a live node; the row is the restart-durable copy.
  """

  require Logger

  import Ecto.Query

  alias Aesir.Commons.Models.GuildCastle
  alias Aesir.Repo
  alias Aesir.ZoneServer.Mmo.Woe.CastleStore

  @task_supervisor Aesir.ZoneServer.TaskSupervisor

  @typedoc "Full durable state of one castle row."
  @type row :: %{
          guild_id: non_neg_integer() | nil,
          economy: 0..100,
          defense: 0..100,
          invested_economy: 0..2,
          invested_defense: 0..2,
          guardians: [0..7],
          kafra: boolean()
        }

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
    write_row(castle_id, %{guild_id: guild_id}, "ownership")
  end

  @doc """
  Asynchronously writes `castle_id`'s economy, defense, and daily investment
  counters.

  Fire-and-forget, on the same async/inline path as `persist/2`.
  """
  @spec persist_economy(non_neg_integer(), CastleStore.economy_state()) :: :ok
  def persist_economy(castle_id, economy_state) do
    run_async(fn -> do_persist_economy(castle_id, economy_state) end)
    :ok
  end

  @spec do_persist_economy(non_neg_integer(), CastleStore.economy_state()) :: :ok
  defp do_persist_economy(castle_id, economy_state) do
    write_row(castle_id, economy_state, "economy")
  end

  @doc """
  Asynchronously writes `castle_id`'s sorted list of hired guardian slots.

  Fire-and-forget, on the same async/inline path as `persist/2`.
  """
  @spec persist_guardians(non_neg_integer(), [0..7]) :: :ok
  def persist_guardians(castle_id, guardians) do
    run_async(fn -> do_persist_guardians(castle_id, guardians) end)
    :ok
  end

  @spec do_persist_guardians(non_neg_integer(), [0..7]) :: :ok
  defp do_persist_guardians(castle_id, guardians) do
    write_row(castle_id, %{guardians: guardians}, "guardians")
  end

  @doc """
  Asynchronously writes whether `castle_id`'s Kafra service is hired.

  Fire-and-forget, on the same async/inline path as `persist/2`.
  """
  @spec persist_kafra(non_neg_integer(), boolean()) :: :ok
  def persist_kafra(castle_id, hired?) do
    run_async(fn -> do_persist_kafra(castle_id, hired?) end)
    :ok
  end

  @spec do_persist_kafra(non_neg_integer(), boolean()) :: :ok
  defp do_persist_kafra(castle_id, hired?) do
    write_row(castle_id, %{kafra: hired?}, "kafra")
  end

  @doc """
  Returns `%{castle_id => row}` for every FE castle, owned or not.

  Used at boot to hydrate `CastleStore` with ownership, economy, and
  guardian state.
  """
  @spec load_all() :: %{non_neg_integer() => row()}
  def load_all do
    from(g in GuildCastle,
      select:
        {g.castle_id,
         %{
           guild_id: g.guild_id,
           economy: g.economy,
           defense: g.defense,
           invested_economy: g.invested_economy,
           invested_defense: g.invested_defense,
           guardians: g.guardians,
           kafra: g.kafra
         }}
    )
    |> Repo.all()
    |> Map.new()
  end

  # Shared update core for both `do_persist/2` and `do_persist_economy/2`: fetches
  # the row by `castle_id`, applies `attrs` through the changeset, and logs
  # (never raises) on a missing row or a changeset error, `label` naming what
  # was being persisted.
  @spec write_row(non_neg_integer(), map(), String.t()) :: :ok
  defp write_row(castle_id, attrs, label) do
    case Repo.get_by(GuildCastle, castle_id: castle_id) do
      nil ->
        Logger.warning(
          "guild_castles row missing for castle_id=#{castle_id}; #{label} not persisted"
        )

        :ok

      castle ->
        case Repo.update(GuildCastle.changeset(castle, attrs)) do
          {:ok, _updated} ->
            :ok

          {:error, reason} ->
            Logger.error("Failed to persist castle #{castle_id} #{label}: #{inspect(reason)}")

            :ok
        end
    end
  end

  defp run_async(fun) do
    if Application.get_env(:zone_server, :inline_persistence, false) do
      fun.()
    else
      Task.Supervisor.start_child(@task_supervisor, fun)
    end
  end
end
