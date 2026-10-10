defmodule Aesir.ZoneServer.Mmo.Combat.RenewalMasteryAtkTest do
  @moduledoc """
  What a renewal player's mastery ATK holds, per hand. The target has no DEF, so
  every mastery contribution reaches the damage unchanged.
  """

  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.CombatTestHelper
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.ElementModifiers
  alias Aesir.ZoneServer.Mmo.Combat.SizeModifiers
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Unit.Player.WeaponHand

  @moduletag game_mode: :renewal

  @cart_revolution 153
  @combo_finish 273
  @investigate 266

  setup :set_mimic_from_context
  setup :verify_on_exit!

  setup do
    Mimic.copy(ElementModifiers)
    Mimic.copy(SizeModifiers)
    Mimic.copy(ModifierCalculator)

    stub(SizeModifiers, :get_modifier, fn _, _, _ -> 100 end)
    stub(ModifierCalculator, :get_all_modifiers, fn _type, _id -> %{} end)
    CombatTestHelper.stub_element_coefficient(fn _element, _, _, _ -> 1.0 end)
    :ok
  end

  test "a normal attack adds 3 per spirit sphere held" do
    bare = damage(attacker(%{}), [])

    assert damage(attacker(%{}) |> Map.put(:spirit_spheres, 2), []) == bare + 6
  end

  test "a sphere-spending skill counts the spheres it leaves" do
    bare = damage(attacker(%{}), skill_id: @combo_finish)
    holding = attacker(%{}) |> Map.put(:spirit_spheres, 3)

    assert damage(holding, skill_id: @combo_finish, spirit_spheres: 1) == bare + 3
  end

  test "weapon masteries, Hilt Binding and Star Crumb join the right hand" do
    bare = damage(attacker(%{}), [])
    masteries = attacker(%{weapon_mastery_atk: 4, hilt_binding_atk: 4, star_atk: 10})

    assert damage(masteries, []) == bare + 18
  end

  test "Cart Revolution takes no Hilt Binding" do
    bare = damage(attacker(%{}), skill_id: @cart_revolution)
    hilt = attacker(%{hilt_binding_atk: 4, star_atk: 10})

    assert damage(hilt, skill_id: @cart_revolution) == bare + 10
  end

  test "a mastery-exempt skill takes none of the mastery block" do
    masteries =
      %{weapon_mastery_atk: 4, hilt_binding_atk: 4, star_atk: 10}
      |> attacker()
      |> Map.put(:spirit_spheres, 2)

    assert damage(masteries, skill_id: @investigate) ==
             damage(attacker(%{}), skill_id: @investigate)
  end

  test "a dual wielder's left hand takes its own masteries and Star Crumb" do
    bare = attacker(%{}) |> with_left_hand(50)

    dual =
      %{weapon_mastery_atk: 4, left_weapon_mastery_atk: 6, star_atk: 10, left_star_atk: 20}
      |> attacker()
      |> with_left_hand(50)
      |> Map.put(:spirit_spheres, 1)

    assert hands(dual).right == hands(bare).right + 4 + 10 + 3
    assert hands(dual).left == hands(bare).left + 6 + 20 + 3
  end

  test "a status counted as a mastery (Ring of Nibelungen) joins both hands" do
    bare = attacker(%{}) |> with_left_hand(50)
    bare_hands = hands(bare)
    bare_investigate = damage(bare, skill_id: @investigate)

    stub(ModifierCalculator, :get_all_modifiers, fn
      :player, _id -> %{mastery_atk: 7}
      _type, _id -> %{}
    end)

    assert hands(bare) == %{right: bare_hands.right + 7, left: bare_hands.left + 7}
    assert damage(bare, skill_id: @investigate) == bare_investigate
  end

  defp hands(attacker) do
    {:ok, %{damage: right, left_components: left_components}} =
      DamageCalculator.calculate_damage(attacker, defender(), skip_crit: true)

    {:ok, %{damage: left}} =
      DamageCalculator.calculate_secondary_hand_damage(attacker, defender(),
        skip_crit: true,
        left_components: left_components
      )

    %{right: right, left: left}
  end

  defp damage(attacker, opts) do
    {:ok, %{damage: damage}} =
      DamageCalculator.calculate_damage(attacker, defender(), Keyword.put(opts, :skip_crit, true))

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
      |> Map.update!(:physical_attack, &Map.merge(&1, snapshot))

    %{attacker | right_hand: hand, combat_stats: combat_stats}
  end

  defp with_left_hand(attacker, base_atk) do
    left = %{attacker.right_hand | element: :neutral, base_atk: base_atk, slot: :left_hand}
    %{attacker | left_hand: left}
  end

  defp defender,
    do: CombatTestHelper.create_mob_combatant(def: 0, soft_def: 0, element: {:earth, 1})
end
