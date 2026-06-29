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

  alias Aesir.Net.NpcShopBuyItem
  alias Aesir.Net.NpcShopOpen
  alias Aesir.Net.NpcShopSellItem
  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Npc.Shop, as: ShopData
  alias Aesir.ZoneServer.Npc.Shop.Registry, as: ShopRegistry
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Shop, as: ShopCore

  # rAthena clicks NPCs within `AREA_SIZE + 1` cells (`npc_checknear`,
  # src/map/npc.cpp); `AREA_SIZE` defaults to 14, so the talk gate is 15 cells
  # (Chebyshev). Intentionally separate from `Config.view_range/0`.
  @talk_range 15

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
