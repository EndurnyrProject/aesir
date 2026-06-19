defmodule Aesir.ZoneServer.Unit.Player.PlayerSessionInventoryTest do
  use Aesir.DataCase, async: true
  use Mimic
  import ExUnit.CaptureLog

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Packets.ZcInventoryEnd
  alias Aesir.ZoneServer.Packets.ZcInventoryItemlistEquip
  alias Aesir.ZoneServer.Packets.ZcInventoryItemlistNormal
  alias Aesir.ZoneServer.Packets.ZcInventoryStart
  alias Aesir.ZoneServer.Unit.Inventory.Persistence
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup :verify_on_exit!
  setup :set_mimic_from_context
  setup :setup_ets_tables

  setup do
    Mimic.copy(Persistence)

    :ok
  end

  # Seeds an inventory row directly through Persistence (the pure domain core no
  # longer touches the DB). Returns the inserted item.
  defp seed_item(char_id, nameid, amount, attrs \\ %{}) do
    {:ok, item} =
      Persistence.insert_item(char_id, Map.merge(%{nameid: nameid, amount: amount}, attrs))

    item
  end

  defp seed_equipped(char_id, nameid, equip) do
    seed_item(char_id, nameid, 1, %{equip: equip})
  end

  setup do
    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        username: "testuser",
        userid: "testuser",
        user_pass: "password",
        email: "test@test.com"
      })
      |> Repo.insert()

    {:ok, character} =
      %Character{}
      |> Character.changeset(%{
        account_id: account.id,
        char_num: 0,
        name: "TestChar",
        class: 1,
        last_map: "prontera",
        last_x: 50,
        last_y: 50,
        str: 10,
        agi: 10,
        vit: 10,
        int: 10,
        dex: 10,
        luk: 10
      })
      |> Repo.insert()

    %{account: account, character: character}
  end

  describe "inventory initialization" do
    test "initializes with empty inventory", %{character: character} do
      connection_pid = self()

      {:ok, state} =
        PlayerSession.init(%{
          character: character,
          connection_pid: connection_pid
        })

      assert state.game_state.inventory == %{}
    end

    test "loads existing inventory items on init", %{character: character} do
      # Add some items to character's inventory
      # 5 Red Potions
      seed_item(character.id, 501, 5)
      # 1 Knife
      seed_item(character.id, 1201, 1)

      connection_pid = self()

      {:ok, state} =
        PlayerSession.init(%{
          character: character,
          connection_pid: connection_pid
        })

      # Verify inventory was loaded
      items = PlayerState.to_list(state.game_state.inventory)
      assert length(items) == 2

      nameids = Enum.map(items, & &1.nameid)
      assert 501 in nameids
      assert 1201 in nameids
    end

    test "handles equipped items correctly", %{character: character} do
      # Add items - one for inventory, one for equipment
      seed_item(character.id, 501, 10)
      seed_equipped(character.id, 1201, 2)

      connection_pid = self()

      {:ok, state} =
        PlayerSession.init(%{
          character: character,
          connection_pid: connection_pid
        })

      # Verify both items are loaded
      items = PlayerState.to_list(state.game_state.inventory)
      assert length(items) == 2

      # Find equipped and non-equipped items
      equipped_items = Enum.filter(items, &(&1.equip > 0))
      inventory_items = Enum.filter(items, &(&1.equip == 0))

      assert length(equipped_items) == 1
      assert length(inventory_items) == 1

      equipped_item = List.first(equipped_items)
      inventory_item = List.first(inventory_items)

      assert equipped_item.nameid == 1201
      assert equipped_item.equip == 2
      assert inventory_item.nameid == 501
      assert inventory_item.equip == 0
    end

    test "fails initialization when inventory load fails", %{character: character} do
      # Mock inventory load to fail
      expect(Persistence, :load_inventory, fn _char_id ->
        {:error, :database_error}
      end)

      connection_pid = self()

      {result, _log} =
        with_log(fn ->
          PlayerSession.init(%{
            character: character,
            connection_pid: connection_pid
          })
        end)

      assert {:stop, {:error, :inventory_load_failed}} = result
    end
  end

  describe "inventory packets" do
    test "frames the inventory with start/normal/equip/end during LoadEndAck", %{
      character: character
    } do
      # Add some inventory items
      seed_item(character.id, 501, 5)
      seed_equipped(character.id, 1201, 2)

      # Initialize player session
      {:ok, state} =
        PlayerSession.init(%{
          character: character,
          connection_pid: self()
        })

      # Simulate LoadEndAck packet (0x007D)
      {:noreply, _new_state} =
        PlayerSession.handle_info(
          {:packet, 0x007D, %{}},
          state
        )

      # Verify the modern framing packets were sent (may receive other packets first)
      _start = receive_packet_of_type(ZcInventoryStart)
      _normal = receive_packet_of_type(ZcInventoryItemlistNormal)
      _equip = receive_packet_of_type(ZcInventoryItemlistEquip)
      _end = receive_packet_of_type(ZcInventoryEnd)
    end

    test "normal itemlist contains only non-equipped items", %{character: character} do
      # Add inventory items(some equipped, some not)
      # Not equipped
      seed_item(character.id, 501, 5)
      # Not equipped
      seed_item(character.id, 1750, 100)
      # Equipped weapon
      seed_equipped(character.id, 1201, 2)

      # Initialize player session
      {:ok, state} =
        PlayerSession.init(%{
          character: character,
          connection_pid: self()
        })

      # Simulate LoadEndAck
      {:noreply, _new_state} =
        PlayerSession.handle_info(
          {:packet, 0x007D, %{}},
          state
        )

      # Capture and verify normal itemlist packet (may receive other packets first)
      normal_itemlist = receive_packet_of_type(ZcInventoryItemlistNormal)

      # Should only contain non-equipped items (potion and arrows)
      assert length(normal_itemlist.items) == 2

      nameids = Enum.map(normal_itemlist.items, & &1.nameid)
      # Potion
      assert 501 in nameids
      # Arrows
      assert 1750 in nameids
      # Weapon (equipped)
      refute 1201 in nameids
    end

    test "equipitem list contains only equipped items", %{character: character} do
      # Add inventory items
      # Not equipped
      seed_item(character.id, 501, 5)
      # Equipped weapon (right hand)
      seed_equipped(character.id, 1201, 2)
      # Equipped armor
      seed_equipped(character.id, 2301, 16)

      # Initialize player session
      {:ok, state} =
        PlayerSession.init(%{
          character: character,
          connection_pid: self()
        })

      # Simulate LoadEndAck
      {:noreply, _new_state} =
        PlayerSession.handle_info(
          {:packet, 0x007D, %{}},
          state
        )

      # Capture and verify equipitem list packet (may receive other packets first)
      equipitem_list = receive_packet_of_type(ZcInventoryItemlistEquip)

      # Should only contain equipped items
      assert length(equipitem_list.items) == 2

      nameids = Enum.map(equipitem_list.items, & &1.nameid)
      # Weapon
      assert 1201 in nameids
      # Armor
      assert 2301 in nameids
      # Potion (not equipped)
      refute 501 in nameids

      # Verify equipment positions reflect the worn bitmask
      weapon_item = Enum.find(equipitem_list.items, &(&1.nameid == 1201))
      armor_item = Enum.find(equipitem_list.items, &(&1.nameid == 2301))

      # Right hand
      assert weapon_item.location == 2
      # Armor slot
      assert armor_item.location == 16
    end

    test "uses a unified, non-colliding client index space across both lists", %{
      character: character
    } do
      # Ordered by DB id: index 0 -> potion (normal), index 1 -> weapon (equip)
      seed_item(character.id, 501, 5)
      seed_equipped(character.id, 1201, 2)

      {:ok, state} =
        PlayerSession.init(%{character: character, connection_pid: self()})

      {:noreply, _new_state} =
        PlayerSession.handle_info({:packet, 0x007D, %{}}, state)

      normal_itemlist = receive_packet_of_type(ZcInventoryItemlistNormal)
      equipitem_list = receive_packet_of_type(ZcInventoryItemlistEquip)

      # +2 client offset, unified index space, no collision
      assert [%{index: 2, nameid: 501}] = normal_itemlist.items
      assert [%{index: 3, nameid: 1201}] = equipitem_list.items
    end

    test "sends empty lists framed by start/end when no inventory items", %{character: character} do
      # Initialize player session with no items
      {:ok, state} =
        PlayerSession.init(%{
          character: character,
          connection_pid: self()
        })

      # Simulate LoadEndAck
      {:noreply, _new_state} =
        PlayerSession.handle_info(
          {:packet, 0x007D, %{}},
          state
        )

      # Should still send the framing with empty lists
      assert_receive {:send_packet, %ZcInventoryStart{}}
      assert_receive {:send_packet, %ZcInventoryItemlistNormal{items: []}}
      assert_receive {:send_packet, %ZcInventoryItemlistEquip{items: []}}
      assert_receive {:send_packet, %ZcInventoryEnd{}}
    end
  end

  describe "inventory state management" do
    test "get_state returns current inventory items", %{character: character} do
      # Add some items
      seed_item(character.id, 501, 5)
      seed_item(character.id, 1201, 1)

      # Initialize player session
      {:ok, state} =
        PlayerSession.init(%{
          character: character,
          connection_pid: self()
        })

      # For this test, we'll use the state directly since we can't call get_state on a mock process
      items = PlayerState.to_list(state.game_state.inventory)
      assert length(items) == 2

      nameids = Enum.map(items, & &1.nameid)
      assert 501 in nameids
      assert 1201 in nameids
    end

    test "inventory persists through player session lifecycle", %{character: character} do
      # Seed an already-modified inventory: 3 potions left, weapon equipped.
      seed_item(character.id, 501, 3)
      seed_equipped(character.id, 1201, 2)

      # Initialize new player session (simulating login)
      {:ok, state} =
        PlayerSession.init(%{
          character: character,
          connection_pid: self()
        })

      # Verify state reflects the modified inventory
      items = PlayerState.to_list(state.game_state.inventory)
      assert length(items) == 2

      # Find the items
      potion_item = Enum.find(items, &(&1.nameid == 501))
      weapon_item = Enum.find(items, &(&1.nameid == 1201))

      # 5 - 2 = 3 remaining
      assert potion_item.amount == 3
      # Not equipped
      assert potion_item.equip == 0

      # Still 1 weapon
      assert weapon_item.amount == 1
      # Equipped in right hand
      assert weapon_item.equip == 2
    end
  end

  # Helper function to receive a specific packet type
  defp receive_packet_of_type(expected_type, timeout \\ 1000) do
    receive do
      {:send_packet, packet} ->
        if packet.__struct__ == expected_type do
          packet
        else
          receive_packet_of_type(expected_type, timeout)
        end
    after
      timeout ->
        flunk("Expected packet of type #{expected_type} not received within #{timeout}ms")
    end
  end
end
