defmodule Aesir.ZoneServer.Unit.Player.Handlers.GuildStorageHandler do
  @moduledoc """
  Owns the guild storage window lifecycle and inventory transfers for a player session.

  `game_state.guild_storage` is `nil` while closed and an item-container map while open.
  The session's `guild_storage_ctx` carries the claimed guild, holder identity, and
  open-time capacity until the window closes.
  """

  require Logger

  alias Aesir.Net.StorageResult
  alias Aesir.ZoneServer.Guild.Manager
  alias Aesir.ZoneServer.Guild.Permissions
  alias Aesir.ZoneServer.Guild.Storage
  alias Aesir.ZoneServer.Guild.Storage.Lock
  alias Aesir.ZoneServer.Guild.Storage.Persistence
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Unit.Player.Handlers.GuildStorageOps
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryManager
  alias Aesir.ZoneServer.Unit.Player.Handlers.StatsManager
  alias Aesir.ZoneServer.Unit.Player.InventoryView
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState

  @doc "Opens the player's guild storage window when every access gate passes."
  @spec open(SessionState.t()) :: {:noreply, SessionState.t()}
  def open(
        %SessionState{
          game_state: %{guild_storage: storage},
          guild_storage_ctx: %{capacity: capacity}
        } = state
      )
      when is_map(storage) do
    MessageRouter.send_to(
      state.connection_pid,
      InventoryView.storage_opened(storage, capacity, :STORAGE_KIND_GUILD)
    )

    {:noreply, state}
  end

  def open(%SessionState{game_state: %{guild_id: 0}} = state) do
    send_result(state.connection_pid, :STORAGE_NO_GUILD)
    {:noreply, state}
  end

  def open(%SessionState{game_state: game_state} = state) do
    with {:ok, guild} <- Manager.ensure_started(game_state.guild_id),
         capacity when capacity > 0 <- Storage.capacity(guild),
         true <- Permissions.can?(guild, game_state.character_id, :storage),
         nil <- game_state.storage,
         :ok <- Lock.claim(game_state.guild_id, game_state.character_id, self()) do
      load_and_open(state, capacity)
    else
      0 ->
        reject_open(state, :STORAGE_GUILD_NO_SKILL)

      false ->
        reject_open(state, :STORAGE_GUILD_NO_PERMISSION)

      storage when is_map(storage) ->
        reject_open(state, :STORAGE_OTHER_STORAGE_OPEN)

      {:error, :not_found} ->
        reject_open(state, :STORAGE_NO_GUILD)

      {:error, :in_use} ->
        reject_open(state, :STORAGE_GUILD_IN_USE)

      {:error, reason} ->
        raise "guild storage open failed: #{inspect(reason)}"
    end
  end

  @doc "Moves an inventory item into the currently open guild storage."
  @spec deposit(non_neg_integer(), integer(), SessionState.t()) ::
          {:noreply, SessionState.t()}
  def deposit(_index, _amount, %SessionState{game_state: %{guild_storage: nil}} = state) do
    send_result(state.connection_pid, :STORAGE_NOT_OPEN)
    {:noreply, state}
  end

  def deposit(
        _index,
        _amount,
        %SessionState{
          game_state: %{guild_id: current_guild_id, guild_storage: storage},
          guild_storage_ctx: %{guild_id: claimed_guild_id}
        } = state
      )
      when is_map(storage) and claimed_guild_id != current_guild_id do
    reject_stale_claim(state)
  end

  def deposit(
        index,
        amount,
        %SessionState{game_state: game_state, guild_storage_ctx: ctx} = state
      )
      when is_map(game_state.guild_storage) and is_map(ctx) do
    server_index = PlayerState.server_index(index)

    with :ok <- ensure_positive_amount(amount),
         {:ok, inventory, storage, inventory_change, storage_change} <-
           GuildStorageOps.deposit(
             ctx,
             game_state.inventory,
             game_state.guild_storage,
             server_index,
             amount
           ) do
      committed =
        StatsManager.update_game_state(state, %{
          game_state
          | inventory: inventory,
            guild_storage: storage
        })

      notify_inventory_removed(committed.connection_pid, inventory_change, amount)
      notify_storage_added(committed.connection_pid, storage, storage_change)
      send_result(committed.connection_pid, :STORAGE_OK)
      {:noreply, committed}
    else
      {:error, reason} ->
        send_result(state.connection_pid, error_code(reason))
        {:noreply, state}
    end
  end

  @doc "Moves a guild storage item back into the player's inventory."
  @spec withdraw(non_neg_integer(), integer(), SessionState.t()) ::
          {:noreply, SessionState.t()}
  def withdraw(_index, _amount, %SessionState{game_state: %{guild_storage: nil}} = state) do
    send_result(state.connection_pid, :STORAGE_NOT_OPEN)
    {:noreply, state}
  end

  def withdraw(
        _index,
        _amount,
        %SessionState{
          game_state: %{guild_id: current_guild_id, guild_storage: storage},
          guild_storage_ctx: %{guild_id: claimed_guild_id}
        } = state
      )
      when is_map(storage) and claimed_guild_id != current_guild_id do
    reject_stale_claim(state)
  end

  def withdraw(
        index,
        amount,
        %SessionState{game_state: game_state, guild_storage_ctx: ctx} = state
      )
      when is_map(game_state.guild_storage) and is_map(ctx) do
    server_index = PlayerState.server_index(index)

    with :ok <- ensure_positive_amount(amount),
         {:ok, inventory, storage, inventory_change, storage_change} <-
           GuildStorageOps.withdraw(
             ctx,
             game_state.inventory,
             game_state.guild_storage,
             game_state.stats,
             server_index,
             amount
           ) do
      committed =
        StatsManager.update_game_state(state, %{
          game_state
          | inventory: inventory,
            guild_storage: storage
        })

      notify_storage_removed(committed.connection_pid, storage_change, amount)
      InventoryManager.notify_added(committed.connection_pid, inventory, inventory_change)
      send_result(committed.connection_pid, :STORAGE_OK)
      {:noreply, committed}
    else
      {:error, reason} ->
        send_result(state.connection_pid, error_code(reason))
        {:noreply, state}
    end
  end

  @doc "Closes guild storage and releases its claim; a no-op when already closed."
  @spec close(SessionState.t()) :: {:noreply, SessionState.t()}
  def close(%SessionState{game_state: %{guild_storage: nil}} = state), do: {:noreply, state}
  def close(state), do: {:noreply, force_close(state)}

  @doc "Closes guild storage without client consent and releases its claim when open."
  @spec force_close(SessionState.t()) :: SessionState.t()
  def force_close(
        %SessionState{
          game_state: game_state,
          guild_storage_ctx: %{guild_id: guild_id, session_pid: session_pid}
        } = state
      ) do
    :ok = Lock.release(guild_id, session_pid)
    committed = StatsManager.update_game_state(state, %{game_state | guild_storage: nil})
    %{committed | guild_storage_ctx: nil}
  end

  def force_close(
        %SessionState{game_state: %{guild_storage: nil}, guild_storage_ctx: nil} = state
      ),
      do: state

  @spec reject_open(SessionState.t(), atom()) :: {:noreply, SessionState.t()}
  defp reject_open(state, code) do
    send_result(state.connection_pid, code)
    {:noreply, state}
  end

  @spec reject_stale_claim(SessionState.t()) :: {:noreply, SessionState.t()}
  defp reject_stale_claim(state) do
    closed = force_close(state)
    send_result(closed.connection_pid, :STORAGE_STALE)
    {:noreply, closed}
  end

  @spec load_and_open(SessionState.t(), pos_integer()) :: {:noreply, SessionState.t()}
  defp load_and_open(%SessionState{game_state: game_state} = state, capacity) do
    storage =
      game_state.guild_id
      |> Persistence.load_storage()
      |> Enum.map(&Persistence.to_session_item/1)
      |> PlayerState.from_list()

    ctx = %{
      guild_id: game_state.guild_id,
      char_id: game_state.character_id,
      session_pid: self(),
      capacity: capacity
    }

    committed = StatsManager.update_game_state(state, %{game_state | guild_storage: storage})
    committed = %{committed | guild_storage_ctx: ctx}

    MessageRouter.send_to(
      committed.connection_pid,
      InventoryView.storage_opened(storage, capacity, :STORAGE_KIND_GUILD)
    )

    {:noreply, committed}
  end

  @spec ensure_positive_amount(term()) :: :ok | {:error, :invalid_amount}
  defp ensure_positive_amount(amount) when is_integer(amount) and amount > 0, do: :ok
  defp ensure_positive_amount(_amount), do: {:error, :invalid_amount}

  @spec error_code(term()) :: atom()
  defp error_code(:storage_full), do: :STORAGE_FULL
  defp error_code(:inventory_full), do: :STORAGE_INVENTORY_FULL
  defp error_code(:overweight), do: :STORAGE_OVERWEIGHT
  defp error_code(:not_storable), do: :STORAGE_NOT_STORABLE
  defp error_code(:item_equipped), do: :STORAGE_ITEM_EQUIPPED
  defp error_code(:rental), do: :STORAGE_RENTAL
  defp error_code(:no_guild_storage), do: :STORAGE_NO_GUILD_STORAGE
  defp error_code(:not_holder), do: :STORAGE_STALE
  defp error_code(:stale), do: :STORAGE_STALE
  defp error_code(:insufficient_amount), do: :STORAGE_INVALID_AMOUNT
  defp error_code(:not_found), do: :STORAGE_INVALID_AMOUNT
  defp error_code(:invalid_amount), do: :STORAGE_INVALID_AMOUNT
  defp error_code(:not_open), do: :STORAGE_NOT_OPEN

  defp error_code(reason) do
    Logger.error("Guild storage transfer failed: #{inspect(reason)}")
    :STORAGE_STALE
  end

  @spec send_result(pid(), atom()) :: :ok
  defp send_result(connection_pid, code) do
    MessageRouter.send_to(connection_pid, %StorageResult{result: code})
  end

  @spec notify_inventory_removed(pid(), term(), pos_integer()) :: :ok
  defp notify_inventory_removed(connection_pid, change, amount) do
    MessageRouter.send_to(
      connection_pid,
      InventoryView.item_removed(removal_index(change), amount)
    )
  end

  @spec notify_storage_added(pid(), Storage.t(), term()) :: :ok
  defp notify_storage_added(connection_pid, storage, change) do
    Enum.each(InventoryManager.affected_indices(change), fn index ->
      item = PlayerState.get_by_index(storage, index)

      MessageRouter.send_to(
        connection_pid,
        InventoryView.storage_item_added(item, index, :STORAGE_KIND_GUILD)
      )
    end)
  end

  @spec notify_storage_removed(pid(), term(), pos_integer()) :: :ok
  defp notify_storage_removed(connection_pid, change, amount) do
    MessageRouter.send_to(
      connection_pid,
      InventoryView.storage_item_removed(
        removal_index(change),
        amount,
        0,
        :STORAGE_KIND_GUILD
      )
    )
  end

  @spec removal_index(term()) :: non_neg_integer()
  defp removal_index({:removed, index}), do: index
  defp removal_index({:reduced, index, _left}), do: index
end
