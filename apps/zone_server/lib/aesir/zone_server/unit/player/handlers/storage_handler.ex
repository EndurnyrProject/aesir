defmodule Aesir.ZoneServer.Unit.Player.Handlers.StorageHandler do
  @moduledoc """
  Opens/closes the account-wide Kafra storage window and moves items between
  the inventory and storage (design "Storage window lifecycle").

  `PlayerSession` is the single writer; every public function takes and returns
  the session `state` map and runs inside a `handle_cast`, mirroring
  `CartHandler`. `game_state.storage` doubles as the window state: `nil` means
  closed, a map means open (`ItemContainer`-shaped, same as inventory/cart).

  Every deposit/withdraw outcome (including rejections) reports a
  `StorageResult` to the client; the window itself only reports `StorageOpened`
  on open (there is no error result to report if `open/1` already sends
  `BASIC_SKILL_REQUIRED` on gate failure).
  """

  require Logger

  alias Aesir.Net.StorageResult
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Learned
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryManager
  alias Aesir.ZoneServer.Unit.Player.Handlers.StatsManager
  alias Aesir.ZoneServer.Unit.Player.Handlers.StorageOps
  alias Aesir.ZoneServer.Unit.Player.InventoryView
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Storage.Persistence, as: StoragePersistence

  @min_basic_skill_level 6

  @doc """
  Opens the account storage window.

  Rejected (state unchanged) with `StorageResult(STORAGE_BASIC_SKILL_REQUIRED)`
  when the learned `NV_BASIC` level is below #{@min_basic_skill_level}. When
  already open, re-sends the current `StorageOpened` without touching the
  database. Otherwise loads every row via `Storage.Persistence.load_storage/1`,
  indexes it into the session map, commits `game_state.storage`, and sends
  `StorageOpened`.
  """
  @spec open(map()) :: {:noreply, map()}
  def open(%{game_state: game_state} = state) do
    if basic_skill_level(game_state) >= @min_basic_skill_level do
      do_open(state)
    else
      Logger.debug(
        "Storage open rejected for #{game_state.character_id}: NV_BASIC < #{@min_basic_skill_level}"
      )

      send_result(state.connection_pid, :STORAGE_BASIC_SKILL_REQUIRED)
      {:noreply, state}
    end
  end

  @doc """
  Moves `amount` of the inventory item at the client `index` into storage.

  Rejected (no state change) with `StorageResult(STORAGE_NOT_OPEN)` when the
  window is closed and `STORAGE_INVALID_AMOUNT` when `amount` is not a
  positive integer, both before `StorageOps` is called. On success it commits
  both container maps and emits the paired client deltas (inventory
  `ItemRemoved` + storage `StorageItemAdded`) followed by
  `StorageResult(STORAGE_OK)`. A `StorageOps` error maps to its result code.
  """
  @spec deposit(non_neg_integer(), integer(), map()) :: {:noreply, map()}
  def deposit(index, amount, %{game_state: game_state} = state) do
    server_index = PlayerState.server_index(index)
    char_id = game_state.character_id

    with :ok <- ensure_open(game_state),
         :ok <- ensure_positive_amount(amount),
         {:ok, new_inventory, new_storage, inv_change, storage_change} <-
           StorageOps.deposit(
             game_state.account_id,
             char_id,
             game_state.inventory,
             game_state.storage,
             server_index,
             amount
           ) do
      committed =
        StatsManager.update_game_state(state, %{
          game_state
          | inventory: new_inventory,
            storage: new_storage
        })

      notify_inventory_removed(committed.connection_pid, inv_change, amount)
      notify_storage_added(committed.connection_pid, new_storage, storage_change)
      send_result(committed.connection_pid, :STORAGE_OK)

      {:noreply, committed}
    else
      {:error, reason} ->
        Logger.debug("Storage deposit rejected for #{char_id}: #{inspect(reason)}")
        send_result(state.connection_pid, error_code(reason))
        {:noreply, state}
    end
  end

  @doc """
  Moves `amount` of the storage item at the client `index` back into the inventory.

  Mirrors `deposit/3`: rejected the same way when the window is closed or
  `amount` is invalid, otherwise it commits both container maps and emits the
  paired client deltas (storage `StorageItemRemoved` + inventory `ItemAdded`)
  followed by `StorageResult(STORAGE_OK)`.
  """
  @spec withdraw(non_neg_integer(), integer(), map()) :: {:noreply, map()}
  def withdraw(index, amount, %{game_state: game_state} = state) do
    server_index = PlayerState.server_index(index)
    char_id = game_state.character_id

    with :ok <- ensure_open(game_state),
         :ok <- ensure_positive_amount(amount),
         {:ok, new_inventory, new_storage, inv_change, storage_change} <-
           StorageOps.withdraw(
             game_state.account_id,
             char_id,
             game_state.inventory,
             game_state.storage,
             game_state.stats,
             server_index,
             amount
           ) do
      committed =
        StatsManager.update_game_state(state, %{
          game_state
          | inventory: new_inventory,
            storage: new_storage
        })

      notify_storage_removed(committed.connection_pid, storage_change, amount)
      InventoryManager.notify_added(committed.connection_pid, new_inventory, inv_change)
      send_result(committed.connection_pid, :STORAGE_OK)

      {:noreply, committed}
    else
      {:error, reason} ->
        Logger.debug("Storage withdraw rejected for #{char_id}: #{inspect(reason)}")
        send_result(state.connection_pid, error_code(reason))
        {:noreply, state}
    end
  end

  @doc """
  Closes the storage window.

  Nothing is persisted: every mutation was already written through. A no-op
  when already closed.
  """
  @spec close(map()) :: {:noreply, map()}
  def close(%{game_state: %{storage: nil}} = state), do: {:noreply, state}

  def close(%{game_state: game_state} = state) do
    {:noreply, StatsManager.update_game_state(state, %{game_state | storage: nil})}
  end

  @spec do_open(map()) :: {:noreply, map()}
  defp do_open(%{game_state: %{storage: storage}} = state) when is_map(storage) do
    MessageRouter.send_to(state.connection_pid, InventoryView.storage_opened(storage))
    {:noreply, state}
  end

  defp do_open(%{game_state: game_state} = state) do
    storage =
      game_state.account_id
      |> StoragePersistence.load_storage()
      |> Enum.map(&StoragePersistence.to_session_item/1)
      |> PlayerState.from_list()

    committed = StatsManager.update_game_state(state, %{game_state | storage: storage})

    MessageRouter.send_to(committed.connection_pid, InventoryView.storage_opened(storage))
    {:noreply, committed}
  end

  @spec basic_skill_level(map()) :: non_neg_integer()
  defp basic_skill_level(%{stats: %{progression: %{learned_skills: learned}}}) do
    case Catalog.by_name(:nv_basic) do
      {:ok, %{id: id}} -> Learned.learned_level(learned, id)
      :error -> 0
    end
  end

  @spec ensure_open(map()) :: :ok | {:error, :not_open}
  defp ensure_open(%{storage: nil}), do: {:error, :not_open}
  defp ensure_open(%{storage: storage}) when is_map(storage), do: :ok

  @spec ensure_positive_amount(term()) :: :ok | {:error, :invalid_amount}
  defp ensure_positive_amount(amount) when is_integer(amount) and amount > 0, do: :ok
  defp ensure_positive_amount(_amount), do: {:error, :invalid_amount}

  # Maps a `StorageOps`/local guard error atom to its `StorageResultCode`.
  # `:not_found` and `:insufficient_amount` both surface as `STORAGE_INVALID_AMOUNT`
  # (design's Error Handling: "amount <= 0 or amount > held -> INVALID_AMOUNT").
  @spec error_code(atom()) :: atom()
  defp error_code(:storage_full), do: :STORAGE_FULL
  defp error_code(:inventory_full), do: :STORAGE_INVENTORY_FULL
  defp error_code(:overweight), do: :STORAGE_OVERWEIGHT
  defp error_code(:not_storable), do: :STORAGE_NOT_STORABLE
  defp error_code(:item_equipped), do: :STORAGE_ITEM_EQUIPPED
  defp error_code(:insufficient_amount), do: :STORAGE_INVALID_AMOUNT
  defp error_code(:not_found), do: :STORAGE_INVALID_AMOUNT
  defp error_code(:invalid_amount), do: :STORAGE_INVALID_AMOUNT
  defp error_code(:not_open), do: :STORAGE_NOT_OPEN

  defp error_code(reason) do
    Logger.warning("Unmapped storage error #{inspect(reason)}, reporting STORAGE_INVALID_AMOUNT")
    :STORAGE_INVALID_AMOUNT
  end

  @spec send_result(pid(), atom()) :: :ok
  defp send_result(connection_pid, code) do
    MessageRouter.send_to(connection_pid, %StorageResult{result: code})
  end

  @spec notify_inventory_removed(pid(), StorageOps.change(), pos_integer()) :: :ok
  defp notify_inventory_removed(connection_pid, change, amount) do
    MessageRouter.send_to(
      connection_pid,
      InventoryView.item_removed(removal_index(change), amount)
    )
  end

  @spec notify_storage_added(pid(), StorageOps.storage(), StorageOps.change()) :: :ok
  defp notify_storage_added(connection_pid, storage, change) do
    Enum.each(InventoryManager.affected_indices(change), fn index ->
      item = PlayerState.get_by_index(storage, index)
      MessageRouter.send_to(connection_pid, InventoryView.storage_item_added(item, index))
    end)
  end

  @spec notify_storage_removed(pid(), StorageOps.change(), pos_integer()) :: :ok
  defp notify_storage_removed(connection_pid, change, amount) do
    MessageRouter.send_to(
      connection_pid,
      InventoryView.storage_item_removed(removal_index(change), amount)
    )
  end

  @spec removal_index(StorageOps.change()) :: non_neg_integer()
  defp removal_index({:removed, index}), do: index
  defp removal_index({:reduced, index, _left}), do: index
end
