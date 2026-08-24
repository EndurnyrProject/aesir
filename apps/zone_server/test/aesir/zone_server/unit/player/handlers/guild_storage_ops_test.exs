defmodule Aesir.ZoneServer.Unit.Player.Handlers.GuildStorageOpsTest do
  use Aesir.DataCase, async: true
  use Mimic

  import Aesir.TestEtsSetup
  import Aesir.TestWait

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.Guild
  alias Aesir.Commons.Models.GuildStorageItem
  alias Aesir.Commons.Models.GuildStorageLog
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Guild.Storage.Lock
  alias Aesir.ZoneServer.Guild.Storage.Persistence, as: GuildStoragePersistence
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemCraft
  alias Aesir.ZoneServer.Unit.Inventory.Persistence, as: InventoryPersistence
  alias Aesir.ZoneServer.Unit.Inventory.Weight
  alias Aesir.ZoneServer.Unit.Player.Handlers.GuildStorageOps
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats

  @potion 501
  @poring_card 4001
  @restricted 598
  @sword 1101

  setup :verify_on_exit!
  setup :set_mimic_from_context
  setup :setup_ets_tables

  setup do
    Mimic.copy(GuildStoragePersistence)
    :ok
  end

  setup do
    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        username: "guild_storage_#{System.unique_integer([:positive])}",
        userid: "guild_storage",
        user_pass: "password",
        email: "guild-storage@test.com"
      })
      |> Repo.insert()

    {:ok, character} =
      %Character{}
      |> Character.changeset(%{
        account_id: account.id,
        char_num: 0,
        name: "GuildStorageChar",
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

    {:ok, guild} =
      %Guild{}
      |> Guild.changeset(%{
        name: "Guild #{System.unique_integer([:positive])}",
        master_char_id: character.id
      })
      |> Repo.insert()

    ctx = %{guild_id: guild.id, char_id: character.id, session_pid: self(), capacity: 600}
    assert :ok = Lock.claim(guild.id, character.id, self())
    on_exit(fn -> Lock.stop(guild.id) end)

    %{
      ctx: ctx,
      character: character,
      guild: guild,
      stats: Stats.from_character(character)
    }
  end

  describe "deposit/5" do
    test "reduces inventory and inserts guild storage with an audit row", %{
      ctx: ctx,
      character: character,
      guild: guild
    } do
      seed_inv(character.id, @potion, 10)
      inventory = inventory_map(character.id)
      index = index_of(inventory, @potion)

      assert {:ok, persisted_inventory, persisted_storage, {:reduced, ^index, 6},
              {:added, 0, _item}} =
               GuildStorageOps.deposit(ctx, inventory, %{}, index, 4)

      assert %{^index => %InventoryItem{amount: 6}} = persisted_inventory
      assert %{0 => %InventoryItem{nameid: @potion, amount: 4}} = persisted_storage
      assert [%InventoryItem{amount: 6}] = InventoryPersistence.load_inventory(character.id)

      assert [%GuildStorageItem{nameid: @potion, amount: 4}] =
               GuildStoragePersistence.load_storage(guild.id)

      assert [%GuildStorageLog{char_id: char_id, amount: 4}] = logs(guild.id)
      assert char_id == character.id
    end

    test "conditionally stacks onto an existing guild row", %{
      ctx: ctx,
      character: character,
      guild: guild
    } do
      seed_inv(character.id, @potion, 10, %{identify: 1})
      seed_guild(guild.id, @potion, 5, %{identify: 1})
      inventory = inventory_map(character.id)
      storage = guild_storage_map(guild.id)
      index = index_of(inventory, @potion)

      assert {:ok, _inventory, persisted_storage, {:reduced, ^index, 7}, {:stacked, 0, 8}} =
               GuildStorageOps.deposit(ctx, inventory, storage, index, 3)

      assert %{0 => %InventoryItem{amount: 8}} = persisted_storage
      assert [%GuildStorageItem{amount: 8}] = GuildStoragePersistence.load_storage(guild.id)
    end

    test "conditionally tops a stack before inserting the split remainder", %{
      ctx: ctx,
      character: character,
      guild: guild
    } do
      seed_inv(character.id, @potion, 5, %{identify: 1})
      seed_guild(guild.id, @potion, 29_998, %{identify: 1})
      inventory = inventory_map(character.id)
      storage = guild_storage_map(guild.id)
      index = index_of(inventory, @potion)

      assert {:ok, %{}, persisted_storage, {:removed, ^index}, {:split, [{0, 30_000}, {1, 3}]}} =
               GuildStorageOps.deposit(ctx, inventory, storage, index, 5)

      assert %{0 => %InventoryItem{amount: 30_000}, 1 => %InventoryItem{amount: 3}} =
               persisted_storage

      assert [%GuildStorageItem{amount: 30_000}, %GuildStorageItem{amount: 3}] =
               GuildStoragePersistence.load_storage(guild.id)
    end

    test "rejects ineligible items before any write", %{
      ctx: ctx,
      character: character,
      guild: guild
    } do
      expire_time = ~N[2030-01-01 00:00:00]
      equipped = seed_inv(character.id, @sword, 1, %{equip: 2})
      bound = seed_inv(character.id, @potion, 1, %{bound: 1})
      rental = seed_inv(character.id, @potion, 1, %{expire_time: expire_time})
      restricted = seed_inv(character.id, @restricted, 1)
      inventory = inventory_map(character.id)

      for {item, reason} <- [
            {equipped, :item_equipped},
            {bound, :not_storable},
            {rental, :rental},
            {restricted, :no_guild_storage}
          ] do
        index = index_of_id(inventory, item.id)
        assert {:error, ^reason} = GuildStorageOps.deposit(ctx, inventory, %{}, index, 1)
      end

      assert length(InventoryPersistence.load_inventory(character.id)) == 4
      assert [] = GuildStoragePersistence.load_storage(guild.id)
      assert [] = logs(guild.id)
    end

    test "rejects a deposit at the active guild capacity before any write", %{
      ctx: ctx,
      character: character,
      guild: guild
    } do
      seed_inv(character.id, @potion, 1)
      seed_guild(guild.id, @sword, 1)
      inventory = inventory_map(character.id)
      storage = guild_storage_map(guild.id)
      index = index_of(inventory, @potion)

      assert {:error, :storage_full} =
               GuildStorageOps.deposit(%{ctx | capacity: 1}, inventory, storage, index, 1)

      assert [%InventoryItem{amount: 1}] = InventoryPersistence.load_inventory(character.id)

      assert [%GuildStorageItem{nameid: @sword}] =
               GuildStoragePersistence.load_storage(guild.id)

      assert [] = logs(guild.id)
    end

    test "returns not_holder without writing after the claim is lost", %{
      ctx: ctx,
      character: character,
      guild: guild
    } do
      seed_inv(character.id, @potion, 4)
      inventory = inventory_map(character.id)
      index = index_of(inventory, @potion)
      assert :ok = Lock.stop(guild.id)
      assert_eventually(fn -> Lock.holder(guild.id) == :error end)

      assert {:error, :not_holder} =
               GuildStorageOps.deposit(ctx, inventory, %{}, index, 4)

      assert [%InventoryItem{amount: 4}] = InventoryPersistence.load_inventory(character.id)
      assert [] = GuildStoragePersistence.load_storage(guild.id)
      assert [] = logs(guild.id)
    end
  end

  describe "withdraw/6" do
    test "conditionally reduces guild storage and inserts inventory with a negative audit", %{
      ctx: ctx,
      guild: guild,
      stats: stats
    } do
      seed_guild(guild.id, @potion, 10)
      storage = guild_storage_map(guild.id)
      index = index_of(storage, @potion)

      assert {:ok, persisted_inventory, persisted_storage, {:added, 0, _item},
              {:reduced, ^index, 6}} =
               GuildStorageOps.withdraw(ctx, %{}, storage, stats, index, 4)

      assert %{0 => %InventoryItem{amount: 4}} = persisted_inventory
      assert %{^index => %InventoryItem{amount: 6}} = persisted_storage
      assert [%GuildStorageItem{amount: 6}] = GuildStoragePersistence.load_storage(guild.id)
      assert [%GuildStorageLog{amount: -4}] = logs(guild.id)
    end

    test "conditionally deletes the guild row when the whole stack moves", %{
      ctx: ctx,
      guild: guild,
      stats: stats
    } do
      seed_guild(guild.id, @potion, 4)
      storage = guild_storage_map(guild.id)
      index = index_of(storage, @potion)

      assert {:ok, _inventory, %{}, {:added, 0, _item}, {:removed, ^index}} =
               GuildStorageOps.withdraw(ctx, %{}, storage, stats, index, 4)

      assert [] = GuildStoragePersistence.load_storage(guild.id)
    end

    test "rejects an overweight withdrawal before any write", %{
      ctx: ctx,
      character: character,
      guild: guild,
      stats: stats
    } do
      fill = div(Weight.max_weight(stats), 70)
      seed_inv(character.id, @potion, fill)
      seed_guild(guild.id, @potion, 1)
      inventory = inventory_map(character.id)
      storage = guild_storage_map(guild.id)
      index = index_of(storage, @potion)

      assert {:error, :overweight} =
               GuildStorageOps.withdraw(ctx, inventory, storage, stats, index, 1)

      assert [%InventoryItem{amount: ^fill}] = InventoryPersistence.load_inventory(character.id)
      assert [%GuildStorageItem{amount: 1}] = GuildStoragePersistence.load_storage(guild.id)
      assert [] = logs(guild.id)
    end

    test "returns not_holder without writing after the claim is lost", %{
      ctx: ctx,
      guild: guild,
      stats: stats
    } do
      seed_guild(guild.id, @potion, 4)
      storage = guild_storage_map(guild.id)
      index = index_of(storage, @potion)
      assert :ok = Lock.stop(guild.id)
      assert_eventually(fn -> Lock.holder(guild.id) == :error end)

      assert {:error, :not_holder} =
               GuildStorageOps.withdraw(ctx, %{}, storage, stats, index, 4)

      assert [] = InventoryPersistence.load_inventory(ctx.char_id)
      assert [%GuildStorageItem{amount: 4}] = GuildStoragePersistence.load_storage(guild.id)
      assert [] = logs(guild.id)
    end
  end

  describe "transaction atomicity" do
    test "a stale guild row rolls back the inventory write", %{
      ctx: ctx,
      character: character,
      guild: guild
    } do
      seed_inv(character.id, @potion, 10, %{identify: 1})
      guild_item = seed_guild(guild.id, @potion, 5, %{identify: 1})
      inventory = inventory_map(character.id)
      storage = guild_storage_map(guild.id)
      index = index_of(inventory, @potion)

      GuildStorageItem
      |> where([item], item.id == ^guild_item.id)
      |> Repo.update_all(set: [amount: 8])

      assert {:error, :stale} =
               GuildStorageOps.deposit(ctx, inventory, storage, index, 3)

      assert [%InventoryItem{amount: 10}] = InventoryPersistence.load_inventory(character.id)
      assert [%GuildStorageItem{amount: 8}] = GuildStoragePersistence.load_storage(guild.id)
      assert [] = logs(guild.id)
    end

    test "a failed audit append rolls back both item writes", %{
      ctx: ctx,
      character: character,
      guild: guild
    } do
      seed_inv(character.id, @potion, 10)
      inventory = inventory_map(character.id)
      index = index_of(inventory, @potion)

      stub(GuildStoragePersistence, :log, fn _guild_id, _char_id, _item, _amount ->
        {:error, :forced_failure}
      end)

      assert {:error, :forced_failure} =
               GuildStorageOps.deposit(ctx, inventory, %{}, index, 4)

      assert [%InventoryItem{amount: 10}] = InventoryPersistence.load_inventory(character.id)
      assert [] = GuildStoragePersistence.load_storage(guild.id)
      assert [] = logs(guild.id)
    end
  end

  describe "attribute fidelity" do
    test "preserves item attributes including craft through a database round trip", %{
      ctx: ctx,
      character: character,
      guild: guild,
      stats: stats
    } do
      craft = ItemCraft.to_map(ItemCraft.forged(:fire, 3, character.id))

      seed_inv(character.id, @sword, 1, %{
        identify: 1,
        refine: 7,
        attribute: 1,
        card0: @poring_card,
        craft: craft,
        random_options: %{"1" => %{"val" => 5, "parm" => 0}},
        bound: 2,
        unique_id: 123_456,
        enchant_grade: 2
      })

      inventory = inventory_map(character.id)
      index = index_of(inventory, @sword)

      assert {:ok, %{}, _storage, _inv_change, _storage_change} =
               GuildStorageOps.deposit(ctx, inventory, %{}, index, 1)

      assert [%GuildStorageItem{craft: ^craft}] = GuildStoragePersistence.load_storage(guild.id)

      stored = guild_storage_map(guild.id)
      stored_index = index_of(stored, @sword)

      assert {:ok, returned, %{}, _inv_change, _storage_change} =
               GuildStorageOps.withdraw(ctx, %{}, stored, stats, stored_index, 1)

      assert %InventoryItem{
               identify: 1,
               refine: 7,
               attribute: 1,
               card0: @poring_card,
               craft: ^craft,
               random_options: %{"1" => %{"val" => 5, "parm" => 0}},
               bound: 2,
               unique_id: 123_456,
               enchant_grade: 2
             } = returned[index_of(returned, @sword)]
    end
  end

  defp seed_inv(char_id, nameid, amount, attrs \\ %{}) do
    {:ok, item} =
      InventoryPersistence.insert_item(
        char_id,
        Map.merge(%{nameid: nameid, amount: amount}, attrs)
      )

    item
  end

  defp seed_guild(guild_id, nameid, amount, attrs \\ %{}) do
    {:ok, item} =
      GuildStoragePersistence.insert_item(
        guild_id,
        Map.merge(%{nameid: nameid, amount: amount}, attrs)
      )

    item
  end

  defp inventory_map(char_id) do
    char_id
    |> InventoryPersistence.load_inventory()
    |> PlayerState.from_list()
  end

  defp guild_storage_map(guild_id) do
    guild_id
    |> GuildStoragePersistence.load_storage()
    |> Enum.map(&GuildStoragePersistence.to_session_item/1)
    |> PlayerState.from_list()
  end

  defp index_of(map, nameid) do
    Enum.find_value(map, fn {index, item} ->
      if item.nameid == nameid, do: index
    end)
  end

  defp index_of_id(map, id) do
    Enum.find_value(map, fn {index, item} ->
      if item.id == id, do: index
    end)
  end

  defp logs(guild_id) do
    GuildStorageLog
    |> where([log], log.guild_id == ^guild_id)
    |> order_by([log], log.id)
    |> Repo.all()
  end
end
