defmodule Aesir.ZoneServer.Unit.Player.Handlers.GuildStorageOps do
  @moduledoc """
  Write-through orchestration between inventory and guild storage.

  Both sides of a transfer and its audit row commit in one database transaction.
  Audit failure deliberately rolls the movement back because an untracked movement
  is worse than a rejected transfer.
  """

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Guild.Storage
  alias Aesir.ZoneServer.Guild.Storage.Lock
  alias Aesir.ZoneServer.Guild.Storage.Persistence
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Inventory.Weight
  alias Aesir.ZoneServer.Unit.ItemContainer
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats

  @typedoc "Transfer identity, lock owner, and active guild storage capacity."
  @type ctx :: %{
          required(:guild_id) => integer(),
          required(:char_id) => integer(),
          required(:session_pid) => pid(),
          required(:capacity) => pos_integer()
        }

  @typedoc "Both persisted container maps plus their change descriptors."
  @type transfer_result ::
          {:ok, Inventory.t(), Storage.t(), Inventory.change(), Inventory.change()}
          | {:error, term()}

  @doc "Moves an inventory item into guild storage atomically."
  @spec deposit(ctx(), Inventory.t(), Storage.t(), non_neg_integer(), pos_integer()) ::
          transfer_result()
  def deposit(ctx, inventory, storage, index, amount)
      when is_integer(amount) and amount > 0 do
    with {:ok, item} <- fetch(inventory, index, amount),
         {:ok, %ItemDefinition{} = item_def} <- ItemManagement.get_item_by_id(item.nameid),
         :ok <- Storage.depositable(item, item_def),
         {:ok, new_inventory, inv_change} <- Inventory.remove(inventory, index, amount),
         {:ok, new_storage, storage_change} <-
           add_to_storage(storage, item_def, amount, ctx.capacity, item),
         {:ok, persisted_inventory, persisted_storage} <-
           transact(
             ctx,
             inventory,
             new_inventory,
             inv_change,
             storage,
             new_storage,
             storage_change,
             {item, amount}
           ) do
      {:ok, persisted_inventory, persisted_storage, inv_change, storage_change}
    end
  end

  @doc "Moves a guild storage item into inventory atomically."
  @spec withdraw(
          ctx(),
          Inventory.t(),
          Storage.t(),
          Stats.t(),
          non_neg_integer(),
          pos_integer()
        ) :: transfer_result()
  def withdraw(ctx, inventory, storage, %Stats{} = stats, index, amount)
      when is_integer(amount) and amount > 0 do
    with {:ok, item} <- fetch(storage, index, amount),
         {:ok, %ItemDefinition{} = item_def} <- ItemManagement.get_item_by_id(item.nameid),
         :ok <- ensure_inventory_capacity(inventory, stats, item_def.weight * amount),
         {:ok, new_storage, storage_change} <- Storage.remove(storage, index, amount),
         {:ok, new_inventory, inv_change} <-
           ItemContainer.add_preserving(
             inventory,
             item_def,
             amount,
             Inventory.capacity(),
             item
           ),
         {:ok, persisted_inventory, persisted_storage} <-
           transact(
             ctx,
             inventory,
             new_inventory,
             inv_change,
             storage,
             new_storage,
             storage_change,
             {item, -amount}
           ) do
      {:ok, persisted_inventory, persisted_storage, inv_change, storage_change}
    end
  end

  defp transact(
         ctx,
         old_inventory,
         new_inventory,
         inv_change,
         old_storage,
         new_storage,
         storage_change,
         {audit_item, audit_amount}
       ) do
    result =
      Persistence.transaction(fn ->
        with :ok <- ensure_holder(ctx),
             {:ok, persisted_inventory} <-
               InventoryOps.apply_change(
                 ctx.char_id,
                 old_inventory,
                 new_inventory,
                 inv_change
               ),
             {:ok, persisted_storage} <-
               persist(ctx.guild_id, old_storage, new_storage, storage_change),
             :ok <- Persistence.log(ctx.guild_id, ctx.char_id, audit_item, audit_amount) do
          {:ok, {persisted_inventory, persisted_storage}}
        end
      end)

    case result do
      {:ok, {persisted_inventory, persisted_storage}} ->
        {:ok, persisted_inventory, persisted_storage}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp add_to_storage(storage, item_def, amount, capacity, item) do
    case Storage.add(storage, item_def, amount, capacity, item) do
      {:error, :inventory_full} -> {:error, :storage_full}
      result -> result
    end
  end

  defp ensure_holder(%{guild_id: guild_id, session_pid: session_pid}) do
    if Lock.held_by?(guild_id, session_pid), do: :ok, else: {:error, :not_holder}
  end

  defp persist(guild_id, _old_storage, new_storage, {:added, index, item}) do
    with {:ok, row} <- Persistence.insert_item(guild_id, Persistence.to_row_attrs(item)) do
      {:ok, PlayerState.put_item(new_storage, index, %{item | id: row.id})}
    end
  end

  defp persist(guild_id, old_storage, new_storage, {:stacked, index, amount}) do
    update_at(guild_id, old_storage, new_storage, index, amount)
  end

  defp persist(guild_id, old_storage, new_storage, {:reduced, index, amount}) do
    update_at(guild_id, old_storage, new_storage, index, amount)
  end

  defp persist(guild_id, old_storage, new_storage, {:removed, index}) do
    old_item = PlayerState.get_by_index(old_storage, index)

    with :ok <- Persistence.delete_item(guild_id, old_item.id, old_item.amount) do
      {:ok, new_storage}
    end
  end

  defp persist(
         guild_id,
         old_storage,
         new_storage,
         {:split, [{topped_index, amount}, {new_index, _}]}
       ) do
    inserted = PlayerState.get_by_index(new_storage, new_index)

    with {:ok, storage} <-
           update_at(guild_id, old_storage, new_storage, topped_index, amount),
         {:ok, row} <- Persistence.insert_item(guild_id, Persistence.to_row_attrs(inserted)) do
      {:ok, PlayerState.put_item(storage, new_index, %{inserted | id: row.id})}
    end
  end

  defp update_at(guild_id, old_storage, new_storage, index, amount) do
    old_item = PlayerState.get_by_index(old_storage, index)

    with :ok <- Persistence.update_amount(guild_id, old_item.id, old_item.amount, amount) do
      {:ok, new_storage}
    end
  end

  defp ensure_inventory_capacity(inventory, stats, added_weight) do
    if Weight.would_exceed?(inventory, stats, added_weight),
      do: {:error, :overweight},
      else: :ok
  end

  defp fetch(container, index, amount) do
    case Map.get(container, index) do
      nil -> {:error, :not_found}
      %InventoryItem{amount: held} when held < amount -> {:error, :insufficient_amount}
      %InventoryItem{} = item -> {:ok, item}
    end
  end
end
