defmodule Aesir.ZoneServer.Mmo.PetManagement.EggTest do
  use ExUnit.Case, async: true

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.PetManagement.Egg

  test "new eggs store an identified pet ID in low-word, high-word order" do
    assert %{card0: 256, card1: 0x5678, card2: 0x1234, card3: 6, identify: 1} =
             Egg.egg_attrs(0x12345678, 500)

    assert Egg.pet_id(%{card0: 256, card1: 0x5678, card2: 0x1234}) == 0x12345678
  end

  test "intimacy grades preserve the rename bit at each boundary" do
    for {intimacy, grade} <- [
          {0, 2},
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
    egg = %InventoryItem{card0: 256, card2: 1, attribute: 1}
    other = %{egg | card0: 0}
    assert Egg.hatched?(egg)
    refute Egg.hatched?(other)
    refute Egg.hatched?(%{egg | attribute: 0})
    assert Egg.pet_id(other) == nil
    assert Egg.find(%{0 => other, 2 => egg}, 65_536) == {:ok, egg}
    assert Egg.find(%{0 => other}, 65_536) == :error
  end
end
