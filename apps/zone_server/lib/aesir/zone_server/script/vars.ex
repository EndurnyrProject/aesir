defmodule Aesir.ZoneServer.Script.Vars do
  @moduledoc """
  Backing stores for the script variable scopes that live outside a single
  player's state (rAthena `$`, `$@`, `#`/`##`, `.`).

  Char-scoped vars (`.@`, `@`, plain) live on `PlayerState` and route through
  the player session; the scopes here are shared and are read/written directly
  from the running interaction:

  - **`$` server permanent** — Postgres write/read-through
    (`Aesir.Commons.Models.ServerVariable`). Cluster-wide via the shared DB.
  - **`$@` server temp** — a node-local ETS table, cleared on restart
    (matching rAthena's per-server-process temp globals).
  - **`#`/`##` account** — Postgres write/read-through
    (`Aesir.Commons.Models.AccountVariable`), keyed by `{account_id, name}`
    where `name` carries the scope sigil.
  - **`.` NPC** — a node-local ETS table keyed by `{npc_source, name}`, where
    `npc_source` is the NPC module tag from `Ctx.source`. Server-lifetime,
    shared across every placement of that script, never persisted.

  Values are jsonb-wrapped as `%{"v" => value}` at the DB boundary so a bare
  integer or string round trips through one column; ETS holds the raw value.
  """

  alias Aesir.Commons.Models.AccountVariable
  alias Aesir.Commons.Models.ServerVariable
  alias Aesir.Repo
  alias Aesir.ZoneServer.EtsTable

  @doc "Reads the `$` server permanent variable `name`, or `default` if unset."
  @spec get_server(String.t(), term()) :: term()
  def get_server(name, default) do
    case Repo.get(ServerVariable, name) do
      %ServerVariable{value: %{"v" => value}} -> value
      _ -> default
    end
  end

  @doc "Upserts the `$` server permanent variable `name` to `value`."
  @spec put_server(String.t(), term()) :: :ok
  def put_server(name, value) do
    %ServerVariable{}
    |> ServerVariable.changeset(%{name: name, value: %{"v" => value}})
    |> Repo.insert!(on_conflict: {:replace, [:value]}, conflict_target: :name)

    :ok
  end

  @doc "Reads the `$@` server temp variable `name`, or `default` if unset."
  @spec get_server_temp(String.t(), term()) :: term()
  def get_server_temp(name, default) do
    case :ets.lookup(EtsTable.table_for(:server_temp_vars), name) do
      [{^name, value}] -> value
      [] -> default
    end
  end

  @doc "Sets the `$@` server temp variable `name` to `value`."
  @spec put_server_temp(String.t(), term()) :: :ok
  def put_server_temp(name, value) do
    :ets.insert(EtsTable.table_for(:server_temp_vars), {name, value})
    :ok
  end

  @doc "Reads account variable `name` for `account_id`, or `default` if unset."
  @spec get_account(integer(), String.t(), term()) :: term()
  def get_account(account_id, name, default) do
    case Repo.get_by(AccountVariable, account_id: account_id, name: name) do
      %AccountVariable{value: %{"v" => value}} -> value
      _ -> default
    end
  end

  @doc "Upserts account variable `name` for `account_id` to `value`."
  @spec put_account(integer(), String.t(), term()) :: :ok
  def put_account(account_id, name, value) do
    %AccountVariable{}
    |> AccountVariable.changeset(%{account_id: account_id, name: name, value: %{"v" => value}})
    |> Repo.insert!(on_conflict: {:replace, [:value]}, conflict_target: [:account_id, :name])

    :ok
  end

  @doc "Reads the `.` NPC variable `name` for `source`, or `default` if unset."
  @spec get_npc(term(), String.t(), term()) :: term()
  def get_npc(source, name, default) do
    case :ets.lookup(EtsTable.table_for(:npc_vars), {source, name}) do
      [{_key, value}] -> value
      [] -> default
    end
  end

  @doc "Sets the `.` NPC variable `name` for `source` to `value`."
  @spec put_npc(term(), String.t(), term()) :: :ok
  def put_npc(source, name, value) do
    :ets.insert(EtsTable.table_for(:npc_vars), {{source, name}, value})
    :ok
  end
end
