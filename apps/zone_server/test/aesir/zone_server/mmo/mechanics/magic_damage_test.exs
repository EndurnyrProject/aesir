defmodule Aesir.ZoneServer.Mmo.Mechanics.MagicDamageTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Mechanics.MagicDamage
  alias Aesir.ZoneServer.Mmo.Mechanics.MagicDamage.PreRenewal
  alias Aesir.ZoneServer.Mmo.Mechanics.MagicDamage.Renewal

  test "both modes apply MDEF before the element adjustment" do
    defense = %{hard_mdef: 10, soft_mdef: 5}

    assert renewal(100, context(defense)) == 86
    assert classic(100, context(defense)) == 85
    assert renewal(100, context(Map.put(defense, :element_modifier, 2.0))) == 172
    assert classic(100, context(Map.put(defense, :element_modifier, 1.5))) == 127
  end

  test "cardfix moves around skill ratio and keeps secondary groups distinct" do
    cards = %{size: 5, race2: 0, element_target: 0, atk_ele: 0, race: 5, class: 0}
    inputs = context(%{attack: cards, skill_ratio: 200})

    assert renewal(50, inputs) == 108
    assert classic(50, inputs) == 110

    inputs = context(%{attack: %{cards | size: 0, race2: 30, element_target: 50, race: 20}})
    assert renewal(11, inputs) == 25
    assert classic(11, inputs) == 24
  end

  test "defender cardfix surrounds MDEF and compounds distinct resistance channels" do
    taken = %{element: 0, size: 0, magic_size: 0, race2: 0, race: 20, class: 0, magic: 0}
    inputs = context(%{soft_mdef: 50, taken: taken})

    assert renewal(1000, inputs) == 750
    assert classic(1000, inputs) == 760

    inputs = context(%{soft_mdef: 50, taken: %{taken | class: 30}})
    assert renewal(1000, inputs) == 510
    assert classic(1000, inputs) == 532

    inputs = context(%{hard_mdef: 10, soft_mdef: 5, taken: %{taken | race: 0, magic: 50}})
    assert renewal(100, inputs) == 40
    assert classic(100, inputs) == 43
  end

  test "the magic size resist multiplies in after the shared size resist, not summed with it" do
    taken = %{element: 0, size: 10, magic_size: 10, race2: 0, race: 0, class: 0, magic: 0}

    assert MagicDamage.defender_cardfix(1000, taken) == 810
    assert MagicDamage.defender_cardfix(1000, %{taken | size: 20, magic_size: 0}) == 800
  end

  test "skill rates retain their separate positions and flat MATK follows the ratio" do
    inputs =
      context(%{
        hard_mdef: 30,
        soft_mdef: 7,
        skill_ratio: 200,
        bonus_matk: 13,
        skill_atk_rate: 30,
        skill_taken_rate: 20
      })

    assert renewal(101, inputs) == 167
    assert classic(101, inputs) == 149

    inputs = context(%{bonus_matk: 50, damage_multiplier: 0.5})
    assert renewal(100, inputs) == 225
    assert classic(100, inputs) == 225
  end

  test "percentage ignore rounds by mode and never removes soft MDEF" do
    inputs = context(%{hard_mdef: 11, soft_mdef: 5, ignore_mdef_rate: 50})
    assert renewal(100, inputs) == 90
    assert classic(100, inputs) == 89

    for implementation <- [&renewal/2, &classic/2] do
      assert implementation.(100, %{inputs | ignore_mdef_rate: 100}) == 95
      assert implementation.(100, %{inputs | ignore_mdef_rate: 200}) == 95
      assert implementation.(100, %{inputs | ignore_mdef?: true}) == 100

      assert implementation.(100, %{inputs | ignore_mdef_rate: -20}) ==
               implementation.(100, %{inputs | ignore_mdef_rate: 0})
    end
  end

  test "Renewal traits apply around the skill stage while classic traits are inert" do
    inputs = context(%{hard_mdef: 10, soft_mdef: 5, smatk: 50, mres: 400})
    assert renewal(100, inputs) == 77
    assert classic(100, inputs) == 85
    assert renewal(100, %{inputs | ignore_mdef?: true}) == 90
    assert classic(100, %{inputs | ignore_mdef?: true}) == 100

    inputs = context(%{smatk: 50, skill_ratio: 200, bonus_matk: 50})
    assert renewal(100, inputs) == 350
    assert classic(100, inputs) == 250
  end

  test "signed card rates and mitigation boundaries keep only the pre-attribute minimum" do
    for implementation <- [&renewal/2, &classic/2] do
      inputs = context(%{})
      assert implementation.(101, %{inputs | attack: %{inputs.attack | size: -5}}) == 96
      assert implementation.(100, %{inputs | soft_mdef: 200}) == 1
      assert implementation.(100, %{inputs | element_modifier: 0}) == 0
      assert implementation.(100, %{inputs | taken: %{inputs.taken | magic: -50}}) == 100
    end

    # Renewal cards precede the pre-attribute minimum; classic cards follow it.
    inputs = context(%{})
    assert renewal(100, %{inputs | taken: %{inputs.taken | magic: 150}}) == 1
    assert classic(100, %{inputs | taken: %{inputs.taken | magic: 150}}) == 0
  end

  defp context(overrides) do
    Map.merge(
      %{
        hard_mdef: 0,
        soft_mdef: 0,
        ignore_mdef_rate: 0,
        ignore_mdef?: false,
        element_modifier: 1.0,
        skill_ratio: 100,
        bonus_matk: 0,
        smatk: 0,
        mres: 0,
        damage_multiplier: 0,
        skill_atk_rate: 0,
        skill_taken_rate: 0,
        attack: %{size: 0, race2: 0, element_target: 0, atk_ele: 0, race: 0, class: 0},
        taken: %{element: 0, size: 0, magic_size: 0, race2: 0, race: 0, class: 0, magic: 0}
      },
      overrides
    )
  end

  # The stages composed as one hit, with `element_modifier` standing in for the
  # coordinator's attribute step (default 1.0).
  defp renewal(matk, context), do: compose(Renewal, matk, context)
  defp classic(matk, context), do: compose(PreRenewal, matk, context)

  defp compose(implementation, matk, context) do
    matk
    |> implementation.pre_element(context)
    |> Kernel.*(Map.get(context, :element_modifier, 1.0))
    |> trunc()
    |> implementation.post_element(context)
  end
end
