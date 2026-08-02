defmodule Aesir.ZoneServer.Mmo.ItemDrop.GroundItemStoreTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.ItemDrop.GroundItem
  alias Aesir.ZoneServer.Mmo.ItemDrop.GroundItemStore

  setup :setup_ets_tables

  describe "GroundItem.new/5" do
    test "builds with a unique positive id and stamps dropped_at" do
      a = GroundItem.new(501, 1, 100, 100)
      b = GroundItem.new(501, 1, 100, 100)

      assert a.id > 0
      assert b.id > 0
      assert a.id != b.id
      assert is_integer(a.dropped_at)
      assert a.nameid == 501
      assert a.amount == 1
      assert a.x == 100
      assert a.y == 100
      assert a.identified == true
      assert a.owners == nil
      assert a.unlock_at == nil
    end

    test "scatters stacked drops with a sub-cell offset in {3, 6, 9, 12}" do
      subs =
        for _ <- 1..50, item <- [GroundItem.new(501, 1, 100, 100)] do
          {item.sub_x, item.sub_y}
        end

      assert Enum.all?(subs, fn {sx, sy} -> sx in [3, 6, 9, 12] and sy in [3, 6, 9, 12] end)
    end
  end

  describe "put/2 and query_in_range/4" do
    test "returns items inside range and excludes those out of range" do
      in_range = GroundItem.new(501, 1, 100, 100)
      out_range = GroundItem.new(502, 1, 200, 200)

      assert :ok = GroundItemStore.put("prontera", in_range)
      assert :ok = GroundItemStore.put("prontera", out_range)

      result = GroundItemStore.query_in_range("prontera", 100, 100, 5)
      ids = Enum.map(result, & &1.id)

      assert in_range.id in ids
      refute out_range.id in ids
    end

    test "excludes items on a different map" do
      item = GroundItem.new(501, 1, 100, 100)
      assert :ok = GroundItemStore.put("morocc", item)

      assert [] = GroundItemStore.query_in_range("prontera", 100, 100, 5)
    end
  end

  describe "get/2" do
    test "returns an item without removing it" do
      item = GroundItem.new(501, 1, 100, 100)
      assert :ok = GroundItemStore.put("prontera", item)

      assert {:ok, ^item} = GroundItemStore.get("prontera", item.id)
      assert {:ok, ^item} = GroundItemStore.get("prontera", item.id)
    end

    test "returns {:error, :gone} for an unknown id" do
      assert {:error, :gone} = GroundItemStore.get("prontera", 123_456)
    end
  end

  describe "claim/2" do
    test "returns {:ok, item} once and {:error, :gone} on the second call" do
      item = GroundItem.new(501, 1, 100, 100)
      assert :ok = GroundItemStore.put("prontera", item)

      assert {:ok, ^item} = GroundItemStore.claim("prontera", item.id)
      assert {:error, :gone} = GroundItemStore.claim("prontera", item.id)
    end

    test "preserves an ownership stamp through a claim" do
      owners = {101, 202, 303}
      unlock_at = {1_000, 2_000, 3_000}
      item = GroundItem.new(501, 1, 100, 100, true, owners: owners, unlock_at: unlock_at)

      assert :ok = GroundItemStore.put("prontera", item)
      assert {:ok, claimed} = GroundItemStore.claim("prontera", item.id)
      assert claimed.owners == owners
      assert claimed.unlock_at == unlock_at
    end

    test "returns {:error, :gone} for an unknown id" do
      assert {:error, :gone} = GroundItemStore.claim("prontera", 123_456)
    end
  end

  describe "expire_due/3" do
    test "removes and returns only items older than the ttl" do
      now = System.monotonic_time(:millisecond)
      old = GroundItem.new(501, 1, 100, 100)
      fresh = GroundItem.new(502, 1, 100, 100)

      :ok = GroundItemStore.put("prontera", %{old | dropped_at: now - 120_000})
      :ok = GroundItemStore.put("prontera", fresh)

      expired = GroundItemStore.expire_due("prontera", now, 60_000)

      assert Enum.map(expired, & &1.id) == [old.id]
      assert {:error, :gone} = GroundItemStore.claim("prontera", old.id)
      assert {:ok, ^fresh} = GroundItemStore.claim("prontera", fresh.id)
    end
  end
end
