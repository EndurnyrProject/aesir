defmodule Aesir.ZoneServer.Unit.Player.GrantedSkillEffectsTest do
  @moduledoc """
  Cross-checks that a skill granted by a real item script reaches the rule that
  reads it, through the shipped item catalog and the equipment fold.
  """
  use ExUnit.Case, async: true

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.Skills.Sage.SaFreecast
  alias Aesir.ZoneServer.Mmo.Skills.Thief.TfMiss
  alias Aesir.ZoneServer.Npc.Shop, as: ShopData
  alias Aesir.ZoneServer.Unit.Player.ItemHeal
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.EquipmentFold
  alias Aesir.ZoneServer.Unit.Player.Stats.Modifiers
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.Shop
  alias Aesir.ZoneServer.Unit.Stats.BaseStats

  @left_accessory 8
  @clip 2607
  @pirate_skeleton_card 4073
  @merchant_manual 2823
  @mage_manual 2824
  @red_potion 501
  @sword 1101

  describe "Stats.skill_level/2 and Stats.effective_skills/1" do
    test "the higher of the learned and granted levels wins, a grant-only skill included" do
      stats = %{
        progression: %{learned_skills: %{1 => 5, 2 => 1, 3 => 0}},
        granted_skills: %{2 => 3, 4 => 2, 1 => 1}
      }

      assert Stats.skill_level(stats, 1) == 5
      assert Stats.skill_level(stats, 2) == 3
      assert Stats.skill_level(stats, 4) == 2
      assert Stats.skill_level(stats, 3) == 0
      assert Stats.effective_skills(stats) == %{1 => 5, 2 => 3, 4 => 2}
    end

    test "a missing progression or grant map counts as nothing" do
      assert Stats.skill_level(%{}, 1) == 0
      assert Stats.skill_level(%{progression: nil, granted_skills: %{1 => 2}}, 1) == 2
      assert Stats.effective_skills(%{progression: %{learned_skills: %{1 => 1}}}) == %{1 => 1}
    end
  end

  test "granted Improve Dodge and Free Cast reach their walk-speed readers" do
    stats = %{
      progression: %{job_id: 12, learned_skills: %{}},
      granted_skills: %{49 => 4, 278 => 2}
    }

    assert TfMiss.move_haste(stats) == 4
    assert SaFreecast.level(%{stats: stats}) == 2
  end

  test "a Pirate Skeleton Card in a worn Clip gives Discount 5 at an NPC shop" do
    player = wearing([%{worn(@clip) | card0: @pirate_skeleton_card}])

    assert player.stats.granted_skills[37] == 5
    assert Shop.effective_buy_price(shop(), @red_potion, player) == 42
    assert Shop.effective_buy_price(shop(), @red_potion, wearing([])) == 50
  end

  @tag game_mode: :renewal
  test "the renewal Merchant Manual gives Overcharge 1 when selling" do
    player = wearing([worn(@merchant_manual)])

    assert Shop.effective_sell_price(@sword, player) == 53
  end

  @tag game_mode: :pre_renewal
  test "the classic Merchant Manual gives Overcharge 10 when selling" do
    player = wearing([worn(@merchant_manual)])

    assert Shop.effective_sell_price(@sword, player) == 62
  end

  test "the Mage Manual's Increase SP Recovery raises an item's SP heal" do
    assert ItemHeal.amounts(wearing([worn(@mage_manual)]), nil, 0, 100) == {0, 112}
    assert ItemHeal.amounts(wearing([]), nil, 0, 100) == {0, 102}
  end

  defp wearing(items) do
    stats =
      EquipmentFold.apply_equipment_modifiers(
        %Stats{
          base_stats: %BaseStats{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
          progression: %PlayerProgression{job_id: 0},
          modifiers: %Modifiers{equipment: %{}, status_effects: %{}, job_bonuses: %{}}
        },
        items
      )

    %PlayerState{character_id: System.unique_integer([:positive]), inventory: %{}, stats: stats}
  end

  defp worn(nameid) do
    %InventoryItem{
      id: System.unique_integer([:positive]),
      nameid: nameid,
      amount: 1,
      equip: @left_accessory,
      identify: 1,
      refine: 0,
      card0: 0,
      card1: 0,
      card2: 0,
      card3: 0
    }
  end

  defp shop do
    %ShopData{
      id: "tool_dealer",
      map: "prontera",
      x: 150,
      y: 60,
      dir: 4,
      sprite: 85,
      name: "Tool Dealer",
      items: [%{nameid: @red_potion, price: 50}]
    }
  end
end
