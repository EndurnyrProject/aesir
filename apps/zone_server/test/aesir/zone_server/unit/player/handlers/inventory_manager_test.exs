defmodule Aesir.ZoneServer.Unit.Player.Handlers.InventoryManagerTest do
  use Aesir.DataCase, async: true

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Unit.Inventory.Persistence
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryManager
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.Player.Stats

  @sword 1101

  setup :setup_ets_tables

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
        base_level: 99,
        str: 10,
        agi: 10,
        vit: 10,
        int: 10,
        dex: 10,
        luk: 10
      })
      |> Repo.insert()

    %{character: character, stats: Stats.from_character(character)}
  end

  test "persists an unidentified pickup and reloads it", %{character: char, stats: stats} do
    {:ok, item_def} = ItemManagement.get_item_by_id(@sword)

    assert {:ok, %{game_state: %{inventory: %{0 => %InventoryItem{identify: 0}}}}} =
             InventoryManager.handle_give_item(item_def, 1, state(char.id, stats), false)

    assert [%InventoryItem{nameid: @sword, identify: 0}] = Persistence.load_inventory(char.id)
  end

  test "persists an identified pickup and reloads it", %{character: char, stats: stats} do
    {:ok, item_def} = ItemManagement.get_item_by_id(@sword)

    assert {:ok, %{game_state: %{inventory: %{0 => %InventoryItem{identify: 1}}}}} =
             InventoryManager.handle_give_item(item_def, 1, state(char.id, stats), true)

    assert [%InventoryItem{nameid: @sword, identify: 1}] = Persistence.load_inventory(char.id)
  end

  test "standard item grants remain identified", %{character: char, stats: stats} do
    {:ok, item_def} = ItemManagement.get_item_by_id(@sword)

    assert {:ok, %{game_state: %{inventory: %{0 => %InventoryItem{identify: 1}}}}} =
             InventoryManager.handle_give_item(item_def, 1, state(char.id, stats))

    assert [%InventoryItem{nameid: @sword, identify: 1}] = Persistence.load_inventory(char.id)
  end

  defp state(character_id, stats) do
    %SessionState{
      connection_pid: self(),
      game_state: %PlayerState{character_id: character_id, inventory: %{}, stats: stats}
    }
  end
end
