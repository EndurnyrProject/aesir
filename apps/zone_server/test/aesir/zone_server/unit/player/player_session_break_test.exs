defmodule Aesir.ZoneServer.Unit.Player.PlayerSessionBreakTest do
  use Aesir.DataCase, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Net.Announcement, as: AnnouncementMsg
  alias Aesir.Net.ItemAdded
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Inventory.Persistence
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup :verify_on_exit!
  setup :set_mimic_from_context
  setup :setup_ets_tables

  setup do
    Mimic.copy(Persistence)
    Mimic.copy(Broadcast)

    :ok
  end

  setup do
    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        username: "breakuser",
        userid: "breakuser",
        user_pass: "password",
        email: "break@test.com"
      })
      |> Repo.insert()

    {:ok, character} =
      %Character{}
      |> Character.changeset(%{
        account_id: account.id,
        char_num: 0,
        name: "Breaker",
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

    %{character: character}
  end

  describe "break_equip cast" do
    test "breaks the worn weapon, red-messages the owner and syncs the client", %{
      character: character
    } do
      # 1101 = Sword, atk 25, worn in the right hand (equip mask 2).
      seed_equipped(character.id, 1101, 2)
      {:ok, item_def} = ItemManagement.get_item_by_id(1101)

      {:ok, state} = PlayerSession.init(%{character: character, connection_pid: self()})

      server_index = index_of(state.game_state.inventory, 1101)
      bare_atk = state.game_state.stats.combat_stats.atk

      expect(Broadcast, :to_player, fn char_id, %AnnouncementMsg{} = packet ->
        send(self(), {:announced, char_id, packet})
        :ok
      end)

      {:noreply, new_state} =
        PlayerSession.handle_cast({:inventory, {:break_equip, :right_hand}}, state)

      broken = new_state.game_state.inventory[server_index]
      assert broken.attribute == 1
      assert broken.equip == 0

      persisted = reload(character.id)[server_index]
      assert persisted.attribute == 1
      assert persisted.equip == 0

      # The broken weapon no longer contributes its +25 atk.
      assert new_state.game_state.stats.combat_stats.atk == bare_atk - 25

      assert_received {:announced, char_id, packet}
      assert char_id == character.id
      assert packet.color == 0xFF0000
      assert packet.text =~ item_def.name

      added = receive_message_of_type(ItemAdded)
      assert added.attribute == 1
      assert added.location == 0
      assert added.index == PlayerState.client_index(server_index)
    end

    test "leaves state unchanged and sends nothing for an empty slot", %{character: character} do
      {:ok, state} = PlayerSession.init(%{character: character, connection_pid: self()})

      reject(&Broadcast.to_player/2)

      {:noreply, new_state} =
        PlayerSession.handle_cast({:inventory, {:break_equip, :right_hand}}, state)

      assert new_state.game_state.inventory == state.game_state.inventory
      refute_received {:send, _channel, {:item_added, _}}
    end
  end

  describe "repair_all cast" do
    test "clears broken rows and syncs the repaired items", %{character: character} do
      # A broken weapon sitting unequipped in the bag (attribute 1, equip 0).
      seed_item(character.id, 1101, 1, %{attribute: 1})
      {:ok, state} = PlayerSession.init(%{character: character, connection_pid: self()})

      server_index = index_of(state.game_state.inventory, 1101)

      {:noreply, new_state} =
        PlayerSession.handle_cast({:inventory, :repair_all}, state)

      assert new_state.game_state.inventory[server_index].attribute == 0
      assert reload(character.id)[server_index].attribute == 0

      added = receive_message_of_type(ItemAdded)
      assert added.attribute == 0
      assert added.index == PlayerState.client_index(server_index)
    end

    test "is a no-op with nothing to repair", %{character: character} do
      seed_item(character.id, 501, 5)
      {:ok, state} = PlayerSession.init(%{character: character, connection_pid: self()})

      {:noreply, new_state} =
        PlayerSession.handle_cast({:inventory, :repair_all}, state)

      assert new_state.game_state.inventory == state.game_state.inventory
      refute_received {:send, _channel, {:item_added, _}}
    end
  end

  defp seed_item(char_id, nameid, amount, attrs \\ %{}) do
    {:ok, item} =
      Persistence.insert_item(char_id, Map.merge(%{nameid: nameid, amount: amount}, attrs))

    item
  end

  defp seed_equipped(char_id, nameid, equip) do
    seed_item(char_id, nameid, 1, %{equip: equip})
  end

  defp reload(char_id) do
    char_id
    |> Persistence.load_inventory()
    |> PlayerState.from_list()
  end

  defp index_of(inventory, nameid) do
    Enum.find_value(inventory, fn {index, item} ->
      if item.nameid == nameid, do: index
    end)
  end

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
