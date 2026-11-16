defmodule Aesir.ZoneServer.Unit.Player.Handlers.EggRefusalTest do
  use ExUnit.Case, async: false
  use Mimic

  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Npc.Shop, as: ShopData
  alias Aesir.ZoneServer.Unit.Player.Handlers.GuildStorageHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryManager
  alias Aesir.ZoneServer.Unit.Player.Handlers.StorageHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.Shop

  setup :set_mimic_private
  setup :verify_on_exit!

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})
    :ok
  end

  defp egg,
    do: %InventoryItem{
      id: 1,
      nameid: 501,
      amount: 1,
      card0: 256,
      attribute: 1,
      equip: 0,
      favorite: 0
    }

  defp player do
    character = %Character{
      id: 1,
      account_id: 1,
      name: "Test",
      class: 0,
      str: 1,
      agi: 1,
      vit: 1,
      int: 1,
      dex: 1,
      luk: 1
    }

    %{
      PlayerState.new(character)
      | inventory: %{0 => egg()},
        storage: %{},
        guild_storage: %{},
        guild_id: 42
    }
  end

  test "shop omits hatched eggs from the offer and rejects forged sales" do
    stub(ItemManagement, :get_item_by_id, fn 501 ->
      {:ok,
       %ItemDefinition{id: 501, aegis_name: "Potion", name: "Potion", type: :healing, sell: 25}}
    end)

    shop = %ShopData{
      id: "test",
      map: "prontera",
      x: 1,
      y: 1,
      dir: 0,
      sprite: 1,
      name: "test",
      items: []
    }

    assert {[], []} = Shop.build_open(shop, player())
    assert {:error, :unsellable} = Shop.compute_sell([{0, 1}], player())
  end

  test "personal and guild storage reject deposits silently" do
    gs = player()
    personal = %SessionState{game_state: gs, connection_pid: self()}
    guild = %{personal | guild_storage_ctx: %{guild_id: 42}}

    assert {:noreply, ^personal} =
             StorageHandler.deposit(PlayerState.client_index(0), 1, personal)

    refute_received {:send, :gameplay, _}
    assert {:noreply, ^guild} = GuildStorageHandler.deposit(PlayerState.client_index(0), 1, guild)
    refute_received {:send, :gameplay, _}
  end

  test "repair all does not resend a hatched egg" do
    state = %SessionState{game_state: player(), connection_pid: self()}
    assert {:noreply, _} = InventoryManager.handle_repair_all(state)
    refute_received {:send, :gameplay, _}
  end
end
