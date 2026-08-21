defmodule Aesir.ZoneServer.Unit.Cart.WeightTest do
  @moduledoc """
  Pure-domain tests for `Aesir.ZoneServer.Unit.Cart.Weight`.

  No DB, no sockets. Cart maps are built with real `%InventoryItem{}` structs
  via `PlayerState.from_list/1` using real item ids from `priv/db/re/items/`
  (loaded into `:persistent_term` at app boot). The cart cap is a flat 80_000
  (rAthena's 8000 display weight in the internal `×10` unit Aesir stores weights in).

  Reference values (loaded db):
  - Red Potion (501): weight 70
  - Sword (1101): weight 500
  """
  use ExUnit.Case, async: true

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Unit.Cart.Weight
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @red_potion 501
  @sword 1101

  defp item(attrs) do
    base = %{
      id: System.unique_integer([:positive]),
      char_id: 1,
      nameid: @red_potion,
      amount: 1,
      equip: 0,
      identify: 1,
      refine: 0,
      attribute: 0,
      card0: 0,
      card1: 0,
      card2: 0,
      card3: 0,
      random_options: %{}
    }

    struct(InventoryItem, Map.merge(base, Map.new(attrs)))
  end

  defp cart(items), do: PlayerState.from_list(items)

  describe "max_weight/0" do
    test "is the flat 80_000 cap" do
      assert Weight.max_weight() == 80_000
    end
  end

  describe "current_weight/1" do
    test "is zero for an empty cart" do
      assert Weight.current_weight(%{}) == 0
    end

    test "sums weight * amount across stacked and single items" do
      c =
        cart([
          item(nameid: @red_potion, amount: 10),
          item(nameid: @sword, amount: 1)
        ])

      assert Weight.current_weight(c) == 70 * 10 + 500
    end
  end

  describe "would_exceed?/2" do
    test "false when current + added equals the 80_000 cap exactly" do
      assert Weight.would_exceed?(%{}, 80_000) == false
    end

    test "true when current + added crosses the cap by one" do
      assert Weight.would_exceed?(%{}, 80_001) == true
    end

    test "accounts for the current cart contents" do
      c = cart([item(nameid: @sword, amount: 1)])

      refute Weight.would_exceed?(c, 79_500)
      assert Weight.would_exceed?(c, 79_501)
    end
  end
end
