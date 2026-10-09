defmodule Aesir.ZoneServer.Mmo.Combat.ClassicMasteryStagesTest do
  @moduledoc """
  Where each classic player mastery bonus joins a weapon hit.

  The attacker has STR 50 (status ATK 50 + 5^2 = 75) and Maximize Power on a
  100 ATK dagger, so a normal attack's base is 175. The target has DEF 10 and
  the classic minimum soft DEF of 1: 175 * 90 / 100 - 1 = 156.
  """

  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.CombatTestHelper
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.ElementModifiers
  alias Aesir.ZoneServer.Mmo.Combat.SizeModifiers
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Unit.Player.WeaponHand

  @moduletag game_mode: :pre_renewal

  @cart_revolution 153
  @envenom 52
  @investigate 266
  @sacrifice 368
  @spiral_pierce 397

  setup :set_mimic_from_context
  setup :verify_on_exit!

  setup do
    Mimic.copy(ElementModifiers)
    Mimic.copy(SizeModifiers)
    Mimic.copy(ModifierCalculator)

    stub(SizeModifiers, :get_modifier, fn _, _, _ -> 100 end)
    stub(ModifierCalculator, :get_all_modifiers, fn _type, _id -> %{} end)
    element_coefficient(1.0)
    :ok
  end

  test "Star Crumb and spirit spheres join after the attribute step" do
    element_coefficient(0.5)
    attacker = attacker(%{star_atk: 10}) |> Map.put(:spirit_spheres, 2)

    # 156 halved = 78, then + 10 Star Crumb + 2 * 3 spheres.
    assert damage(attacker, []) == 94
  end

  test "Weapon Research and Hilt Binding join after the 0 cap and take the attacker's cards" do
    element_coefficient(0.0)
    attacker = attacker(%{weapon_research_atk: 10, hilt_binding_atk: 4})
    carded = %{attacker | equip_modifiers: %{{:addrace, :all} => 100}}

    assert damage(attacker, []) == 14
    assert damage(carded, []) == 28
    # Cart Revolution takes no Hilt Binding.
    assert damage(carded, skill_id: @cart_revolution) == 20
  end

  test "a mastery-exempt skill keeps only Weapon Research and Hilt Binding" do
    attacker =
      %{weapon_mastery_atk: 4, star_atk: 10, weapon_research_atk: 10}
      |> attacker()
      |> put_in([Access.key(:right_hand), Access.key(:refine_atk)], 7)
      |> Map.put(:spirit_spheres, 2)

    # 156 + 7 refine + 4 mastery, + 10 Star Crumb + 6 spheres, + 10 research.
    assert damage(attacker, []) == 193
    # Investigate takes no refine, mastery, Star Crumb or sphere bonus.
    assert damage(attacker, skill_id: @investigate) == 166
  end

  test "a dual wielder's left hand takes its own masteries and Star Crumb" do
    attacker =
      %{weapon_mastery_atk: 4, left_weapon_mastery_atk: 6, star_atk: 10, left_star_atk: 20}
      |> attacker()
      |> with_left_hand(50)

    # Right: 156 + 4 + 10. Left: (75 + 50) * 90 / 100 - 1 = 111, + 6, + 20.
    assert {:ok, %{damage: 170, left_components: 137}} =
             DamageCalculator.calculate_damage(attacker, defender(), skip_crit: true)

    assert {:ok, %{damage: 137}} =
             DamageCalculator.calculate_secondary_hand_damage(attacker, defender(),
               skip_crit: true,
               left_components: 137
             )
  end

  test "Envenom's second attribute step also covers the Star Crumb bonus" do
    CombatTestHelper.stub_element_coefficient(fn
      :poison, _, _, _ -> 2.0
      _element, _, _, _ -> 1.0
    end)

    attacker = attacker(%{star_atk: 10})

    # 156 doubled = 312, + 10 Star Crumb + 150 Envenom = 472, doubled again.
    assert damage(attacker, skill_id: @envenom, element: :poison, envenom_atk: 150) == 944
  end

  describe "a replaced-base player hit" do
    setup do
      element_coefficient(0.5)
      attacker = attacker(%{weapon_mastery_atk: 4, star_atk: 10, weapon_research_atk: 10})
      %{attacker: %{attacker | equip_modifiers: %{{:addrace, :all} => 100}}}
    end

    test "Spiral Pierce adds refine after DEF and Star Crumb before its cards", %{
      attacker: attacker
    } do
      opts = [skill_id: @spiral_pierce, base_damage: 100, refine_atk: 7]

      # 100 + 7 refine = 107, halved 53, + 10 Star Crumb + 10 research, doubled.
      assert ignoring_defense(attacker, opts) == 146
    end

    test "Sacrifice keeps only Weapon Research before its cards", %{attacker: attacker} do
      opts = [skill_id: @sacrifice, base_damage: 100, refine_atk: 7]

      # 100 halved = 50, + 10 research, doubled.
      assert ignoring_defense(attacker, opts) == 120
    end

    defp ignoring_defense(attacker, opts) do
      {:ok, %{damage: damage}} =
        DamageCalculator.calculate_damage_ignoring_defense(
          attacker,
          defender(),
          [skip_crit: true] ++ opts
        )

      damage
    end
  end

  defp with_left_hand(attacker, base_atk) do
    left = %{attacker.right_hand | element: :neutral, base_atk: base_atk, slot: :left_hand}
    %{attacker | left_hand: left}
  end

  defp element_coefficient(coefficient) do
    CombatTestHelper.stub_element_coefficient(fn _element, _, _, _ -> coefficient end)
  end

  defp damage(attacker, opts, defender \\ defender()) do
    {:ok, %{damage: damage}} =
      DamageCalculator.calculate_damage(
        attacker,
        defender,
        Keyword.put_new(opts, :skip_crit, true)
      )

    damage
  end

  defp attacker(snapshot) do
    attacker =
      CombatTestHelper.create_player_combatant(
        str: 50,
        dex: 0,
        luk: 0,
        base_level: 0,
        weapon_type: :dagger,
        weapon_element: :neutral
      )

    hand = %WeaponHand{
      item_id: 1,
      subtype: :dagger,
      element: :neutral,
      base_atk: 100,
      weapon_level: 1,
      refine_atk: 0,
      overrefine_band: 0,
      slot: :right_hand
    }

    combat_stats =
      attacker.combat_stats
      |> Map.put(:max_weapon_damage, true)
      |> Map.update!(:physical_attack, &Map.merge(&1, legacy_mastery(snapshot)))

    %{attacker | right_hand: hand, combat_stats: combat_stats}
  end

  # The legacy `mastery_atk` is every passive ATK plus the right Star Crumb.
  defp legacy_mastery(snapshot) do
    legacy =
      Map.get(snapshot, :weapon_mastery_atk, 0) + Map.get(snapshot, :star_atk, 0) +
        Map.get(snapshot, :weapon_research_atk, 0) + Map.get(snapshot, :hilt_binding_atk, 0)

    Map.put(snapshot, :mastery_atk, legacy)
  end

  defp defender,
    do: CombatTestHelper.create_mob_combatant(def: 10, soft_def: 0, element: {:earth, 1})
end
