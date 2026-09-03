defmodule Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps do
  @moduledoc """
  Write-through orchestration between the pure inventory core and persistence.

  The pure core (`Aesir.ZoneServer.Unit.Inventory`) computes a new inventory map
  plus a change descriptor without touching the database. This module commits
  that change with **persist-first** semantics: it runs every row write inside a
  single `Persistence.transaction/1` and only returns the advanced inventory map
  when the commit succeeds. On any DB failure the transaction rolls back and the
  caller's in-memory state must stay exactly as it was.

  All multi-row changes (stack splits, card compounding, and equip-with-conflict,
  which unequips the conflicting items) run in one transaction so they roll back atomically.

  Inserted rows obtain their real DB `id` here; that id is reflected back into
  the returned inventory map so memory and the database never diverge.
  """

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Inventory.Persistence
  alias Aesir.ZoneServer.Unit.Inventory.Weight
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats

  @type inventory :: Inventory.t()

  @doc """
  Persists `change` and returns the advanced inventory map.

  `old_inventory` is the pre-change map (needed to locate rows to delete);
  `new_inventory` is the map the pure core produced. The whole change is wrapped
  in a single transaction. On success returns `{:ok, persisted_inventory}` where
  inserted items carry their real DB `id`; on failure returns `{:error, reason}`
  and nothing has been committed.
  """
  @spec apply_change(integer(), inventory(), inventory(), Inventory.change()) ::
          {:ok, inventory()} | {:error, term()}
  def apply_change(char_id, old_inventory, new_inventory, change) do
    Persistence.transaction(fn ->
      persist_change(char_id, old_inventory, new_inventory, change)
    end)
  end

  @spec set_slot(integer(), inventory(), non_neg_integer(), InventoryItem.t()) ::
          {:ok, inventory()} | {:error, term()}
  def set_slot(_char_id, inventory, index, %InventoryItem{} = item) do
    with {:ok, row} <- Persistence.update_item(item, %{bound: item.bound}) do
      {:ok, PlayerState.put_item(inventory, index, row)}
    end
  end

  @doc """
  Adds `amount` of `item_def`, enforcing max weight, then persists.

  Rejects with `{:error, :overweight}` before any DB write when the add would
  push the player past their max weight. Otherwise runs the pure `add`, persists
  the change, and returns `{:ok, persisted_inventory, change}`.
  """
  @spec add(integer(), inventory(), Stats.t(), ItemDefinition.t(), pos_integer(), map()) ::
          {:ok, inventory(), Inventory.change()} | {:error, term()}
  def add(char_id, inventory, %Stats{} = stats, %ItemDefinition{} = item_def, amount, opts \\ %{}) do
    if Weight.would_exceed?(inventory, stats, item_def.weight * amount) do
      {:error, :overweight}
    else
      with {:ok, new_inventory, change} <- Inventory.add(inventory, item_def, amount, opts),
           {:ok, persisted} <- apply_change(char_id, inventory, new_inventory, change) do
        {:ok, persisted, change}
      end
    end
  end

  @doc """
  Persists a prechecked batch of item additions in one transaction.

  Each entry is applied against the inventory returned by the previous entry,
  preserving stacking and stable session indices. Any failed row write rolls
  back the entire batch.
  """
  @spec add_many(
          integer(),
          inventory(),
          [{ItemDefinition.t(), pos_integer(), map()}]
        ) :: {:ok, inventory()} | {:error, term()}
  def add_many(char_id, inventory, entries) when is_list(entries) do
    Persistence.transaction(fn ->
      Enum.reduce_while(entries, {:ok, inventory}, &persist_add(char_id, &1, &2))
    end)
  end

  defp persist_add(char_id, {item_def, amount, opts}, {:ok, current}) do
    with {:ok, next, change} <- Inventory.add(current, item_def, amount, opts),
         {:ok, persisted} <- persist_change(char_id, current, next, change) do
      {:cont, {:ok, persisted}}
    else
      {:error, reason} -> {:halt, {:error, reason}}
    end
  end

  @doc """
  Whether `amount` of `item_def` can be added without a write.

  Runs the same checks `add/6` enforces before its DB write — max weight first,
  then slot availability — so a pre-check (e.g. ground-item pickup) can refuse
  before committing to an irreversible step. Returns `:ok`, `{:error, :overweight}`
  or `{:error, :inventory_full}`.
  """
  @spec can_add(inventory(), Stats.t(), ItemDefinition.t(), pos_integer()) ::
          :ok | {:error, :overweight | :inventory_full}
  def can_add(inventory, %Stats{} = stats, %ItemDefinition{} = item_def, amount) do
    cond do
      Weight.would_exceed?(inventory, stats, item_def.weight * amount) ->
        {:error, :overweight}

      match?({:error, :inventory_full}, Inventory.add(inventory, item_def, amount)) ->
        {:error, :inventory_full}

      true ->
        :ok
    end
  end

  @doc """
  Removes `amount` from the item at `index`, then persists.
  """
  @spec remove(integer(), inventory(), non_neg_integer(), pos_integer()) ::
          {:ok, inventory(), Inventory.change()} | {:error, term()}
  def remove(char_id, inventory, index, amount) do
    with {:ok, new_inventory, change} <- Inventory.remove(inventory, index, amount),
         {:ok, persisted} <- apply_change(char_id, inventory, new_inventory, change) do
      {:ok, persisted, change}
    end
  end

  @doc false
  @spec persist_change(integer(), inventory(), inventory(), Inventory.change()) ::
          {:ok, inventory()} | {:error, term()}
  def persist_change(char_id, _old, new_inventory, {:added, index, item}) do
    with {:ok, row} <- Persistence.insert_item(char_id, item_attrs(item)) do
      {:ok, PlayerState.put_item(new_inventory, index, row)}
    end
  end

  def persist_change(_char_id, old_inventory, new_inventory, {:stacked, index, amount}) do
    update_at(old_inventory, new_inventory, index, %{amount: amount})
  end

  def persist_change(
        char_id,
        old_inventory,
        new_inventory,
        {:split, [{topped_index, amount}, {new_index, _}]}
      ) do
    inserted = PlayerState.get_by_index(new_inventory, new_index)
    topped_row = PlayerState.get_by_index(old_inventory, topped_index)

    with {:ok, topped} <- Persistence.update_item(topped_row, %{amount: amount}),
         {:ok, inserted_row} <- Persistence.insert_item(char_id, item_attrs(inserted)) do
      {:ok,
       new_inventory
       |> PlayerState.put_item(topped_index, topped)
       |> PlayerState.put_item(new_index, inserted_row)}
    end
  end

  def persist_change(_char_id, old_inventory, new_inventory, {:removed, index}) do
    item = PlayerState.get_by_index(old_inventory, index)

    with {:ok, _deleted} <- Persistence.delete_item(item) do
      {:ok, new_inventory}
    end
  end

  def persist_change(_char_id, old_inventory, new_inventory, {:reduced, index, left}) do
    update_at(old_inventory, new_inventory, index, %{amount: left})
  end

  def persist_change(
        _char_id,
        old_inventory,
        new_inventory,
        {:card_compounded, card_index, equipment_index, card_field}
      ) do
    equipment = PlayerState.get_by_index(new_inventory, equipment_index)
    equipment_attrs = %{card_field => Map.fetch!(equipment, card_field)}

    case Map.get(new_inventory, card_index) do
      nil ->
        card = PlayerState.get_by_index(old_inventory, card_index)

        with {:ok, inventory} <-
               update_at(old_inventory, new_inventory, equipment_index, equipment_attrs),
             {:ok, _deleted} <- Persistence.delete_item(card) do
          {:ok, inventory}
        end

      %InventoryItem{amount: amount} ->
        with {:ok, inventory} <-
               update_at(old_inventory, new_inventory, card_index, %{amount: amount}) do
          update_at(old_inventory, inventory, equipment_index, equipment_attrs)
        end
    end
  end

  def persist_change(_char_id, old_inventory, new_inventory, {:identified, index}) do
    update_at(old_inventory, new_inventory, index, %{identify: 1})
  end

  def persist_change(
        _char_id,
        old_inventory,
        new_inventory,
        {:equipped, index, worn_mask, unequipped}
      ) do
    with {:ok, inventory} <- update_at(old_inventory, new_inventory, index, %{equip: worn_mask}) do
      unequip_rows(old_inventory, inventory, unequipped)
    end
  end

  def persist_change(_char_id, old_inventory, new_inventory, {:unequipped, index}) do
    update_at(old_inventory, new_inventory, index, %{equip: 0})
  end

  # Updates the row at `index` using the pre-change row (which carries the real
  # DB id and old value) as the changeset base so the diff is detected, then
  # reflects the persisted row back into the new inventory map.
  @spec update_at(inventory(), inventory(), non_neg_integer(), map()) ::
          {:ok, inventory()} | {:error, term()}
  defp update_at(old_inventory, new_inventory, index, attrs) do
    base = PlayerState.get_by_index(old_inventory, index)

    with {:ok, row} <- Persistence.update_item(base, attrs) do
      {:ok, PlayerState.put_item(new_inventory, index, row)}
    end
  end

  @spec unequip_rows(inventory(), inventory(), [non_neg_integer()]) ::
          {:ok, inventory()} | {:error, term()}
  defp unequip_rows(old_inventory, inventory, indices) do
    Enum.reduce_while(indices, {:ok, inventory}, fn index, {:ok, inv} ->
      case update_at(old_inventory, inv, index, %{equip: 0}) do
        {:ok, updated} -> {:cont, {:ok, updated}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  @spec item_attrs(InventoryItem.t()) :: map()
  defp item_attrs(%InventoryItem{} = item) do
    %{
      nameid: item.nameid,
      amount: item.amount,
      equip: item.equip,
      identify: item.identify,
      refine: item.refine,
      attribute: item.attribute,
      card0: item.card0,
      card1: item.card1,
      card2: item.card2,
      card3: item.card3,
      craft: item.craft,
      random_options: item.random_options,
      expire_time: item.expire_time,
      bound: item.bound,
      favorite: item.favorite,
      unique_id: item.unique_id,
      enchant_grade: item.enchant_grade
    }
  end
end
