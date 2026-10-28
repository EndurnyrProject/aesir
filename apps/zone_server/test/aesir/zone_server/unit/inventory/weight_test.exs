defmodule Aesir.ZoneServer.Unit.Inventory.WeightTest do
  @moduledoc """
  Pure-domain tests for `Aesir.ZoneServer.Unit.Inventory.Weight`.

  No DB, no sockets. Inventory maps are built with real `%InventoryItem{}`
  structs via `PlayerState.from_list/1` using real item ids from
  `priv/db/re/items/` (loaded into `:persistent_term` at app boot). Stats are
  built as real `%Stats{}` structs with populated sub-structs.

  Reference values (loaded db):
  - Red Potion (501): weight 70
  - Sword (1101): weight 500
  - Body Armor (2301): weight 100
  - Novice (job 0): max_weight 20_000
  - Swordman (job 1): max_weight 28_000
  """
  use ExUnit.Case, async: true

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Unit.Inventory.Weight
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Modifiers
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.Stats.BaseStats

  @red_potion 501
  @sword 1101
  @body_armor 2301
  @novice 0
  @swordman 1

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
      random_options: []
    }

    struct(InventoryItem, Map.merge(base, Map.new(attrs)))
  end

  defp inventory(items), do: PlayerState.from_list(items)

  defp one_more_max(stats) do
    %{stats | modifiers: %{stats.modifiers | passive: %{max_weight_bonus: 1}}}
  end

  defp stats(job_id, str) do
    %Stats{
      base_stats: %BaseStats{str: str, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
      progression: %PlayerProgression{job_id: job_id},
      modifiers: %Modifiers{equipment: %{}, status_effects: %{}, job_bonuses: %{}}
    }
  end

  describe "current_weight/1" do
    test "is zero for an empty inventory" do
      assert Weight.current_weight(%{}) == 0
    end

    test "sums weight * amount across stacked and single items" do
      inv =
        inventory([
          item(nameid: @red_potion, amount: 10),
          item(nameid: @sword, amount: 1)
        ])

      assert Weight.current_weight(inv) == 70 * 10 + 500
    end

    test "counts equipped items the same as carried items" do
      inv = inventory([item(nameid: @body_armor, amount: 1, equip: 16)])

      assert Weight.current_weight(inv) == 100
    end
  end

  describe "max_weight/1" do
    test "is job base plus str * 300 for a novice" do
      assert Weight.max_weight(stats(@novice, 1)) == 20_000 + 1 * 300
    end

    test "uses the swordman base and effective str" do
      assert Weight.max_weight(stats(@swordman, 50)) == 28_000 + 50 * 300
    end

    test "adds the passive max_weight_bonus modifier when present (e.g. MC_INCCARRY)" do
      stats = %{
        stats(@novice, 1)
        | modifiers: %Modifiers{
            equipment: %{},
            status_effects: %{},
            job_bonuses: %{},
            passive: %{max_weight_bonus: 20_000}
          }
      }

      assert Weight.max_weight(stats) == 20_000 + 1 * 300 + 20_000
    end
  end

  describe "would_exceed?/3" do
    test "false when the addition fits exactly at max" do
      inv = inventory([item(nameid: @red_potion, amount: 1)])
      stats = stats(@novice, 1)
      headroom = Weight.max_weight(stats) - Weight.current_weight(inv)

      refute Weight.would_exceed?(inv, stats, headroom)
    end

    test "true when the addition crosses max by one" do
      inv = inventory([item(nameid: @red_potion, amount: 1)])
      stats = stats(@novice, 1)
      headroom = Weight.max_weight(stats) - Weight.current_weight(inv)

      assert Weight.would_exceed?(inv, stats, headroom + 1)
    end
  end

  describe "regen_overweight?/2" do
    # Novice with STR 1: max 20_300. 70% is 14_210 (203 Red Potions); 50% is 10_150 (145).
    # `one_more_max/1` raises the max by one unit, putting the same load just under the rate.
    @tag game_mode: :renewal
    test "renewal is overweight at exactly 70% of max weight" do
      inv = inventory([item(amount: 203)])

      assert Weight.regen_overweight?(inv, stats(@novice, 1))
      refute Weight.regen_overweight?(inv, one_more_max(stats(@novice, 1)))
    end

    @tag game_mode: :pre_renewal
    test "pre-renewal is overweight at exactly 50% of max weight" do
      inv = inventory([item(amount: 145)])

      assert Weight.regen_overweight?(inv, stats(@novice, 1))
      refute Weight.regen_overweight?(inv, one_more_max(stats(@novice, 1)))
    end

    test "regen_overweight?/2 is false when max weight is 0" do
      stats = stats(999_999, 0)

      assert Weight.max_weight(stats) == 0
      refute Weight.regen_overweight?(inventory([item(amount: 10)]), stats)
    end
  end
end
