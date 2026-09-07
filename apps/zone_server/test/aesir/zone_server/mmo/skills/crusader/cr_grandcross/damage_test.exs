defmodule Aesir.ZoneServer.Mmo.Skills.Crusader.CrGrandcross.DamageTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skills.Crusader.CrGrandcross.Damage

  test "mode-specific hybrid composition and defense precede enemy holy stages or one self half-rate" do
    renewal = inputs(1.25)
    classic = inputs(1.5)

    assert Damage.calculate(:renewal, renewal) == 257
    assert Damage.calculate(:pre_renewal, classic) == 487
    assert Damage.calculate(:renewal, %{renewal | target_ref: {:player, 1}}) == 103
    assert Damage.calculate(:pre_renewal, %{classic | target_ref: {:player, 1}}) == 162

    assert Damage.calculate(:renewal, %{renewal | target_ref: {:mob, 1}}) == 257
    assert Damage.calculate(:pre_renewal, %{classic | target_ref: {:mob, 1}}) == 487
  end

  test "weapon components retain size, element, refine and percentage stages without mastery" do
    renewal = inputs(1.25)
    {:player, base} = renewal.physical

    parts = %{
      base
      | flat_atk: 20,
        weapon_atk: 80,
        refine_atk: 10,
        overrefine_atk: 3,
        mastery_atk: 999
    }

    renewal = %{renewal | physical: {:player, parts}, size_rate: 75, equipment_atk_rate: 20}
    classic = %{renewal | magic: %{renewal.magic | element_modifier: 1.5}}

    assert Damage.calculate(:renewal, renewal) == 390
    assert Damage.calculate(:pre_renewal, classic) == 726
    assert Damage.calculate(:renewal, %{renewal | neutral_modifier: 0.5}) == 281

    assert Damage.calculate(:renewal, %{
             renewal
             | physical: {:player, %{parts | hand: :left_hand}}
           }) == 281

    assert Damage.calculate(:renewal, %{renewal | physical: {:player, %{parts | refine_atk: 999}}}) ==
             390

    assert Damage.calculate(:pre_renewal, %{
             classic
             | physical: {:player, %{parts | refine_atk: 11}}
           }) == 729

    for {mode, data} <- [renewal: renewal, pre_renewal: classic] do
      assert Damage.calculate(mode, %{data | physical: {:player, %{parts | mastery_atk: 0}}}) ==
               Damage.calculate(mode, data)
    end
  end

  test "non-player rolls never acquire doubled player status or self damage" do
    renewal = %{inputs(1.25) | physical: {:non_player, 100}, caster_ref: {:mob, 1}}
    classic = %{inputs(1.5) | physical: {:non_player, 100}, caster_ref: {:mob, 1}}
    assert Damage.calculate(:renewal, renewal) == 147
    assert Damage.calculate(:pre_renewal, classic) == 487
    assert Damage.calculate(:renewal, %{renewal | target_ref: {:mob, 1}}) == 0
    assert Damage.calculate(:pre_renewal, %{classic | target_ref: {:mob, 1}}) == 0
  end

  test "magic card, skill, status and trait stages stay on their hybrid component" do
    renewal = inputs(1.25)

    magic = %{
      renewal.magic
      | smatk: 50,
        mres: 400,
        matk_rate: 20,
        skill_atk_rate: 20,
        skill_taken_rate: 10,
        attack: %{renewal.magic.attack | size: 20},
        taken: %{renewal.magic.taken | race: 25}
    }

    renewal = %{renewal | magic: magic}
    classic = %{renewal | magic: %{magic | element_modifier: 1.5}}

    assert Damage.calculate(:renewal, renewal) == 260
    assert Damage.calculate(:pre_renewal, classic) == 514
    assert Damage.calculate(:renewal, %{renewal | magic: %{magic | ignore_mdef_rate: 50}}) == 260

    assert Damage.calculate(:pre_renewal, %{
             classic
             | magic: %{classic.magic | ignore_mdef_rate: 50}
           }) == 531

    assert Damage.calculate(:pre_renewal, %{
             classic
             | magic: %{classic.magic | ignore_mdef?: true}
           }) == 567
  end

  test "odd hybrid sums round before the level ratio and immune hits keep their floor" do
    data = inputs(1.0)

    data = %{
      data
      | level: 3,
        matk: 101,
        physical_defense: {0, 0},
        magic: %{data.magic | hard_mdef: 0, soft_mdef: 0}
    }

    assert Damage.calculate(:renewal, data) == 330
    assert Damage.calculate(:pre_renewal, data) == 440

    for mode <- [:renewal, :pre_renewal] do
      immune = %{data | magic: %{data.magic | element_modifier: 0}}
      assert Damage.calculate(mode, immune) == 1
      assert Damage.calculate(mode, %{immune | target_ref: immune.caster_ref}) == 1
    end
  end

  test "percentage physical DEF-ignore reduces both defense slots without bypassing magic defense" do
    renewal = inputs(1.25)
    classic = inputs(1.5)
    assert Damage.calculate(:renewal, Map.put(renewal, :physical_ignore_rate, 50)) == 281
    assert Damage.calculate(:pre_renewal, Map.put(classic, :physical_ignore_rate, 50)) == 535
    assert Damage.calculate(:renewal, Map.put(renewal, :physical_ignore_rate, 100)) == 303
    assert Damage.calculate(:pre_renewal, Map.put(classic, :physical_ignore_rate, 100)) == 577
  end

  defp inputs(element) do
    %{
      caster_ref: {:player, 1},
      target_ref: {:mob, 2},
      level: 1,
      physical:
        {:player,
         %{
           status_atk: 100,
           flat_atk: 0,
           weapon_atk: 0,
           refine_atk: 0,
           overrefine_atk: 0,
           mastery_atk: 0,
           hand: :right_hand,
           source: :weapon
         }},
      physical_defense: {20, 10},
      physical_ignore_rate: 0,
      size_rate: 100,
      neutral_modifier: 1.0,
      equipment_atk_rate: 0,
      matk: 100,
      magic: %{
        hard_mdef: 10,
        soft_mdef: 5,
        ignore_mdef_rate: 0,
        ignore_mdef?: false,
        element_modifier: element,
        skill_ratio: 100,
        bonus_matk: 0,
        smatk: 0,
        mres: 0,
        matk_rate: 0,
        damage_multiplier: 0,
        skill_atk_rate: 0,
        skill_taken_rate: 0,
        attack: %{size: 0, race2: 0, element_target: 0, atk_ele: 0, race: 0, class: 0},
        taken: %{element: 0, size: 0, race2: 0, race: 0, class: 0, magic: 0}
      }
    }
  end
end
