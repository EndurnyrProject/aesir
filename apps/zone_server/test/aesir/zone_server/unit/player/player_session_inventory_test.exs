defmodule Aesir.ZoneServer.Unit.Player.PlayerSessionInventoryTest do
  use Aesir.DataCase, async: true
  use Mimic
  import ExUnit.CaptureLog

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Packets.ZcAckTakeoffEquip
  alias Aesir.ZoneServer.Packets.ZcAckWearEquip
  alias Aesir.ZoneServer.Packets.ZcInventoryEnd
  alias Aesir.ZoneServer.Packets.ZcInventoryItemlistEquip
  alias Aesir.ZoneServer.Packets.ZcInventoryItemlistNormal
  alias Aesir.ZoneServer.Packets.ZcInventoryStart
  alias Aesir.ZoneServer.Packets.ZcSpriteChange
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Inventory.Persistence
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats

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

  describe "equip/unequip orchestration" do
    setup %{account: account} do
      {:ok, character} =
        %Character{}
        |> Character.changeset(%{
          account_id: account.id,
          char_num: 1,
          name: "Equipper",
          class: 1,
          base_level: 99,
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

      %{equip_char: character}
    end

    test "equip request equips the item, acks success and broadcasts the sprite", %{
      equip_char: character
    } do
      Mimic.copy(Broadcast)
      # 1101 = Sword (right_hand, atk 25)
      seed_item(character.id, 1101, 1)
      {:ok, state} = PlayerSession.init(%{character: character, connection_pid: self()})

      server_index = index_of(state.game_state.inventory, 1101)
      bare_atk = state.game_state.stats.combat_stats.atk

      expect(Broadcast, :to_visible_players, fn _gs, %ZcSpriteChange{}, _opts -> :ok end)

      {:noreply, new_state} =
        PlayerSession.handle_cast(
          {:equip_item, PlayerState.client_index(server_index), 2},
          state
        )

      # Item now equipped in memory and persisted.
      assert new_state.game_state.inventory[server_index].equip == 2
      assert reload(character.id)[server_index].equip == 2

      # Stats reflect the +25 atk equipment bonus.
      assert new_state.game_state.stats.combat_stats.atk == bare_atk + 25

      ack = receive_packet_of_type(ZcAckWearEquip)
      assert ack.result == ZcAckWearEquip.result_ok()
      assert ack.wear_location == 2
    end

    test "equipping a two-hander emits a takeoff ack for the worn shield", %{
      equip_char: character
    } do
      Mimic.copy(Broadcast)
      stub(Broadcast, :to_visible_players, fn _gs, _packet, _opts -> :ok end)

      # Guard (2101) worn in left hand; Katana (1116) two-handed weapon.
      _shield = seed_equipped(character.id, 2101, 32)
      _katana = seed_item(character.id, 1116, 1)

      {:ok, state} = PlayerSession.init(%{character: character, connection_pid: self()})

      katana_index = index_of(state.game_state.inventory, 1116)
      shield_index = index_of(state.game_state.inventory, 2101)

      {:noreply, new_state} =
        PlayerSession.handle_cast(
          {:equip_item, PlayerState.client_index(katana_index), 34},
          state
        )

      # Katana equipped to both hands, shield cleared.
      assert new_state.game_state.inventory[katana_index].equip == 34
      assert new_state.game_state.inventory[shield_index].equip == 0
      assert reload(character.id)[shield_index].equip == 0

      wear_ack = receive_packet_of_type(ZcAckWearEquip)
      assert wear_ack.result == ZcAckWearEquip.result_ok()

      takeoff_ack = receive_packet_of_type(ZcAckTakeoffEquip)
      assert takeoff_ack.index == PlayerState.client_index(shield_index)
    end

    test "unequip request clears the item and acks success", %{equip_char: character} do
      Mimic.copy(Broadcast)
      stub(Broadcast, :to_visible_players, fn _gs, _packet, _opts -> :ok end)

      _sword = seed_equipped(character.id, 1101, 2)
      {:ok, state} = PlayerSession.init(%{character: character, connection_pid: self()})

      server_index = index_of(state.game_state.inventory, 1101)

      {:noreply, new_state} =
        PlayerSession.handle_cast(
          {:unequip_item, PlayerState.client_index(server_index)},
          state
        )

      assert new_state.game_state.inventory[server_index].equip == 0
      assert reload(character.id)[server_index].equip == 0

      ack = receive_packet_of_type(ZcAckTakeoffEquip)
      assert ack.result == ZcAckTakeoffEquip.result_success()
    end

    test "persist failure leaves inventory unchanged and acks failure", %{equip_char: character} do
      _sword = seed_item(character.id, 1101, 1)
      {:ok, state} = PlayerSession.init(%{character: character, connection_pid: self()})

      server_index = index_of(state.game_state.inventory, 1101)

      # Simulate a DB failure: the whole transaction rolls back.
      stub(Persistence, :transaction, fn _fun -> {:error, :persist_failed} end)

      {:noreply, new_state} =
        PlayerSession.handle_cast(
          {:equip_item, PlayerState.client_index(server_index), 2},
          state
        )

      # State untouched (persist-first), DB still unequipped.
      assert new_state.game_state.inventory[server_index].equip == 0
      assert reload(character.id)[server_index].equip == 0

      ack = receive_packet_of_type(ZcAckWearEquip)
      assert ack.result == ZcAckWearEquip.result_fail()
    end

    test "stale/invalid index yields a failure ack and no mutation", %{equip_char: character} do
      {:ok, state} = PlayerSession.init(%{character: character, connection_pid: self()})

      {:noreply, new_state} =
        PlayerSession.handle_cast({:equip_item, PlayerState.client_index(99), 2}, state)

      assert new_state.game_state.inventory == state.game_state.inventory

      ack = receive_packet_of_type(ZcAckWearEquip)
      assert ack.result == ZcAckWearEquip.result_fail()
    end
  end

  describe "spawn-time equipment derivation" do
    test "stats and appearance reflect equipped gear at spawn", %{account: account} do
      {:ok, character} =
        %Character{}
        |> Character.changeset(%{
          account_id: account.id,
          char_num: 2,
          name: "Geared",
          class: 1,
          base_level: 99,
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

      # Sword (1101) atk 25, view 0; equipped in right hand at login.
      seed_equipped(character.id, 1101, 2)

      bare = Stats.calculate_stats(Stats.from_character(character), character.id, [])

      {:ok, state} = PlayerSession.init(%{character: character, connection_pid: self()})

      # Equipment bonus applied at spawn from the worn sword.
      assert state.game_state.stats.combat_stats.atk == bare.combat_stats.atk + 25
      assert state.game_state.stats.equipment.right_hand == 1101
    end
  end

  defp reload(char_id) do
    {:ok, items} = Persistence.load_inventory(char_id)
    PlayerState.from_list(items)
  end

  defp index_of(inventory, nameid) do
    Enum.find_value(inventory, fn {index, item} ->
      if item.nameid == nameid, do: index
    end)
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
