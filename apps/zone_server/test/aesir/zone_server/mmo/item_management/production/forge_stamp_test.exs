defmodule Aesir.ZoneServer.Mmo.ItemManagement.Production.ForgeStampTest do
  use ExUnit.Case, async: true

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.ItemManagement.Production.ForgeStamp

  test "round-trips every crumb count and forge element" do
    star_damage = %{0 => 0, 1 => 5, 2 => 10, 3 => 40}

    for element <- [:neutral, :water, :earth, :fire, :wind], crumb_count <- 0..3 do
      stamp = ForgeStamp.encode(element, crumb_count, 1)

      assert ForgeStamp.decode(stamp) ==
               {:ok,
                %{
                  element: element,
                  star_damage: Map.fetch!(star_damage, crumb_count),
                  creator_id: 1
                }}
    end
  end

  test "three crumbs decode to 40 star damage, not the stored value 15" do
    stamp = ForgeStamp.encode(:fire, 3, 1)

    assert div(stamp.card1, 256) == 15
    # The maximum stores 15 for metadata compatibility but deliberately grants 40 in combat.
    assert {:ok, %{star_damage: 40}} = ForgeStamp.decode(stamp)
  end

  test "one and two crumbs retain their stored combat values" do
    assert {:ok, %{star_damage: 5}} =
             :wind |> ForgeStamp.encode(1, 1) |> ForgeStamp.decode()

    assert {:ok, %{star_damage: 10}} =
             :earth |> ForgeStamp.encode(2, 1) |> ForgeStamp.decode()
  end

  test "packs card values and reconstructs a character id beyond 16 bits" do
    stamp = ForgeStamp.encode(:fire, 2, 150_000)

    assert stamp == %{card0: 0x00FF, card1: 10 * 256 + 3, card2: 18_928, card3: 2}
    assert {:ok, %{creator_id: 150_000}} = ForgeStamp.decode(stamp)
  end

  test "returns error for a non-forged item without raising" do
    assert ForgeStamp.decode(%InventoryItem{}) == :error
  end

  test "returns error for corrupt card payloads without raising" do
    corrupt_stamp = %{ForgeStamp.encode(:neutral, 0, 1) | card1: 6 * 256}

    assert ForgeStamp.decode(corrupt_stamp) == :error
    assert ForgeStamp.decode(%{card0: 0x00FF, card1: "invalid", card2: nil, card3: 0}) == :error
  end
end
