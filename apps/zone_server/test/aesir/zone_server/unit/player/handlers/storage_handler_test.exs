defmodule Aesir.ZoneServer.Unit.Player.Handlers.StorageHandlerTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Commons.Models.StorageItem
  alias Aesir.Net.ItemAdded
  alias Aesir.Net.ItemRemoved
  alias Aesir.Net.StorageItemAdded
  alias Aesir.Net.StorageItemRemoved
  alias Aesir.Net.StorageOpened
  alias Aesir.Net.StorageResult
  alias Aesir.ZoneServer.Unit.Player.Handlers.PacketHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.StorageHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.StorageOps
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Storage.Persistence, as: StoragePersistence
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!
  setup :set_mimic_from_context
  setup :setup_ets_tables

  @char_id 8001
  @account_id 3000
  @nv_basic_id 1

  defp character(opts) do
    %Character{
      id: @char_id,
      account_id: @account_id,
      name: "Storekeeper",
      last_map: "prontera",
      last_x: 150,
      last_y: 150,
      sex: "M",
      str: 10,
      agi: 10,
      vit: 10,
      int: 10,
      dex: 10,
      luk: 10,
      base_level: 50,
      job_level: 50,
      class: 0,
      hp: 800,
      sp: 300,
      learned_skills: Keyword.get(opts, :learned_skills, %{})
    }
  end

  defp state(opts \\ []) do
    base = PlayerState.new(character(opts))

    game_state = %{
      base
      | storage: Keyword.get(opts, :storage, nil),
        inventory: Keyword.get(opts, :inventory, %{})
    }

    %{connection_pid: self(), game_state: game_state, interaction_lock: nil}
  end

  defp item(nameid, amount) do
    %InventoryItem{
      id: 11,
      nameid: nameid,
      amount: amount,
      equip: 0,
      identify: 1,
      refine: 0,
      attribute: 0,
      card0: 0,
      card1: 0,
      card2: 0,
      card3: 0,
      random_options: %{},
      bound: 0,
      favorite: 0
    }
  end

  defp learned_basic(level), do: %{Integer.to_string(@nv_basic_id) => level}

  defp storage_row(opts) do
    %StorageItem{
      id: Keyword.get(opts, :id, 1),
      account_id: @account_id,
      nameid: Keyword.fetch!(opts, :nameid),
      amount: Keyword.fetch!(opts, :amount),
      identify: 1,
      refine: 0,
      attribute: 0,
      card0: 0,
      card1: 0,
      card2: 0,
      card3: 0,
      random_options: %{},
      bound: 0,
      unique_id: 0,
      enchant_grade: 0
    }
  end

  describe "open/1" do
    test "with NV_BASIC below 6 sends BASIC_SKILL_REQUIRED and leaves storage nil" do
      reject(&StoragePersistence.load_storage/1)

      base = state(learned_skills: learned_basic(5))

      assert {:noreply, ^base} = StorageHandler.open(base)

      assert_received {:send, :gameplay,
                       {:storage_result, %StorageResult{result: :STORAGE_BASIC_SKILL_REQUIRED}}}
    end

    test "with NV_BASIC >= 6 loads rows and sends StorageOpened" do
      stub(UnitRegistry, :update_unit_state, fn :player, @char_id, _gs -> :ok end)

      stub(StoragePersistence, :load_storage, fn @account_id ->
        [storage_row(nameid: 501, amount: 5)]
      end)

      base = state(learned_skills: learned_basic(6))

      assert {:noreply, new_state} = StorageHandler.open(base)

      assert %{0 => %InventoryItem{nameid: 501, amount: 5}} = new_state.game_state.storage

      assert_received {:send, :bulk,
                       {:storage_opened, %StorageOpened{capacity: 600, items: [%{nameid: 501}]}}}
    end

    test "double open re-sends StorageOpened without reloading or corrupting state" do
      reject(&StoragePersistence.load_storage/1)

      storage = %{0 => item(501, 5)}
      base = state(learned_skills: learned_basic(6), storage: storage)

      assert {:noreply, ^base} = StorageHandler.open(base)

      assert_received {:send, :bulk, {:storage_opened, %StorageOpened{items: [%{nameid: 501}]}}}
    end
  end

  describe "deposit/3" do
    test "with storage closed sends STORAGE_NOT_OPEN and writes nothing" do
      reject(&StorageOps.deposit/6)

      base = state(inventory: %{0 => item(501, 4)})
      client_index = PlayerState.client_index(0)

      assert {:noreply, ^base} = StorageHandler.deposit(client_index, 4, base)

      assert_received {:send, :gameplay,
                       {:storage_result, %StorageResult{result: :STORAGE_NOT_OPEN}}}
    end

    test "with amount <= 0 sends STORAGE_INVALID_AMOUNT without raising" do
      reject(&StorageOps.deposit/6)

      base = state(storage: %{}, inventory: %{0 => item(501, 4)})
      client_index = PlayerState.client_index(0)

      assert {:noreply, ^base} = StorageHandler.deposit(client_index, 0, base)

      assert_received {:send, :gameplay,
                       {:storage_result, %StorageResult{result: :STORAGE_INVALID_AMOUNT}}}
    end

    test "on success emits ItemRemoved + StorageItemAdded + StorageResult(OK)" do
      stub(UnitRegistry, :update_unit_state, fn :player, @char_id, _gs -> :ok end)

      moved = item(501, 4)
      new_storage = %{0 => moved}

      stub(StorageOps, :deposit, fn @account_id, @char_id, _inv, %{}, 0, 4 ->
        {:ok, %{}, new_storage, {:removed, 0}, {:added, 0, moved}}
      end)

      base = state(storage: %{}, inventory: %{0 => item(501, 4)})
      client_index = PlayerState.client_index(0)

      assert {:noreply, committed} = StorageHandler.deposit(client_index, 4, base)

      assert committed.game_state.storage == new_storage
      assert committed.game_state.inventory == %{}

      assert_received {:send, :gameplay,
                       {:item_removed, %ItemRemoved{index: ^client_index, amount: 4}}}

      assert_received {:send, :gameplay,
                       {:storage_item_added,
                        %StorageItemAdded{index: ^client_index, nameid: 501, amount: 4}}}

      assert_received {:send, :gameplay, {:storage_result, %StorageResult{result: :STORAGE_OK}}}
    end

    test "maps a StorageOps error to its result code and writes nothing" do
      stub(StorageOps, :deposit, fn @account_id, @char_id, _inv, %{}, 0, 4 ->
        {:error, :item_equipped}
      end)

      base = state(storage: %{}, inventory: %{0 => item(501, 4)})
      client_index = PlayerState.client_index(0)

      assert {:noreply, ^base} = StorageHandler.deposit(client_index, 4, base)

      assert_received {:send, :gameplay,
                       {:storage_result, %StorageResult{result: :STORAGE_ITEM_EQUIPPED}}}
    end
  end

  describe "withdraw/3" do
    test "with storage closed sends STORAGE_NOT_OPEN and writes nothing" do
      reject(&StorageOps.withdraw/7)

      base = state()
      client_index = PlayerState.client_index(0)

      assert {:noreply, ^base} = StorageHandler.withdraw(client_index, 3, base)

      assert_received {:send, :gameplay,
                       {:storage_result, %StorageResult{result: :STORAGE_NOT_OPEN}}}
    end

    test "with amount <= 0 sends STORAGE_INVALID_AMOUNT without raising" do
      reject(&StorageOps.withdraw/7)

      base = state(storage: %{0 => item(501, 3)})
      client_index = PlayerState.client_index(0)

      assert {:noreply, ^base} = StorageHandler.withdraw(client_index, -1, base)

      assert_received {:send, :gameplay,
                       {:storage_result, %StorageResult{result: :STORAGE_INVALID_AMOUNT}}}
    end

    test "on success emits StorageItemRemoved + ItemAdded + StorageResult(OK)" do
      stub(UnitRegistry, :update_unit_state, fn :player, @char_id, _gs -> :ok end)

      moved = item(501, 3)
      new_inventory = %{0 => moved}

      stub(StorageOps, :withdraw, fn @account_id, @char_id, _inv, _storage, _stats, 0, 3 ->
        {:ok, new_inventory, %{}, {:added, 0, moved}, {:removed, 0}}
      end)

      base = state(storage: %{0 => item(501, 3)})
      client_index = PlayerState.client_index(0)

      assert {:noreply, committed} = StorageHandler.withdraw(client_index, 3, base)

      assert committed.game_state.inventory == new_inventory
      assert committed.game_state.storage == %{}

      assert_received {:send, :gameplay,
                       {:storage_item_removed,
                        %StorageItemRemoved{index: ^client_index, amount: 3}}}

      assert_received {:send, :gameplay,
                       {:item_added, %ItemAdded{index: ^client_index, nameid: 501, amount: 3}}}

      assert_received {:send, :gameplay, {:storage_result, %StorageResult{result: :STORAGE_OK}}}
    end

    test "maps a StorageOps error to its result code and writes nothing" do
      stub(StorageOps, :withdraw, fn @account_id, @char_id, _inv, _storage, _stats, 0, 3 ->
        {:error, :overweight}
      end)

      base = state(storage: %{0 => item(501, 3)})
      client_index = PlayerState.client_index(0)

      assert {:noreply, ^base} = StorageHandler.withdraw(client_index, 3, base)

      assert_received {:send, :gameplay,
                       {:storage_result, %StorageResult{result: :STORAGE_OVERWEIGHT}}}
    end
  end

  describe "close/1" do
    test "sets storage back to nil" do
      stub(UnitRegistry, :update_unit_state, fn :player, @char_id, _gs -> :ok end)

      base = state(storage: %{0 => item(501, 3)})

      assert {:noreply, closed} = StorageHandler.close(base)
      assert closed.game_state.storage == nil
    end

    test "is a no-op when already closed" do
      base = state()

      assert {:noreply, ^base} = StorageHandler.close(base)
    end
  end

  describe "packet dispatch" do
    test "StorageDepositRequest dispatches deposit/3 with the client index/amount" do
      base = %{game_state: %PlayerState{character_id: @char_id}}

      expect(StorageHandler, :deposit, fn 5, 2, st -> {:noreply, st} end)

      assert {:noreply, ^base} =
               PacketHandler.handle_message(
                 %Aesir.Net.StorageDepositRequest{inventory_index: 5, amount: 2},
                 base
               )
    end

    test "StorageWithdrawRequest dispatches withdraw/3 with the client index/amount" do
      base = %{game_state: %PlayerState{character_id: @char_id}}

      expect(StorageHandler, :withdraw, fn 3, 4, st -> {:noreply, st} end)

      assert {:noreply, ^base} =
               PacketHandler.handle_message(
                 %Aesir.Net.StorageWithdrawRequest{storage_index: 3, amount: 4},
                 base
               )
    end

    test "StorageCloseRequest dispatches close/1" do
      base = %{game_state: %PlayerState{character_id: @char_id}}

      expect(StorageHandler, :close, fn st -> {:noreply, st} end)

      assert {:noreply, ^base} =
               PacketHandler.handle_message(%Aesir.Net.StorageCloseRequest{}, base)
    end
  end
end
