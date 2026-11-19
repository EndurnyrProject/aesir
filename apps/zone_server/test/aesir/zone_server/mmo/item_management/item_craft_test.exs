defmodule Aesir.ZoneServer.Mmo.ItemManagement.ItemCraftTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemCraft

  describe "star_damage/1" do
    test "maps forged star crumb counts to their combat damage" do
      for {star_crumbs, damage} <- [{0, 0}, {1, 5}, {2, 10}, {3, 40}] do
        craft = ItemCraft.forged(:fire, star_crumbs, 42)

        assert ItemCraft.star_damage(craft) == damage
      end
    end

    test "returns no star damage for signed items" do
      craft = ItemCraft.signed(42)

      damage = ItemCraft.star_damage(craft)

      assert damage == 0
    end
  end

  describe "to_map/1" do
    test "serializes signed and forged crafts with string keys and values" do
      signed = ItemCraft.signed(42)
      forged = ItemCraft.forged(:fire, 3, 42)

      signed_map = ItemCraft.to_map(signed)
      forged_map = ItemCraft.to_map(forged)

      assert signed_map == %{
               "kind" => "signed",
               "creator_char_id" => 42,
               "element" => "neutral",
               "star_crumbs" => 0
             }

      assert forged_map == %{
               "kind" => "forged",
               "creator_char_id" => 42,
               "element" => "fire",
               "star_crumbs" => 3
             }
    end
  end

  describe "from_map/1" do
    test "deserializes a valid string-keyed map" do
      map = %{
        "kind" => "forged",
        "creator_char_id" => 42,
        "element" => "fire",
        "star_crumbs" => 3
      }

      result = ItemCraft.from_map(map)

      assert result == {:ok, ItemCraft.forged(:fire, 3, 42)}
    end

    test "rejects absent and malformed craft metadata" do
      valid_map = %{
        "kind" => "forged",
        "creator_char_id" => 42,
        "element" => "fire",
        "star_crumbs" => 3
      }

      assert ItemCraft.from_map(nil) == :error
      assert ItemCraft.from_map(Map.delete(valid_map, "element")) == :error
      assert ItemCraft.from_map(%{valid_map | "kind" => "unknown"}) == :error
      assert ItemCraft.from_map(%{valid_map | "element" => "shadow"}) == :error
      assert ItemCraft.from_map(%{valid_map | "star_crumbs" => 4}) == :error
    end

    test "round-trips signed and forged crafts" do
      crafts = [ItemCraft.signed(42), ItemCraft.forged(:fire, 3, 42)]

      for craft <- crafts do
        assert ItemCraft.from_map(ItemCraft.to_map(craft)) == {:ok, craft}
      end
    end
  end
end
