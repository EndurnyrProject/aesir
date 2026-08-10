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

  test "bound item grants preserve their identify and bound values", %{
    character: char,
    stats: stats
  } do
    {:ok, item_def} = ItemManagement.get_item_by_id(@sword)

    assert {:ok, %{game_state: %{inventory: %{0 => %InventoryItem{identify: 0, bound: 2}}}}} =
             InventoryManager.handle_give_item(item_def, 1, state(char.id, stats), false, 2)

    assert [%InventoryItem{nameid: @sword, identify: 0, bound: 2}] =
             Persistence.load_inventory(char.id)
  end

  test "persists item attributes supplied through opts", %{character: char, stats: stats} do
    {:ok, item_def} = ItemManagement.get_item_by_id(@sword)
    expire_time = ~N[2026-08-11 12:00:00]
    random_options = %{"1" => %{val: 10, parm: 2}}

    assert {:ok, %{game_state: %{inventory: %{0 => item}}}} =
             InventoryManager.handle_give_item(item_def, 1, state(char.id, stats), %{
               expire_time: expire_time,
               refine: 5,
               card0: 1234,
               random_options: random_options
             })

    assert %InventoryItem{
             expire_time: ^expire_time,
             refine: 5,
             card0: 1234,
             random_options: ^random_options,
             identify: 1
           } = item
  end

  test "opts grant leaves a full inventory unchanged", %{character: char, stats: stats} do
    {:ok, item_def} = ItemManagement.get_item_by_id(@sword)

    full_inventory =
      for index <- 0..99, into: %{} do
        {index, %InventoryItem{nameid: -index - 1, amount: 1}}
      end

    session = state(char.id, stats)
    session = %{session | game_state: %{session.game_state | inventory: full_inventory}}

    assert {:error, :inventory_full, ^session} =
             InventoryManager.handle_give_item(item_def, 1, session, %{
               expire_time: ~N[2026-08-11 12:00:00]
             })

    assert [] = Persistence.load_inventory(char.id)
  end

  test "repairs one row and rejects a stale repeat", %{character: char, stats: stats} do
    broken =
      %InventoryItem{}
      |> InventoryItem.changeset(%{
        char_id: char.id,
        nameid: @sword,
        amount: 1,
        attribute: 1,
        equip: 0
      })
      |> Repo.insert!()

    session = state(char.id, stats)
    session = %{session | game_state: %{session.game_state | inventory: %{4 => broken}}}

    assert {:reply, :ok, repaired_session} =
             InventoryManager.handle_repair_item(4, session)

    assert repaired_session.game_state.inventory[4].attribute == 0
    assert Repo.get!(InventoryItem, broken.id).attribute == 0

    assert {:reply, {:error, :repair_failed}, ^repaired_session} =
             InventoryManager.handle_repair_item(4, repaired_session)
  end

  defp state(character_id, stats) do
    %SessionState{
      connection_pid: self(),
      game_state: %PlayerState{character_id: character_id, inventory: %{}, stats: stats}
    }
  end
end
