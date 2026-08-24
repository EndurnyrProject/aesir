defmodule Aesir.ZoneServer.Guild.StorageTest do
  use ExUnit.Case, async: true

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Guild.State
  alias Aesir.ZoneServer.Guild.Storage
  alias Aesir.ZoneServer.Mmo.ItemManagement

  @guild_storage 10_016
  @red_potion 501
  @restricted_item 9895
  @restricted_card 6846
  @unknown_card 999_999

  describe "capacity/1" do
    test "returns zero when the guild has not learned Guild Storage Expansion" do
      guild = guild(0)

      assert Storage.capacity(guild) == 0
    end

    test "returns 200 at Guild Storage Expansion level 1" do
      guild = guild(1)

      assert Storage.capacity(guild) == 200
    end

    test "scales by 100 slots through Guild Storage Expansion level 5" do
      for {level, capacity} <- [{2, 300}, {3, 400}, {4, 500}, {5, 600}] do
        assert Storage.capacity(guild(level)) == capacity
      end
    end
  end

  describe "add/5" do
    test "keeps a refined and carded item separate from a plain stack" do
      storage = %{0 => item(nameid: @red_potion, amount: 5, identify: 1)}
      source = item(nameid: @red_potion, amount: 1, identify: 1, refine: 7, card0: 4001)

      assert {:ok,
              %{
                0 => %InventoryItem{amount: 5, refine: 0, card0: 0},
                1 => %InventoryItem{amount: 1, refine: 7, card0: 4001}
              }, {:added, 1, %InventoryItem{refine: 7, card0: 4001}}} =
               Storage.add(storage, def!(@red_potion), 1, 200, source)
    end
  end

  describe "remove/3" do
    test "delegates removals to the shared container core" do
      storage = %{0 => item(nameid: @red_potion, amount: 2)}

      assert {:ok, %{0 => %InventoryItem{amount: 1}}, {:reduced, 0, 1}} =
               Storage.remove(storage, 0, 1)
    end
  end

  describe "depositable/2" do
    test "accepts an unbound item" do
      assert :ok = Storage.depositable(item(), def!(@red_potion))
    end

    test "accepts a guild-bound item" do
      assert :ok = Storage.depositable(item(bound: 2), def!(@red_potion))
    end

    test "rejects an equipped or equipment-switch item" do
      for attrs <- [[equip: 1], [equip_switch: 1]] do
        assert {:error, :item_equipped} = Storage.depositable(item(attrs), def!(@red_potion))
      end
    end

    test "rejects account-bound, party-bound, and character-bound items" do
      for bound <- [1, 3, 4] do
        assert {:error, :not_storable} =
                 Storage.depositable(item(bound: bound), def!(@red_potion))
      end
    end

    test "rejects a rental item" do
      assert {:error, :rental} =
               Storage.depositable(item(expire_time: ~N[2026-08-25 00:00:00]), def!(@red_potion))
    end

    test "rejects an item with the guild storage restriction" do
      assert {:error, :no_guild_storage} =
               Storage.depositable(item(nameid: @restricted_item), def!(@restricted_item))
    end

    test "rejects an item holding a restricted card in any card slot" do
      for card_slot <- [:card0, :card1, :card2, :card3] do
        assert {:error, :no_guild_storage} =
                 Storage.depositable(item([{card_slot, @restricted_card}]), def!(@red_potion))
      end
    end

    test "accepts an item with an unrecognised card" do
      assert :ok = Storage.depositable(item(card0: @unknown_card), def!(@red_potion))
    end
  end

  defp guild(level) do
    %State{
      guild_id: 1,
      name: "Test Guild",
      master_char_id: 1,
      learned_skills: %{@guild_storage => level}
    }
  end

  defp item(attrs \\ []) do
    struct(InventoryItem, Map.new(attrs))
  end

  defp def!(id) do
    {:ok, definition} = ItemManagement.get_item_by_id(id)
    definition
  end
end
