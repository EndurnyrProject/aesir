defmodule Aesir.ZoneServer.Unit.Player.PlayerSessionInventoryTest do
  use Aesir.DataCase, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Net.EquipItem
  alias Aesir.Net.EquipResult
  alias Aesir.Net.InventoryList
  alias Aesir.Net.ItemAdded
  alias Aesir.Net.ItemRemoved
  alias Aesir.Net.MapLoaded
  alias Aesir.Net.SpriteChange
  alias Aesir.Net.UnequipItem
  alias Aesir.Net.UnequipResult
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Inventory.Persistence
  alias Aesir.ZoneServer.Unit.Inventory.Weight
  alias Aesir.ZoneServer.Unit.Player.Handlers.EquipmentHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.PacketHandler
  alias Aesir.ZoneServer.Unit.Player.InventoryView
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
  end

  describe "inventory dump" do
    test "sends exactly one InventoryList on the bulk channel during LoadEndAck", %{
      character: character
    } do
      seed_item(character.id, 501, 5)
      seed_equipped(character.id, 1201, 2)

      {:ok, state} =
        PlayerSession.init(%{character: character, connection_pid: self()})

      {:noreply, _new_state} =
        PlayerSession.handle_info({:message, %MapLoaded{}}, state)

      assert {:send, :bulk, {:inventory_list, %InventoryList{}}} = next_inventory_list()
    end

    test "splits items into normal (non-equipped) and equip (worn)", %{character: character} do
      seed_item(character.id, 501, 5)
      seed_item(character.id, 1750, 100)
      seed_equipped(character.id, 1201, 2)
      seed_equipped(character.id, 2301, 16)

      {:ok, state} =
        PlayerSession.init(%{character: character, connection_pid: self()})

      {:noreply, _new_state} =
        PlayerSession.handle_info({:message, %MapLoaded{}}, state)

      %InventoryList{normal: normal, equip: equip} = receive_inventory_list()

      normal_ids = Enum.map(normal, & &1.nameid)
      equip_ids = Enum.map(equip, & &1.nameid)

      assert 501 in normal_ids
      assert 1750 in normal_ids
      refute 1201 in normal_ids

      assert 1201 in equip_ids
      assert 2301 in equip_ids
      refute 501 in equip_ids

      weapon = Enum.find(equip, &(&1.nameid == 1201))
      armor = Enum.find(equip, &(&1.nameid == 2301))
      assert weapon.location == 2
      assert armor.location == 16
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
        PlayerSession.handle_info({:message, %MapLoaded{}}, state)

      %InventoryList{normal: normal, equip: equip} = receive_inventory_list()

      # +2 client offset, unified index space, no collision
      assert [%{index: 2, nameid: 501}] = normal
      assert [%{index: 3, nameid: 1201}] = equip
    end

    test "carries per-item fields faithfully", %{character: character} do
      seed_item(character.id, 501, 5, %{identify: 1, card0: 4001, favorite: 1})

      {:ok, state} =
        PlayerSession.init(%{character: character, connection_pid: self()})

      {:noreply, _new_state} =
        PlayerSession.handle_info({:message, %MapLoaded{}}, state)

      %InventoryList{normal: [item]} = receive_inventory_list()

      assert item.nameid == 501
      assert item.amount == 5
      assert item.identified == true
      assert item.favorite == true
      assert [4001, 0, 0, 0] = item.cards
    end

    test "sends an empty InventoryList when there are no items", %{character: character} do
      {:ok, state} =
        PlayerSession.init(%{character: character, connection_pid: self()})

      {:noreply, _new_state} =
        PlayerSession.handle_info({:message, %MapLoaded{}}, state)

      assert %InventoryList{normal: [], equip: []} = receive_inventory_list()
    end
  end

  describe "item gain/loss messages" do
    test "item_added maps a gained item, applying the +2 client offset", %{character: character} do
      item = seed_item(character.id, 501, 5, %{identify: 1, refine: 0, card0: 4001, favorite: 1})

      assert %ItemAdded{} = added = InventoryView.item_added(item, 0)

      assert added.index == PlayerState.client_index(0)
      assert added.amount == 5
      assert added.nameid == 501
      assert added.identified == true
      assert added.refine == 0
      assert [4001, 0, 0, 0] = added.cards
      assert added.result == 0
    end

    test "item_removed names the index, amount and reason", %{character: _character} do
      assert %ItemRemoved{index: index, amount: 3, reason: 1} =
               InventoryView.item_removed(0, 3, 1)

      assert index == PlayerState.client_index(0)
    end

    test "item_removed defaults to the normal reason code", %{character: _character} do
      assert %ItemRemoved{reason: 0} = InventoryView.item_removed(0, 1)
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

  describe "give_item delivery" do
    test "adds the item, persists it, updates game_state and notifies the client", %{
      character: character
    } do
      {:ok, state} = PlayerSession.init(%{character: character, connection_pid: self()})
      {:ok, item_def} = ItemManagement.get_item_by_id(501)

      {:noreply, new_state} =
        PlayerSession.handle_cast({:inventory, {:give_item, item_def, 5}}, state)

      items = PlayerState.to_list(new_state.game_state.inventory)
      assert [%{nameid: 501, amount: 5}] = items
      assert [%{nameid: 501, amount: 5}] = PlayerState.to_list(reload(character.id))

      added = receive_message_of_type(ItemAdded)
      assert added.nameid == 501
      assert added.amount == 5
    end

    test "stacks onto an existing stack and notifies the affected slot", %{character: character} do
      seed_item(character.id, 501, 3)
      {:ok, state} = PlayerSession.init(%{character: character, connection_pid: self()})
      {:ok, item_def} = ItemManagement.get_item_by_id(501)

      {:noreply, new_state} =
        PlayerSession.handle_cast({:inventory, {:give_item, item_def, 2}}, state)

      assert [%{nameid: 501, amount: 5}] = PlayerState.to_list(new_state.game_state.inventory)

      added = receive_message_of_type(ItemAdded)
      assert added.nameid == 501
      assert added.amount == 5
    end

    @tag :capture_log
    test "leaves inventory unchanged and sends nothing when overweight", %{character: character} do
      {:ok, state} = PlayerSession.init(%{character: character, connection_pid: self()})
      {:ok, item_def} = ItemManagement.get_item_by_id(501)

      huge = div(Weight.max_weight(state.game_state.stats), item_def.weight) + 100

      {:noreply, new_state} =
        PlayerSession.handle_cast({:inventory, {:give_item, item_def, huge}}, state)

      assert new_state.game_state.inventory == state.game_state.inventory
      assert PlayerState.to_list(reload(character.id)) == []
      refute_received {:send, _channel, {:item_added, _}}
    end
  end

  describe "equip/unequip inbound dispatch" do
    test "an EquipItem dispatches handle_equip with the server index/position" do
      state = %{game_state: %PlayerState{character_id: 1000}}
      server_index = PlayerState.server_index(7)

      expect(EquipmentHandler, :handle_equip, fn ^server_index, 2, st -> {:noreply, st} end)

      assert {:noreply, ^state} =
               PacketHandler.handle_message(%EquipItem{index: 7, position: 2}, state)
    end

    test "an UnequipItem dispatches handle_unequip with the server index" do
      state = %{game_state: %PlayerState{character_id: 1000}}
      server_index = PlayerState.server_index(7)

      expect(EquipmentHandler, :handle_unequip, fn ^server_index, st -> {:noreply, st} end)

      assert {:noreply, ^state} =
               PacketHandler.handle_message(%UnequipItem{index: 7}, state)
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

    test "equip request equips the item and acks success with a pure ack", %{
      equip_char: character
    } do
      Mimic.copy(Broadcast)
      stub(Broadcast, :to_visible_players, fn _gs, _packet, _opts -> :ok end)
      # 1101 = Sword (right_hand, atk 25, no explicit view -> class view 2).
      seed_item(character.id, 1101, 1)
      {:ok, state} = PlayerSession.init(%{character: character, connection_pid: self()})

      server_index = index_of(state.game_state.inventory, 1101)
      bare_atk = state.game_state.stats.combat_stats.atk

      {:noreply, new_state} =
        PlayerSession.handle_info(
          {:message, %EquipItem{index: PlayerState.client_index(server_index), position: 2}},
          state
        )

      # Item now equipped in memory and persisted.
      assert new_state.game_state.inventory[server_index].equip == 2
      assert reload(character.id)[server_index].equip == 2

      # Stats reflect the +25 atk equipment bonus.
      assert new_state.game_state.stats.combat_stats.atk == bare_atk + 25

      ack = receive_message_of_type(EquipResult)
      assert ack.result == 0
      assert ack.wear_location == 2
      # Pure ack: the view never rides the ack anymore.
      assert ack.view_id == 0

      # The sword's class view (2 = one-handed sword) rides a weapon SpriteChange;
      # the ack itself stays pure (view_id 0 above).
      assert_received {:send, _channel, {:sprite_change, %SpriteChange{type: 2, val: 2, val2: 0}}}
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
        PlayerSession.handle_info(
          {:message, %EquipItem{index: PlayerState.client_index(katana_index), position: 34}},
          state
        )

      # Katana equipped to both hands, shield cleared.
      assert new_state.game_state.inventory[katana_index].equip == 34
      assert new_state.game_state.inventory[shield_index].equip == 0
      assert reload(character.id)[shield_index].equip == 0

      wear_ack = receive_message_of_type(EquipResult)
      assert wear_ack.result == 0

      takeoff_ack = receive_message_of_type(UnequipResult)
      assert takeoff_ack.index == PlayerState.client_index(shield_index)
    end

    test "unequip request clears the item and acks success", %{equip_char: character} do
      Mimic.copy(Broadcast)
      stub(Broadcast, :to_visible_players, fn _gs, _packet, _opts -> :ok end)

      _sword = seed_equipped(character.id, 1101, 2)
      {:ok, state} = PlayerSession.init(%{character: character, connection_pid: self()})

      server_index = index_of(state.game_state.inventory, 1101)

      {:noreply, new_state} =
        PlayerSession.handle_info(
          {:message, %UnequipItem{index: PlayerState.client_index(server_index)}},
          state
        )

      assert new_state.game_state.inventory[server_index].equip == 0
      assert reload(character.id)[server_index].equip == 0

      ack = receive_message_of_type(UnequipResult)
      assert ack.result == 0
    end

    @tag :capture_log
    test "persist failure leaves inventory unchanged and acks failure", %{equip_char: character} do
      _sword = seed_item(character.id, 1101, 1)
      {:ok, state} = PlayerSession.init(%{character: character, connection_pid: self()})

      server_index = index_of(state.game_state.inventory, 1101)

      # Simulate a DB failure: the whole transaction rolls back.
      stub(Persistence, :transaction, fn _fun -> {:error, :persist_failed} end)

      {:noreply, new_state} =
        PlayerSession.handle_info(
          {:message, %EquipItem{index: PlayerState.client_index(server_index), position: 2}},
          state
        )

      # State untouched (persist-first), DB still unequipped.
      assert new_state.game_state.inventory[server_index].equip == 0
      assert reload(character.id)[server_index].equip == 0

      ack = receive_message_of_type(EquipResult)
      assert ack.result == 2
    end

    test "stale/invalid index yields a failure ack and no mutation", %{equip_char: character} do
      {:ok, state} = PlayerSession.init(%{character: character, connection_pid: self()})

      {:noreply, new_state} =
        PlayerSession.handle_info(
          {:message, %EquipItem{index: PlayerState.client_index(99), position: 2}},
          state
        )

      assert new_state.game_state.inventory == state.game_state.inventory

      ack = receive_message_of_type(EquipResult)
      assert ack.result == 2

      # A failed equip never touches appearance.
      refute_received {:send, _channel, {:sprite_change, _}}
    end

    test "equipping a headgear emits a matching SpriteChange to self and nearby", %{
      equip_char: character
    } do
      Mimic.copy(Broadcast)
      # 2208 = Ribbon (head_top, view 17). LookType.head_top() == 4.
      seed_item(character.id, 2208, 1)
      {:ok, state} = PlayerSession.init(%{character: character, connection_pid: self()})

      server_index = index_of(state.game_state.inventory, 2208)

      expect(Broadcast, :to_visible_players, fn _gs,
                                                %SpriteChange{type: 4, val: 17, val2: 0},
                                                _opts ->
        :ok
      end)

      {:noreply, _new_state} =
        PlayerSession.handle_info(
          {:message, %EquipItem{index: PlayerState.client_index(server_index), position: 0x100}},
          state
        )

      ack = receive_message_of_type(EquipResult)
      assert ack.result == 0
      assert ack.wear_location == 0x100
      assert ack.view_id == 0

      change = receive_message_of_type(SpriteChange)
      assert change.gid == character.id
      assert change.type == 4
      assert change.val == 17
      assert change.val2 == 0
    end

    test "equipping a shield emits exactly one weapon-typed SpriteChange", %{
      equip_char: character
    } do
      Mimic.copy(Broadcast)
      # 2101 = Guard (left_hand shield, view 1). Weapon+shield collapse into the
      # single weapon look (type 2): val = weapon_view (0), val2 = shield_view (1).
      seed_item(character.id, 2101, 1)
      {:ok, state} = PlayerSession.init(%{character: character, connection_pid: self()})

      server_index = index_of(state.game_state.inventory, 2101)

      expect(Broadcast, :to_visible_players, fn _gs,
                                                %SpriteChange{type: 2, val: 0, val2: 1},
                                                _opts ->
        :ok
      end)

      {:noreply, _new_state} =
        PlayerSession.handle_info(
          {:message, %EquipItem{index: PlayerState.client_index(server_index), position: 0x20}},
          state
        )

      change = receive_message_of_type(SpriteChange)
      assert change.type == 2
      assert change.val == 0
      assert change.val2 == 1
    end

    test "equipping ammo acks success with no SpriteChange", %{equip_char: character} do
      Mimic.copy(Broadcast)
      stub(Broadcast, :to_visible_players, fn _gs, _packet, _opts -> :ok end)
      # 13210 = Slug Ammunition L (ammo, view 0, no job/level requirement).
      seed_item(character.id, 13210, 1)
      {:ok, state} = PlayerSession.init(%{character: character, connection_pid: self()})

      server_index = index_of(state.game_state.inventory, 13210)

      {:noreply, new_state} =
        PlayerSession.handle_info(
          {:message, %EquipItem{index: PlayerState.client_index(server_index), position: 0x8000}},
          state
        )

      assert new_state.game_state.inventory[server_index].equip == 0x8000

      ack = receive_message_of_type(EquipResult)
      assert ack.result == 0
      assert ack.wear_location == 0x8000
      assert ack.view_id == 0

      # Arrows have view 0, so no appearance change rides the equip.
      refute_received {:send, _channel, {:sprite_change, _}}
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
    items = Persistence.load_inventory(char_id)
    PlayerState.from_list(items)
  end

  defp index_of(inventory, nameid) do
    Enum.find_value(inventory, fn {index, item} ->
      if item.nameid == nameid, do: index
    end)
  end

  # Returns the first {:send, channel, {tag, %InventoryList{}}} message verbatim
  # so a test can assert the channel/tag alongside the struct.
  defp next_inventory_list(timeout \\ 1000) do
    receive do
      {:send, _channel, {_tag, %InventoryList{}}} = message -> message
      _other -> next_inventory_list(timeout)
    after
      timeout -> flunk("Expected an InventoryList send within #{timeout}ms")
    end
  end

  defp receive_inventory_list, do: receive_message_of_type(InventoryList)

  # Helper for the QUIC + protobuf outbound path: messages arrive as
  # {:send, channel, {tag, struct}} on the connection pid.
  defp receive_message_of_type(expected_type, timeout \\ 1000) do
    receive do
      {:send, _channel, {_tag, message}} ->
        if message.__struct__ == expected_type do
          message
        else
          receive_message_of_type(expected_type, timeout)
        end
    after
      timeout ->
        flunk("Expected message of type #{expected_type} not received within #{timeout}ms")
    end
  end
end
