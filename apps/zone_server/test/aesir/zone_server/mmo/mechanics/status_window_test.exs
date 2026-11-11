defmodule Aesir.ZoneServer.Mmo.Mechanics.StatusWindowTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Mechanics.StatusWindow.PreRenewal
  alias Aesir.ZoneServer.Mmo.Mechanics.StatusWindow.Renewal

  @components %{
    status_atk: 120,
    hilt_binding_atk: 4,
    bonus_atk: 15,
    right_atk: 100,
    right_refine_atk: 14,
    right_level: 3,
    left_atk: 0,
    left_refine_atk: 0,
    left_level: 0,
    status_watk: 0,
    level4_watk: 0,
    hard_def: 60,
    soft_def: 45,
    hard_mdef: 20,
    soft_mdef: 70,
    vit: 50,
    status_matk: 90,
    weapon_matk: 130,
    flat_matk: 25,
    matk_min: 180,
    matk_max: 260,
    matk_amp_rate: 0
  }

  describe "renewal" do
    test "shows status parts on the left and equipment parts on the right" do
      assert Renewal.values(@components) == %{
               atk1: 120,
               atk2: 100 + 14 + 15,
               def1: 45,
               def2: 60,
               mdef1: 70,
               mdef2: 20,
               matk1: 130 + 25,
               matk2: 90
             }
    end

    test "status weapon ATK joins the right weapon, or the left hand without one" do
      dual = %{@components | left_atk: 80, left_refine_atk: 5, status_watk: 30}
      left_only = %{dual | right_atk: 0, right_refine_atk: 0}

      assert Renewal.values(dual).atk2 == 114 + 30 + 85 + 15
      assert Renewal.values(left_only).atk2 == 85 + 30 + 15
    end

    test "a hand's weapon ATK never drops below zero" do
      weakened = %{@components | status_watk: -500}

      assert Renewal.values(weakened).atk2 == 15
    end
  end

  describe "pre-renewal" do
    test "shows weapon ATK with status ATK and refine ATK apart" do
      assert PreRenewal.values(@components) == %{
               atk1: 120 + 4 + 15 + 100,
               atk2: 14,
               def1: 60,
               def2: 45,
               mdef1: 20,
               mdef2: 70 - 25,
               matk1: 260,
               matk2: 180
             }
    end

    test "status weapon ATK joins the right hand always and an armed left hand" do
      buffed = %{@components | status_watk: 30}
      bare = %{buffed | right_atk: 0, right_refine_atk: 0}
      dual = %{buffed | left_atk: 80, left_refine_atk: 5}

      assert PreRenewal.values(buffed).atk1 == 139 + 130
      assert PreRenewal.values(bare).atk1 == 139 + 30
      assert PreRenewal.values(dual).atk1 == 139 + 130 + 110
      assert PreRenewal.values(dual).atk2 == 14 + 5
    end

    test "only a level 4 weapon takes the level 4 status weapon ATK" do
      nibelungen = %{@components | level4_watk: 50}

      assert PreRenewal.values(nibelungen).atk1 == 139 + 100
      assert PreRenewal.values(%{nibelungen | right_level: 4}).atk1 == 139 + 150
    end

    test "soft MDEF loses its VIT half and stops at zero" do
      assert PreRenewal.values(%{@components | soft_mdef: 10}).mdef2 == 0
    end

    test "an armed Mystical Amplification is taken back out of the band" do
      amplified = %{@components | matk_min: 270, matk_max: 390, matk_amp_rate: 50}

      assert PreRenewal.values(amplified).matk2 == div(270 * 100 + 50, 150)
      assert PreRenewal.values(amplified).matk1 == div(390 * 100 + 50, 150)
    end
  end
end
