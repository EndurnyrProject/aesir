defmodule Aesir.ZoneServer.Unit.Player.Handlers.NpcShopHandler do
  @moduledoc """
  Opens an NPC buy/sell shop window for the clicking player (design §7).

  A shop click is a single request/response: unlike a scripted NPC it starts no
  `Script.Interaction` coroutine and takes no `interaction_lock`. `open_window/2`
  gates the player against the shop cell with the NPC talk range, builds both the
  buy and sell lists through the pure `Unit.Shop` core, and sends one
  `NpcShopOpen`. Out of range (or on another map) it is a silent no-op.

  The handler runs inside a `PlayerSession` cast/call: it takes and returns the
  session `state` map and returns `{:noreply, state}`, matching the `NpcTalk`
  clause it is delegated from.
  """

  alias Aesir.Commons.StatusParams
  alias Aesir.Net.NpcBuyEntry
  alias Aesir.Net.NpcBuyRequest
  alias Aesir.Net.NpcBuyResult
  alias Aesir.Net.NpcSellEntry
  alias Aesir.Net.NpcSellRequest
  alias Aesir.Net.NpcSellResult
  alias Aesir.Net.NpcShopBuyItem
  alias Aesir.Net.NpcShopOpen
  alias Aesir.Net.NpcShopSellItem
  alias Aesir.Repo
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Npc.Shop, as: ShopData
  alias Aesir.ZoneServer.Npc.Shop.Registry, as: ShopRegistry
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Aesir.ZoneServer.Unit.Player.InventoryView
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.StatusSync
  alias Aesir.ZoneServer.Unit.Shop, as: ShopCore

  # rAthena clicks NPCs within `AREA_SIZE + 1` cells (`npc_checknear`,
  # src/map/npc.cpp); `AREA_SIZE` defaults to 14, so the talk gate is 15 cells
  # (Chebyshev). Intentionally separate from `Config.view_range/0`.
  @talk_range 15

  # The shared `Npc*Result.result` enum, in the design §5 order. Buy uses every
  # code; sell only surfaces ok / invalid / out_of_range.
  @result_ok 0
  @result_not_enough_zeny 1
  @result_overweight 2
  @result_no_slots 3
  @result_invalid 4
  @result_out_of_range 5

  @max_zeny 1_000_000_000

  @type state :: %{
          required(:connection_pid) => pid(),
          required(:game_state) => PlayerState.t(),
          optional(atom()) => term()
        }

  @doc """
  Opens `shop`'s window for the player when in talk range, otherwise a no-op.

  On success it builds the buy/sell lists via `Unit.Shop.build_open/2`, maps them
  to their wire structs, and sends one `NpcShopOpen` keyed by the shop's synthetic
  gid. Always returns `{:noreply, state}`; no `interaction_lock` is taken.
  """
  @spec open_window(state(), ShopData.t()) :: {:noreply, state()}
  def open_window(%{game_state: gs, connection_pid: connection_pid} = state, %ShopData{} = shop) do
    if in_talk_range?(gs, shop) do
      {buy_items, sell_items} = ShopCore.build_open(shop, gs)

      MessageRouter.send_to(connection_pid, %NpcShopOpen{
        unit_id: ShopRegistry.entity_id(shop),
        buy_items: Enum.map(buy_items, &to_buy_item/1),
        sell_items: Enum.map(sell_items, &to_sell_item/1)
      })
    end

    {:noreply, state}
  end

  @doc """
  Buys `request.items` from the shop identified by `request.unit_id`.

  Re-resolves the shop by gid and re-checks talk range (anti-forgery: the client
  never names a price or trusts the open-window list). On a valid, in-range,
  affordable request it commits every inventory add and the zeny debit inside one
  `Repo.transact`, so a partial buy can never persist; it then updates in-memory
  state, pushes one `ItemAdded` per touched slot, a zeny `ParamChange`, and
  `NpcBuyResult{ok}`. Any gate or transaction failure replies with the mapped
  result code and leaves inventory, zeny and the client view untouched. Always
  returns `{:noreply, state}`.
  """
  @spec buy(state(), NpcBuyRequest.t()) :: {:noreply, state()}
  def buy(%{game_state: gs, connection_pid: connection_pid} = state, %NpcBuyRequest{
        unit_id: unit_id,
        items: entries
      }) do
    requests = Enum.map(entries, fn %NpcBuyEntry{nameid: id, amount: a} -> {id, a} end)

    with {:ok, shop} <- fetch_in_range(gs, unit_id),
         {:ok, %{total_cost: total_cost, item_adds: item_adds}} <-
           ShopCore.compute_buy(shop, requests, gs),
         {:ok, inventory, changes} <-
           transact_buy(gs.character_id, gs.inventory, gs.zeny, total_cost, item_adds) do
      new_state = finalize_buy(state, inventory, changes, total_cost)
      reply(connection_pid, %NpcBuyResult{result: @result_ok})
      {:noreply, new_state}
    else
      {:error, reason} ->
        reply(connection_pid, %NpcBuyResult{result: buy_result_code(reason)})
        {:noreply, state}
    end
  end

  @doc """
  Sells `request.items` back to the shop identified by `request.unit_id`.

  Re-resolves the shop by gid and re-checks talk range (the player must be at a
  real shop, though selling itself is not restricted to the shop's buy list). On
  a valid, in-range request it commits every inventory removal and the zeny
  credit (clamped to `#{@max_zeny}`) inside one `Repo.transact`, so a partial
  sell can never persist; it then updates in-memory state, pushes one
  `ItemRemoved` per sold slot, a zeny `ParamChange`, and `NpcSellResult{ok}`. Any
  gate or transaction failure replies with the mapped result code and leaves
  inventory, zeny and the client view untouched. Always returns
  `{:noreply, state}`.
  """
  @spec sell(state(), NpcSellRequest.t()) :: {:noreply, state()}
  def sell(%{game_state: gs, connection_pid: connection_pid} = state, %NpcSellRequest{
        unit_id: unit_id,
        items: entries
      }) do
    requests =
      Enum.map(entries, fn %NpcSellEntry{inventory_index: index, amount: a} -> {index, a} end)

    with {:ok, _shop} <- fetch_in_range(gs, unit_id),
         {:ok, %{total_credit: total_credit, removals: removals}} <-
           ShopCore.compute_sell(requests, gs),
         {:ok, inventory} <-
           transact_sell(gs.character_id, gs.inventory, gs.zeny, total_credit, removals) do
      new_state = finalize_sell(state, inventory, removals, total_credit)
      reply(connection_pid, %NpcSellResult{result: @result_ok})
      {:noreply, new_state}
    else
      {:error, reason} ->
        reply(connection_pid, %NpcSellResult{result: sell_result_code(reason)})
        {:noreply, state}
    end
  end

  @spec fetch_in_range(PlayerState.t(), non_neg_integer()) ::
          {:ok, ShopData.t()} | {:error, :invalid | :out_of_range}
  defp fetch_in_range(gs, unit_id) do
    case ShopRegistry.fetch(unit_id) do
      {:ok, shop} -> if in_talk_range?(gs, shop), do: {:ok, shop}, else: {:error, :out_of_range}
      :error -> {:error, :invalid}
    end
  end

  @spec transact_buy(
          integer(),
          Inventory.t(),
          non_neg_integer(),
          non_neg_integer(),
          [{ItemDefinition.t(), pos_integer()}]
        ) :: {:ok, Inventory.t(), [Inventory.change()]} | {:error, term()}
  defp transact_buy(char_id, inventory, zeny, total_cost, item_adds) do
    new_zeny = zeny - total_cost

    result =
      Repo.transact(fn ->
        with {:ok, inv, changes} <- apply_buy_adds(char_id, inventory, item_adds),
             {:ok, _} <- CharacterPersistence.update_character(char_id, %{zeny: new_zeny}) do
          {:ok, {inv, changes}}
        end
      end)

    case result do
      {:ok, {inv, changes}} -> {:ok, inv, changes}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec apply_buy_adds(integer(), Inventory.t(), [{ItemDefinition.t(), pos_integer()}]) ::
          {:ok, Inventory.t(), [Inventory.change()]} | {:error, term()}
  defp apply_buy_adds(char_id, inventory, item_adds) do
    item_adds
    |> Enum.reduce_while({:ok, inventory, []}, fn {item_def, amount}, {:ok, current, changes} ->
      with {:ok, new_inv, change} <- Inventory.add(current, item_def, amount),
           {:ok, persisted} <- InventoryOps.apply_change(char_id, current, new_inv, change) do
        {:cont, {:ok, persisted, [change | changes]}}
      else
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, inv, changes} -> {:ok, inv, Enum.reverse(changes)}
      error -> error
    end
  end

  @spec transact_sell(
          integer(),
          Inventory.t(),
          non_neg_integer(),
          non_neg_integer(),
          [{non_neg_integer(), pos_integer()}]
        ) :: {:ok, Inventory.t()} | {:error, term()}
  defp transact_sell(char_id, inventory, zeny, total_credit, removals) do
    new_zeny = min(zeny + total_credit, @max_zeny)

    result =
      Repo.transact(fn ->
        with {:ok, inv} <- apply_sell_removals(char_id, inventory, removals),
             {:ok, _} <- CharacterPersistence.update_character(char_id, %{zeny: new_zeny}) do
          {:ok, inv}
        end
      end)

    case result do
      {:ok, inv} -> {:ok, inv}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec apply_sell_removals(integer(), Inventory.t(), [{non_neg_integer(), pos_integer()}]) ::
          {:ok, Inventory.t()} | {:error, term()}
  defp apply_sell_removals(char_id, inventory, removals) do
    Enum.reduce_while(removals, {:ok, inventory}, fn {index, amount}, {:ok, current} ->
      with {:ok, new_inv, change} <- Inventory.remove(current, index, amount),
           {:ok, persisted} <- InventoryOps.apply_change(char_id, current, new_inv, change) do
        {:cont, {:ok, persisted}}
      else
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  @spec finalize_sell(
          state(),
          Inventory.t(),
          [{non_neg_integer(), pos_integer()}],
          non_neg_integer()
        ) ::
          state()
  defp finalize_sell(%{game_state: gs} = state, inventory, removals, total_credit) do
    new_zeny = min(gs.zeny + total_credit, @max_zeny)
    new_gs = %{gs | inventory: inventory, zeny: new_zeny}

    notify_removed(state.connection_pid, removals)
    StatusSync.send_param(state.connection_pid, StatusParams.zeny(), new_zeny)

    %{state | game_state: new_gs}
  end

  @spec notify_removed(pid(), [{non_neg_integer(), pos_integer()}]) :: :ok
  defp notify_removed(connection_pid, removals) do
    Enum.each(removals, fn {index, amount} ->
      MessageRouter.send_to(connection_pid, InventoryView.item_removed(index, amount))
    end)
  end

  @spec finalize_buy(state(), Inventory.t(), [Inventory.change()], non_neg_integer()) :: state()
  defp finalize_buy(%{game_state: gs} = state, inventory, changes, total_cost) do
    new_zeny = gs.zeny - total_cost
    new_gs = %{gs | inventory: inventory, zeny: new_zeny}

    notify_added(state.connection_pid, inventory, changes)
    StatusSync.send_param(state.connection_pid, StatusParams.zeny(), new_zeny)

    %{state | game_state: new_gs}
  end

  @spec notify_added(pid(), Inventory.t(), [Inventory.change()]) :: :ok
  defp notify_added(connection_pid, inventory, changes) do
    Enum.each(changes, fn change ->
      Enum.each(affected_indices(change), fn index ->
        item = PlayerState.get_by_index(inventory, index)
        MessageRouter.send_to(connection_pid, InventoryView.item_added(item, index))
      end)
    end)
  end

  @spec affected_indices(Inventory.change()) :: [non_neg_integer()]
  defp affected_indices({:added, index, _item}), do: [index]
  defp affected_indices({:stacked, index, _total}), do: [index]

  defp affected_indices({:split, [{topped_index, _}, {new_index, _}]}),
    do: [topped_index, new_index]

  @spec buy_result_code(atom()) :: non_neg_integer()
  defp buy_result_code(:not_enough_zeny), do: @result_not_enough_zeny
  defp buy_result_code(:overweight), do: @result_overweight
  defp buy_result_code(:no_slots), do: @result_no_slots
  defp buy_result_code(:out_of_range), do: @result_out_of_range
  defp buy_result_code(_), do: @result_invalid

  # Sell shares the §5 enum but only ever yields ok / out_of_range / invalid;
  # `:invalid_item`, `:insufficient_amount`, `:unsellable` and a forged gid all
  # collapse to the generic invalid code.
  @spec sell_result_code(atom()) :: non_neg_integer()
  defp sell_result_code(:out_of_range), do: @result_out_of_range
  defp sell_result_code(_), do: @result_invalid

  @spec reply(pid(), NpcBuyResult.t() | NpcSellResult.t()) :: :ok
  defp reply(connection_pid, result) do
    MessageRouter.send_to(connection_pid, result)
  end

  @spec in_talk_range?(PlayerState.t(), ShopData.t()) :: boolean()
  defp in_talk_range?(%PlayerState{map_name: map, x: x, y: y}, %ShopData{map: map} = shop) do
    Geometry.in_tile_range?(x, y, shop.x, shop.y, @talk_range)
  end

  defp in_talk_range?(_gs, _shop), do: false

  @spec to_buy_item(ShopCore.buy_item()) :: NpcShopBuyItem.t()
  defp to_buy_item(%{nameid: nameid, type: type, price: price}) do
    %NpcShopBuyItem{nameid: nameid, type: type, price: price}
  end

  @spec to_sell_item(ShopCore.sell_item()) :: NpcShopSellItem.t()
  defp to_sell_item(%{
         inventory_index: index,
         nameid: nameid,
         type: type,
         amount: amount,
         sell_price: sell_price
       }) do
    %NpcShopSellItem{
      inventory_index: index,
      nameid: nameid,
      type: type,
      amount: amount,
      sell_price: sell_price
    }
  end
end
