defmodule Aesir.ZoneServer.Mmo.PetManagement.EggTest do
  use ExUnit.Case, async: true

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.PetManagement.Egg

  test "pet IDs round-trip through the card words" do
    for id <- [1, 65_535, 65_536, 4_000_000] do
      assert id == id |> Egg.egg_attrs(500) |> Egg.pet_id()
    end
  end

  test "intimacy grades preserve the rename bit at each boundary" do
    for {intimacy, grade} <- [
          {0, 2},
          {1, 2},
          {99, 2},
          {100, 4},
          {249, 4},
          {250, 6},
          {749, 6},
          {750, 8},
          {909, 8},
          {910, 10},
          {1000, 10},
          {1001, 0}
        ] do
      assert Egg.card3(0, intimacy) == grade
      assert Egg.card3(1, intimacy) == grade + 1
    end
  end

  test "finds only marked eggs and recognizes hatched eggs" do
    egg = struct(InventoryItem, Map.merge(Egg.egg_attrs(65_536, 500), %{attribute: 1}))
    other = %InventoryItem{card1: 0, card2: 1, attribute: 1}
    assert Egg.card0_pet() == 256
    assert Egg.pet_egg?(egg)
    assert Egg.hatched?(egg)
    refute Egg.pet_egg?(other)
    refute Egg.hatched?(other)
    refute Egg.hatched?(%{egg | attribute: 0})
    assert Egg.pet_id(other) == nil
    assert Egg.find(%{0 => other, 2 => egg}, 65_536) == {:ok, egg}
    assert Egg.find(%{0 => other}, 65_536) == :error
  end
end
