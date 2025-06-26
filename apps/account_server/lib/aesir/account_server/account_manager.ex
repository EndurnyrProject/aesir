defmodule Aesir.AccountServer.AccountManager do
  @moduledoc """
  In-memory account management for testing.
  In production, this would interface with a database.
  """
  use GenServer

  require Logger

  defstruct accounts: %{}

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def authenticate(username, password) do
    GenServer.call(__MODULE__, {:authenticate, username, password})
  end

  def create_account(username, password, opts \\ []) do
    GenServer.call(__MODULE__, {:create_account, username, password, opts})
  end

  def get_account(account_id) do
    GenServer.call(__MODULE__, {:get_account, account_id})
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    state = %__MODULE__{
      accounts: %{
        "test" => %{
          id: 2_000_000,
          username: "test",
          password: "test123",
          level: 0,
          sex: "M",
          email: "test@example.com",
          banned: false,
          created_at: DateTime.utc_now()
        },
        "admin" => %{
          id: 2_000_001,
          username: "admin",
          password: "admin123",
          level: 99,
          sex: "M",
          email: "admin@example.com",
          banned: false,
          created_at: DateTime.utc_now()
        }
      }
    }

    Logger.info("AccountManager started with #{map_size(state.accounts)} test accounts")
    {:ok, state}
  end

  @impl true
  def handle_call({:authenticate, username, password}, _from, state) do
    case Map.get(state.accounts, username) do
      nil ->
        {:reply, {:error, :account_not_found}, state}

      account ->
        cond do
          account.banned ->
            {:reply, {:error, :banned}, state}

          account.password != password ->
            {:reply, {:error, :invalid_password}, state}

          true ->
            {:reply, {:ok, account}, state}
        end
    end
  end

  def handle_call({:create_account, username, password, opts}, _from, state) do
    if Map.has_key?(state.accounts, username) do
      {:reply, {:error, :username_taken}, state}
    else
      account_id = 2_000_000 + map_size(state.accounts)

      account = %{
        id: account_id,
        username: username,
        password: password,
        level: Keyword.get(opts, :level, 0),
        sex: Keyword.get(opts, :sex, "M"),
        email: Keyword.get(opts, :email, "#{username}@example.com"),
        banned: false,
        created_at: DateTime.utc_now()
      }

      new_state = %{state | accounts: Map.put(state.accounts, username, account)}
      Logger.info("Created account: #{username} (ID: #{account_id})")

      {:reply, {:ok, account}, new_state}
    end
  end

  def handle_call({:get_account, account_id}, _from, state) do
    account =
      Enum.find_value(state.accounts, fn {_username, acc} ->
        if acc.id == account_id, do: acc
      end)

    if account do
      {:reply, {:ok, account}, state}
    else
      {:reply, {:error, :not_found}, state}
    end
  end
end
