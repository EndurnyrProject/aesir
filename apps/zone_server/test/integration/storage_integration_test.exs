defmodule Aesir.ZoneServer.Integration.StorageIntegrationTest do
  @moduledoc """
  End-to-end coverage that the account-wide Kafra storage window is playable on
  the real stack, mirroring the cart integration coverage. Every step drives
  the live session/handler/persistence subsystems (no re-stubbing of units
  already unit-tested):

    1. Talking to an NPC that calls `openstorage` with `NV_BASIC >= 6` loads the
       account's rows and sends `StorageOpened` with the capacity and items.
    2. The same script with `NV_BASIC < 6` is rejected with
       `StorageResult(STORAGE_BASIC_SKILL_REQUIRED)` and the window stays closed.
    3. A plain-stack deposit then withdraw round-trips through both containers,
       both DB tables, and the paired client deltas.
    4. A carded/refined item round-trips preserving its cards/refine/unique_id/
       enchant_grade, always taking a fresh storage slot rather than merging
       into a plain stack of the same nameid.
    5. A character-bound item is rejected with `STORAGE_NOT_STORABLE`.
    6. A worn item is rejected with `STORAGE_ITEM_EQUIPPED`.
    7. A deposit sent after `StorageCloseRequest` is rejected with
       `STORAGE_NOT_OPEN`.

  Storage rows are keyed by `account_id` (not `char_id`), which every
  DB-assertion above verifies directly.
  """

  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Net.ItemAdded
  alias Aesir.Net.ItemRemoved
  alias Aesir.Net.NpcDialog
  alias Aesir.Net.NpcTalk
  alias Aesir.Net.StorageCloseRequest
  alias Aesir.Net.StorageDepositRequest
  alias Aesir.Net.StorageItemAdded
  alias Aesir.Net.StorageItemRemoved
  alias Aesir.Net.StorageOpened
  alias Aesir.Net.StorageResult
  alias Aesir.Net.StorageWithdrawRequest
  alias Aesir.Repo
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry
  alias Aesir.ZoneServer.Unit.Inventory.Persistence, as: InventoryPersistence
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Storage
  alias Aesir.ZoneServer.Unit.Storage.Persistence, as: StoragePersistence

  @map "prontera"
  @kafra_pos {170, 160}
  # Red Potion (item db, plain and stackable).
  @potion 501
  # Sword (item db, refineable, 3 card slots).
  @sword 1101

  defmodule KafraNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 170, y: 160, dir: 0, sprite: 117, name: "Kafra"}]

    @impl true
    def on_talk(ctx) do
      ctx |> openstorage() |> close()
    end
  end

  setup do
    on_exit(fn -> :persistent_term.erase(NpcRegistry) end)
    NpcRegistry.reload([KafraNpc])
    :ok
  end

  describe "opening storage via an NPC's openstorage call" do
    test "NV_BASIC >= 6 loads the account's rows into StorageOpened" do
      character = insert_character(nv_basic: 6)

      {:ok, _row} =
        StoragePersistence.insert_item(character.account_id, %{
          nameid: @potion,
          amount: 7,
          identify: 1
        })

      session = start_session(character)
      talk_to_kafra(session.pid)

      assert_receive {:packet_sent, %StorageOpened{capacity: capacity, items: items}, _}, 1_000
      assert capacity == Storage.capacity()
      assert Enum.any?(items, &(&1.nameid == @potion and &1.amount == 7))

      assert_receive {:packet_sent, %NpcDialog{expect: :CLOSE}, _}, 1_000

      state = get_player_state(session.pid)
      assert %{nameid: @potion, amount: 7} = only_item(state.storage)
    end

    test "NV_BASIC < 6 is rejected with BASIC_SKILL_REQUIRED and the window stays closed" do
      character = insert_character(nv_basic: 5)
      session = start_session(character)

      talk_to_kafra(session.pid)

      assert_receive {:packet_sent, %StorageResult{result: :STORAGE_BASIC_SKILL_REQUIRED}, _},
                     1_000

      refute_receive {:packet_sent, %StorageOpened{}, _}, 200

      assert_receive {:packet_sent, %NpcDialog{expect: :CLOSE}, _}, 1_000

      assert get_player_state(session.pid).storage == nil
    end
  end

  describe "deposit/withdraw lifecycle" do
    test "a plain stack round-trips through both containers and both DB tables" do
      character = insert_character(nv_basic: 6)
      seed_inventory(character.id, nameid: @potion, amount: 10)

      session = start_session(character)
      open_storage!(session.pid)

      inv_index = client_index_of(get_player_state(session.pid).inventory, @potion)

      simulate_incoming_message(session.pid, %StorageDepositRequest{
        inventory_index: inv_index,
        amount: 4
      })

      assert_receive {:packet_sent, %ItemRemoved{index: ^inv_index, amount: 4}, _}, 1_000
      assert_receive {:packet_sent, %StorageItemAdded{nameid: @potion, amount: 4}, _}, 1_000
      assert_receive {:packet_sent, %StorageResult{result: :STORAGE_OK}, _}, 1_000

      after_deposit = get_player_state(session.pid)
      assert %{nameid: @potion, amount: 4} = only_item(after_deposit.storage)
      assert held(after_deposit.inventory, @potion) == 6

      assert [%InventoryItem{amount: 6}] = InventoryPersistence.load_inventory(character.id)

      storage_rows = StoragePersistence.load_storage(character.account_id)
      assert [%{nameid: @potion, amount: 4, account_id: account_id}] = storage_rows
      assert account_id == character.account_id

      storage_index = client_index_of(after_deposit.storage, @potion)

      simulate_incoming_message(session.pid, %StorageWithdrawRequest{
        storage_index: storage_index,
        amount: 4
      })

      assert_receive {:packet_sent, %StorageItemRemoved{index: ^storage_index, amount: 4}, _},
                     1_000

      # The 4 stack back onto the 6 left behind, so ItemAdded reports the
      # resulting slot total (10), not the delta.
      assert_receive {:packet_sent, %ItemAdded{nameid: @potion, amount: 10}, _}, 1_000
      assert_receive {:packet_sent, %StorageResult{result: :STORAGE_OK}, _}, 1_000

      after_withdraw = get_player_state(session.pid)
      assert after_withdraw.storage == %{}
      assert held(after_withdraw.inventory, @potion) == 10

      assert [%InventoryItem{amount: 10}] = InventoryPersistence.load_inventory(character.id)
      assert StoragePersistence.load_storage(character.account_id) == []
    end

    test "a carded, refined item round-trips its attributes and never merges into a plain stack" do
      character = insert_character(nv_basic: 6)

      seed_inventory(character.id, nameid: @sword, amount: 1)

      seed_inventory(character.id,
        nameid: @sword,
        amount: 1,
        refine: 7,
        card0: 4001,
        unique_id: 555_555,
        enchant_grade: 3
      )

      session = start_session(character)
      open_storage!(session.pid)

      inventory = get_player_state(session.pid).inventory
      plain_index = index_of(inventory, &(&1.refine == 0))
      carded_index = index_of(inventory, &(&1.refine == 7))

      simulate_incoming_message(session.pid, %StorageDepositRequest{
        inventory_index: plain_index,
        amount: 1
      })

      assert_receive {:packet_sent, %StorageItemAdded{nameid: @sword, refine: 0}, _}, 1_000
      assert_receive {:packet_sent, %StorageResult{result: :STORAGE_OK}, _}, 1_000

      simulate_incoming_message(session.pid, %StorageDepositRequest{
        inventory_index: carded_index,
        amount: 1
      })

      assert_receive {:packet_sent,
                      %StorageItemAdded{nameid: @sword, refine: 7, cards: [4001, 0, 0, 0]}, _},
                     1_000

      assert_receive {:packet_sent, %StorageResult{result: :STORAGE_OK}, _}, 1_000

      storage = get_player_state(session.pid).storage
      assert map_size(storage) == 2

      carded_item = storage |> Map.values() |> Enum.find(&(&1.refine == 7))
      assert carded_item.card0 == 4001
      assert carded_item.unique_id == 555_555
      assert carded_item.enchant_grade == 3

      rows = StoragePersistence.load_storage(character.account_id)
      assert length(rows) == 2
      assert Enum.all?(rows, &(&1.account_id == character.account_id))

      plain_row = Enum.find(rows, &(&1.refine == 0))
      carded_row = Enum.find(rows, &(&1.refine == 7))

      assert plain_row.card0 == 0
      assert carded_row.card0 == 4001
      assert carded_row.unique_id == 555_555
      assert carded_row.enchant_grade == 3
    end

    test "a character-bound item cannot be deposited" do
      character = insert_character(nv_basic: 6)
      seed_inventory(character.id, nameid: @potion, amount: 1, bound: 4)

      session = start_session(character)
      open_storage!(session.pid)

      inv_index = client_index_of(get_player_state(session.pid).inventory, @potion)

      simulate_incoming_message(session.pid, %StorageDepositRequest{
        inventory_index: inv_index,
        amount: 1
      })

      assert_receive {:packet_sent, %StorageResult{result: :STORAGE_NOT_STORABLE}, _}, 1_000

      state = get_player_state(session.pid)
      assert state.storage == %{}
      assert held(state.inventory, @potion) == 1

      assert [%InventoryItem{amount: 1, bound: 4}] =
               InventoryPersistence.load_inventory(character.id)

      assert StoragePersistence.load_storage(character.account_id) == []
    end

    test "an equipped item cannot be deposited" do
      character = insert_character(nv_basic: 6)
      seed_inventory(character.id, nameid: @sword, amount: 1, equip: 2)

      session = start_session(character)
      open_storage!(session.pid)

      inv_index = client_index_of(get_player_state(session.pid).inventory, @sword)

      simulate_incoming_message(session.pid, %StorageDepositRequest{
        inventory_index: inv_index,
        amount: 1
      })

      assert_receive {:packet_sent, %StorageResult{result: :STORAGE_ITEM_EQUIPPED}, _}, 1_000

      state = get_player_state(session.pid)
      assert state.storage == %{}
      assert held(state.inventory, @sword) == 1

      assert [%InventoryItem{amount: 1, equip: 2}] =
               InventoryPersistence.load_inventory(character.id)

      assert StoragePersistence.load_storage(character.account_id) == []
    end

    test "a deposit sent after StorageCloseRequest is rejected with STORAGE_NOT_OPEN" do
      character = insert_character(nv_basic: 6)
      seed_inventory(character.id, nameid: @potion, amount: 1)

      session = start_session(character)
      open_storage!(session.pid)

      inv_index = client_index_of(get_player_state(session.pid).inventory, @potion)

      simulate_incoming_message(session.pid, %StorageCloseRequest{})
      assert get_player_state(session.pid).storage == nil

      simulate_incoming_message(session.pid, %StorageDepositRequest{
        inventory_index: inv_index,
        amount: 1
      })

      assert_receive {:packet_sent, %StorageResult{result: :STORAGE_NOT_OPEN}, _}, 1_000

      state = get_player_state(session.pid)
      assert state.storage == nil
      assert held(state.inventory, @potion) == 1

      assert [%InventoryItem{amount: 1}] = InventoryPersistence.load_inventory(character.id)
      assert StoragePersistence.load_storage(character.account_id) == []
    end
  end

  defp start_session(character) do
    session = start_player_session(character: character, map_name: @map, position: @kafra_pos)
    on_exit(fn -> end_player_session(session) end)
    flush_packets()
    session
  end

  defp open_storage!(pid) do
    talk_to_kafra(pid)
    assert_receive {:packet_sent, %StorageOpened{}, _}, 1_000
    assert_receive {:packet_sent, %NpcDialog{expect: :CLOSE}, _}, 1_000
  end

  defp talk_to_kafra(pid) do
    {x, y} = @kafra_pos
    {:ok, {_module, npc_placement}} = NpcRegistry.module_at(@map, x, y)
    gid = NpcRegistry.entity_id(npc_placement)
    simulate_incoming_message(pid, %NpcTalk{npc_id: gid})
  end

  defp insert_character(opts) do
    uniq = System.unique_integer([:positive])
    {x, y} = @kafra_pos

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        username: "storage#{uniq}",
        userid: "storage#{uniq}",
        user_pass: "password",
        email: "storage#{uniq}@aesir.test"
      })
      |> Repo.insert()

    {:ok, character} =
      %Character{}
      |> Character.changeset(%{
        account_id: account.id,
        char_num: 0,
        name: "Storer#{uniq}",
        class: 0,
        base_level: 50,
        job_level: 50,
        str: 10,
        agi: 10,
        vit: 10,
        int: 10,
        dex: 10,
        luk: 10,
        last_map: @map,
        last_x: x,
        last_y: y,
        save_map: @map,
        save_x: x,
        save_y: y,
        learned_skills: learned_skills(Keyword.get(opts, :nv_basic, 0))
      })
      |> Repo.insert()

    character
  end

  defp learned_skills(0), do: %{}
  defp learned_skills(level), do: %{Integer.to_string(nv_basic_id()) => level}

  defp nv_basic_id do
    {:ok, %{id: id}} = Catalog.by_name(:nv_basic)
    id
  end

  defp seed_inventory(char_id, attrs) do
    attrs = attrs |> Map.new() |> Map.put_new(:identify, 1)
    {:ok, item} = InventoryPersistence.insert_item(char_id, attrs)
    item
  end

  defp client_index_of(map, nameid) do
    index_of(map, &(&1.nameid == nameid))
  end

  defp index_of(map, pred) do
    {server_index, _item} = Enum.find(map, fn {_index, item} -> pred.(item) end)
    PlayerState.client_index(server_index)
  end

  defp only_item(map) do
    map |> Map.values() |> hd() |> Map.take([:nameid, :amount])
  end

  defp held(map, nameid) do
    Enum.reduce(map, 0, fn
      {_index, %InventoryItem{nameid: ^nameid, amount: amount}}, acc -> acc + amount
      _entry, acc -> acc
    end)
  end
end
