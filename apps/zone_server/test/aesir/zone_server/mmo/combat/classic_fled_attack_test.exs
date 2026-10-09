defmodule Aesir.ZoneServer.Mmo.Combat.ClassicFledAttackTest do
  @moduledoc """
  What a weapon attack still deals after the target flees it.

  A fled classic attack skips its hit block but still runs everything after
  it on zero damage: Star Crumb, spirit spheres, Envenom, the Magnum Break
  share, Weapon Research, Hilt Binding and the cards. Renewal keeps those
  bonuses inside the hit block.
  """

  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.CombatTestHelper
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.ElementModifiers
  alias Aesir.ZoneServer.Mmo.Combat.SizeModifiers
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Unit.Player.WeaponHand

  @cart_revolution 153
  @envenom 52
  @investigate 266

  setup :set_mimic_from_context
  setup :verify_on_exit!

  setup do
    Mimic.copy(ElementModifiers)
    Mimic.copy(SizeModifiers)
    Mimic.copy(ModifierCalculator)

    stub(SizeModifiers, :get_modifier, fn _, _, _ -> 100 end)
    stub(ModifierCalculator, :get_all_modifiers, fn _type, _id -> %{} end)

    CombatTestHelper.stub_element_coefficient(fn
      :poison, _, _, _ -> 2.0
      :fire, _, _, _ -> 2.0
      _element, _, _, _ -> 1.0
    end)

    :ok
  end

  describe "classic" do
    @describetag game_mode: :pre_renewal

    test "Star Crumb, spirit spheres, Weapon Research and Hilt Binding still deal damage" do
      attacker = masteries_attacker()
      carded = %{attacker | equip_modifiers: %{{:addrace, :all} => 100}}

      # 10 Star Crumb + 2 * 3 spheres, then + 10 research + 4 Hilt Binding.
      assert fled(attacker) == 30
      assert fled(carded) == 60
    end

    test "a fled attack without those bonuses deals nothing" do
      assert fled(attacker(%{})) == 0
    end

    test "Cart Revolution takes no Hilt Binding; a mastery-exempt skill no Star Crumb or spheres" do
      attacker = masteries_attacker()

      assert fled(attacker, skill_id: @cart_revolution) == 26
      assert fled(attacker, skill_id: @investigate) == 14
    end

    test "Envenom's flat ATK takes the attribute step, for any attacker" do
      opts = [skill_id: @envenom, element: :poison, envenom_atk: 150]

      # (10 Star Crumb + 150) doubled by poison.
      assert fled(attacker(%{star_atk: 10}), opts) == 320
      assert fled(CombatTestHelper.create_mob_combatant(), opts) == 300
    end

    test "the Magnum Break share's base is the Star Crumb and sphere bonus alone" do
      stub(ModifierCalculator, :get_all_modifiers, fn _type, _id ->
        %{{:pseudo_element_atk, :fire} => 20}
      end)

      attacker = attacker(%{star_atk: 10}) |> Map.put(:spirit_spheres, 2)

      # 16, plus 20% of (0 taken as fire + 10 + 6).
      assert fled(attacker) == 19
    end

    test "a dual wielder's left hand keeps its own Star Crumb and the spheres" do
      attacker =
        %{star_atk: 10, left_star_atk: 20}
        |> attacker()
        |> Map.put(:spirit_spheres, 2)
        |> with_left_hand()

      assert {:ok, %{damage: 16, left_components: 26}} =
               DamageCalculator.calculate_fled_damage(attacker, defender(), [])

      assert {:ok, %{damage: 26}} =
               DamageCalculator.calculate_secondary_hand_damage(attacker, defender(),
                 skip_crit: true,
                 left_components: 26
               )
    end
  end

  @tag game_mode: :renewal
  test "a fled renewal attack deals nothing" do
    assert fled(masteries_attacker()) == 0
  end

  defp fled(attacker, opts \\ []) do
    {:ok, %{damage: damage, is_critical: false}} =
      DamageCalculator.calculate_fled_damage(attacker, defender(), opts)

    damage
  end

  defp masteries_attacker do
    %{star_atk: 10, weapon_research_atk: 10, hilt_binding_atk: 4}
    |> attacker()
    |> Map.put(:spirit_spheres, 2)
  end

  defp attacker(snapshot) do
    attacker = CombatTestHelper.create_player_combatant(weapon_type: :dagger)

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

    combat_stats = Map.update!(attacker.combat_stats, :physical_attack, &Map.merge(&1, snapshot))
    %{attacker | right_hand: hand, combat_stats: combat_stats}
  end

  defp with_left_hand(attacker) do
    %{attacker | left_hand: %{attacker.right_hand | base_atk: 50, slot: :left_hand}}
  end

  defp defender,
    do: CombatTestHelper.create_mob_combatant(def: 10, soft_def: 0, element: {:earth, 1})
end
