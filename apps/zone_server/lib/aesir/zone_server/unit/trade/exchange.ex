defmodule Aesir.ZoneServer.Unit.Trade.Exchange do
  @moduledoc """
  Atomically exchanges the items and zeny in two player trade offers.

  Offered rows and character balances are re-read under database locks. The
  supplied inventories and stats are confirm-time snapshots used for capacity
  checks and for constructing the deltas each player session applies locally.
  """

  import Ecto.Query

  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Repo
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Inventory.Persistence
  alias Aesir.ZoneServer.Unit.Inventory.Weight
  alias Aesir.ZoneServer.Unit.ItemContainer
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Trade
  alias Aesir.ZoneServer.Unit.Trade.Offer
  alias Aesir.ZoneServer.Unit.Zeny

  @type side :: %{
          char_id: integer(),
          offer: Offer.t(),
          inventory: Inventory.t(),
          stats: Stats.t()
        }

  @type delta :: %{
          inventory: Inventory.t(),
          item_changes: [Inventory.change()],
          zeny: non_neg_integer()
        }

  @doc """
  Exchanges both sides' offers in one database transaction.
  """
  @spec run(side(), side()) :: {:ok, %{a: delta(), b: delta()}} | {:error, term()}
  def run(%{char_id: char_a} = side_a, %{char_id: char_b} = side_b) when char_a != char_b do
    Repo.transact(fn -> transact(side_a, side_b) end)
  end

  def run(%{char_id: char_id}, %{char_id: char_id}), do: {:error, :same_character}

  defp transact(side_a, side_b) do
    with {:ok, characters} <- fetch_characters(side_a.char_id, side_b.char_id),
         rows <- fetch_rows(side_a.offer, side_b.offer),
         {:ok, offered_a} <- validate_offer(side_a, rows),
         {:ok, offered_b} <- validate_offer(side_b, rows),
         {:ok, new_zeny_a, new_zeny_b} <- validate_zeny(side_a, side_b, characters),
         :ok <- validate_capacity(side_a, offered_b, offered_a),
         :ok <- validate_capacity(side_b, offered_a, offered_b),
         {:ok, inventory_a, removed_a} <- remove_offered(side_a.inventory, offered_a),
         {:ok, inventory_b, removed_b} <- remove_offered(side_b.inventory, offered_b),
         {:ok, inventory_a, added_a} <- add_offered(side_a.char_id, inventory_a, offered_b),
         {:ok, inventory_b, added_b} <- add_offered(side_b.char_id, inventory_b, offered_a),
         :ok <- persist_zeny(side_a.char_id, characters[side_a.char_id].zeny, new_zeny_a),
         :ok <- persist_zeny(side_b.char_id, characters[side_b.char_id].zeny, new_zeny_b) do
      {:ok,
       %{
         a: %{
           inventory: inventory_a,
           item_changes: removed_a ++ added_a,
           zeny: new_zeny_a
         },
         b: %{
           inventory: inventory_b,
           item_changes: removed_b ++ added_b,
           zeny: new_zeny_b
         }
       }}
    end
  end

  defp fetch_characters(char_a, char_b) do
    characters =
      Character
      |> where([character], character.id in ^[char_a, char_b])
      |> order_by([character], character.id)
      |> lock("FOR UPDATE")
      |> Repo.all()
      |> Map.new(&{&1.id, &1})

    if map_size(characters) == 2,
      do: {:ok, characters},
      else: {:error, :character_not_found}
  end

  defp fetch_rows(offer_a, offer_b) do
    row_ids =
      (offer_a.entries ++ offer_b.entries)
      |> Enum.map(& &1.row_id)
      |> Enum.sort()

    InventoryItem
    |> where([item], item.id in ^row_ids)
    |> order_by([item], item.id)
    |> lock("FOR UPDATE")
    |> Repo.all()
    |> Map.new(&{&1.id, &1})
  end

  defp validate_offer(side, rows) do
    Enum.reduce_while(side.offer.entries, {:ok, []}, fn entry, {:ok, offered} ->
      with %InventoryItem{} = row <- Map.get(rows, entry.row_id),
           :ok <- validate_owner(row, side.char_id),
           :ok <- validate_amount(row, entry.amount),
           {:ok, %ItemDefinition{} = item_def} <- ItemManagement.get_item_by_id(row.nameid),
           :ok <- Trade.offerable?(row, item_def) do
        {:cont, {:ok, [%{row: row, amount: entry.amount, item_def: item_def} | offered]}}
      else
        nil -> {:halt, {:error, :item_not_found}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, offered} -> {:ok, Enum.reverse(offered)}
      error -> error
    end
  end

  defp validate_owner(%InventoryItem{char_id: char_id}, char_id), do: :ok
  defp validate_owner(%InventoryItem{}, _char_id), do: {:error, :item_not_owned}

  defp validate_amount(%InventoryItem{amount: amount}, offered) when amount >= offered, do: :ok
  defp validate_amount(%InventoryItem{}, _offered), do: {:error, :insufficient_amount}

  defp validate_zeny(side_a, side_b, characters) do
    zeny_a = characters[side_a.char_id].zeny
    zeny_b = characters[side_b.char_id].zeny
    new_a = zeny_a - side_a.offer.zeny + side_b.offer.zeny
    new_b = zeny_b - side_b.offer.zeny + side_a.offer.zeny

    cond do
      zeny_a < side_a.offer.zeny or zeny_b < side_b.offer.zeny ->
        {:error, :not_enough_zeny}

      new_a > Zeny.max_zeny() or new_b > Zeny.max_zeny() ->
        {:error, :zeny_overflow}

      true ->
        {:ok, new_a, new_b}
    end
  end

  defp validate_capacity(side, incoming, outgoing) do
    net_weight = offered_weight(incoming) - offered_weight(outgoing)

    if Weight.would_exceed?(side.inventory, side.stats, net_weight),
      do: {:error, :overweight},
      else: :ok
  end

  defp offered_weight(offered) do
    Enum.reduce(offered, 0, fn %{amount: amount, item_def: item_def}, total ->
      total + item_def.weight * amount
    end)
  end

  defp remove_offered(inventory, offered) do
    Enum.reduce_while(offered, {:ok, inventory, []}, fn offered_item, {:ok, current, changes} ->
      case remove_one(current, offered_item) do
        {:ok, updated, change} -> {:cont, {:ok, updated, [change | changes]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, inventory, changes} -> {:ok, inventory, Enum.reverse(changes)}
      error -> error
    end
  end

  defp remove_one(inventory, %{row: row, amount: amount}) do
    with {:ok, index} <- find_index(inventory, row.id) do
      persist_removal(inventory, index, row, amount)
    end
  end

  defp persist_removal(inventory, index, %InventoryItem{amount: amount} = row, amount) do
    with {:ok, _} <- Persistence.delete_item(row) do
      {:ok, PlayerState.delete_index(inventory, index), {:removed, index}}
    end
  end

  defp persist_removal(inventory, index, row, amount) do
    left = row.amount - amount

    with {:ok, persisted} <- Persistence.update_item(row, %{amount: left}) do
      {:ok, PlayerState.put_item(inventory, index, persisted), {:reduced, index, left}}
    end
  end

  defp find_index(inventory, row_id) do
    case Enum.find(inventory, fn {_index, item} -> item.id == row_id end) do
      {index, _item} -> {:ok, index}
      nil -> {:error, :inventory_mismatch}
    end
  end

  defp add_offered(char_id, inventory, offered) do
    Enum.reduce_while(offered, {:ok, inventory, []}, fn offered_item, {:ok, current, changes} ->
      %{row: source, amount: amount, item_def: item_def} = offered_item

      with {:ok, new_inventory, change} <-
             ItemContainer.add_preserving(
               current,
               item_def,
               amount,
               Inventory.capacity(),
               source
             ),
           {:ok, persisted} <- persist_change(char_id, current, new_inventory, change) do
        {:cont, {:ok, persisted, [change | changes]}}
      else
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, inventory, changes} -> {:ok, inventory, Enum.reverse(changes)}
      error -> error
    end
  end

  defp persist_change(char_id, _old, new_inventory, {:added, index, item}) do
    with {:ok, row} <- Persistence.insert_item(char_id, item_attrs(item)) do
      {:ok, PlayerState.put_item(new_inventory, index, row)}
    end
  end

  defp persist_change(_char_id, old, new_inventory, {:stacked, index, amount}) do
    update_at(old, new_inventory, index, %{amount: amount})
  end

  defp persist_change(char_id, old, new_inventory, {
         :split,
         [{topped_index, amount}, {new_index, _}]
       }) do
    inserted = PlayerState.get_by_index(new_inventory, new_index)
    topped = PlayerState.get_by_index(old, topped_index)

    with {:ok, topped_row} <- Persistence.update_item(topped, %{amount: amount}),
         {:ok, inserted_row} <- Persistence.insert_item(char_id, item_attrs(inserted)) do
      {:ok,
       new_inventory
       |> PlayerState.put_item(topped_index, topped_row)
       |> PlayerState.put_item(new_index, inserted_row)}
    end
  end

  defp update_at(old, new_inventory, index, attrs) do
    with {:ok, row} <- Persistence.update_item(PlayerState.get_by_index(old, index), attrs) do
      {:ok, PlayerState.put_item(new_inventory, index, row)}
    end
  end

  defp item_attrs(item) do
    Map.take(item, [
      :nameid,
      :amount,
      :equip,
      :identify,
      :refine,
      :attribute,
      :card0,
      :card1,
      :card2,
      :card3,
      :craft,
      :random_options,
      :expire_time,
      :bound,
      :favorite,
      :unique_id,
      :equip_switch,
      :enchant_grade
    ])
  end

  defp persist_zeny(_char_id, zeny, zeny), do: :ok

  defp persist_zeny(char_id, _old_zeny, new_zeny) do
    case CharacterPersistence.update_character(char_id, %{zeny: new_zeny}) do
      {:ok, _character} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end
