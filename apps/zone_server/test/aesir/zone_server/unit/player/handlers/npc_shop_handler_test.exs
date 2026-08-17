defmodule Aesir.ZoneServer.Unit.Player.Handlers.NpcShopHandlerTest do
  @moduledoc """
  Click-routing + open-window coverage for the NPC shop handler.

  Drives the real `PacketHandler` `NpcTalk` clause so the shop branch (ahead of
  the scripted-NPC dialog path) is exercised end to end. The shop data source
  (`Npc.Shops`) and the pure `Unit.Shop` core are stubbed so the test stays
  focused on routing, the talk-range gate, and the row -> packet mapping.
  """

  use ExUnit.Case, async: false
  use Mimic

  alias Aesir.Net.NpcShopBuyItem
  alias Aesir.Net.NpcShopOpen
  alias Aesir.Net.NpcShopSellItem
  alias Aesir.Net.NpcTalk
  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry
  alias Aesir.ZoneServer.Npc.Shop
  alias Aesir.ZoneServer.Npc.Shops
  alias Aesir.ZoneServer.Unit.Player.Handlers.PacketHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Shop, as: ShopCore

  defmodule TalkNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 200, y: 200, dir: 0, sprite: 58, name: "Talker"}]

    @impl true
    def on_talk(ctx) do
      ctx |> mes("hi") |> next() |> close()
    end
  end

  setup :set_mimic_from_context

  setup do
    Mimic.copy(Shops)
    Mimic.copy(ShopCore)
    :ok
  end

  defp shop do
    %Shop{
      id: "prontera_tool_dealer",
      map: "prontera",
      x: 152,
      y: 151,
      dir: 4,
      sprite: 85,
      name: "Tool Dealer",
      items: [%{nameid: 501, price: 50}]
    }
  end

  defp state(x, y) do
    %{
      game_state: %PlayerState{
        character_id: 1,
        account_id: 100,
        map_name: "prontera",
        x: x,
        y: y
      },
      connection_pid: self(),
      interaction_lock: nil
    }
  end

  test "clicking a shop in range opens the window without taking the interaction lock" do
    shop = shop()
    gid = Shop.Registry.entity_id(shop)
    stub(Shops, :all, fn -> %{"prontera" => [shop]} end)

    stub(ShopCore, :build_open, fn ^shop, _gs ->
      {[%{nameid: 501, type: 3, price: 50}],
       [%{inventory_index: 0, nameid: 909, type: 3, amount: 5, sell_price: 2}]}
    end)

    {:noreply, new_state} = PacketHandler.handle_message(%NpcTalk{npc_id: gid}, state(150, 150))

    assert new_state.interaction_lock == nil

    assert_receive {:send, _ch,
                    {:npc_shop_open,
                     %NpcShopOpen{
                       unit_id: ^gid,
                       buy_items: [%NpcShopBuyItem{nameid: 501, type: 3, price: 50}],
                       sell_items: [
                         %NpcShopSellItem{
                           inventory_index: 0,
                           nameid: 909,
                           type: 3,
                           amount: 5,
                           sell_price: 2
                         }
                       ]
                     }}}
  end

  test "clicking a scripted NPC still starts the dialog interaction (no shop branch)" do
    NpcRegistry.reload([TalkNpc])
    {:ok, {_module, npc_placement}} = NpcRegistry.module_at("prontera", 200, 200)
    gid = NpcRegistry.entity_id(npc_placement)
    stub(Shops, :all, fn -> %{} end)

    {:noreply, new_state} = PacketHandler.handle_message(%NpcTalk{npc_id: gid}, state(200, 200))

    assert {pid, ref, ^gid} = new_state.interaction_lock
    assert is_pid(pid)
    assert is_reference(ref)
    assert Process.alive?(pid)
    refute_received {:send, _ch, {:npc_shop_open, _}}
  end

  test "an out-of-range shop click does not open the window" do
    shop = shop()
    gid = Shop.Registry.entity_id(shop)
    stub(Shops, :all, fn -> %{"prontera" => [shop]} end)

    {:noreply, new_state} = PacketHandler.handle_message(%NpcTalk{npc_id: gid}, state(10, 10))

    assert new_state.interaction_lock == nil
    refute_received {:send, _ch, {:npc_shop_open, _}}
  end
end
