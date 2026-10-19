defmodule Aesir.ZoneServer.Mmo.Combat.ClassicMagnumBreakTest do
  @moduledoc """
  Classic Magnum Break's fire aura on a player's physical hit: a share of the
  player's normal-attack damage, taken as fire, joins the hit after its
  attribute step.

  The attacker has STR 50 (status ATK 50 + 5^2 = 75) and Maximize Power on a
  100 ATK weapon, so every roll is the maximum: a normal attack's base is 175.
  The target has DEF 10 and the classic minimum soft DEF of 1, so 175 becomes
  175 * 90 / 100 - 1 = 156. Fire doubles against it, so the share of a plain
  normal attack is 156 * 2 * 20 / 100 = 62.
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

  @aura %{{:pseudo_element_atk, :fire} => 20}
  @bash 5
  @sand_attack 149

  setup :set_mimic_from_context
  setup :verify_on_exit!

  setup do
    Mimic.copy(ElementModifiers)
    Mimic.copy(SizeModifiers)
    Mimic.copy(ModifierCalculator)

    stub(SizeModifiers, :get_modifier, fn _, _, _ -> 100 end)

    CombatTestHelper.stub_element_coefficient(fn
      :fire, _, _, _ -> 2.0
      :holy, _, _, _ -> 0.0
      _element, _, _, _ -> 1.0
    end)

    stub_modifiers(@aura)
    :ok
  end

  test "a normal attack gains 20% of its own damage taken as fire" do
    assert damage(attacker(), []) == 156 + 62
    assert damage(attacker(), [], %{}) == 156
  end

  test "a skill's share comes from a normal attack, not from the skill" do
    # Bash 300%: 525 * 90 / 100 - 1 = 471; the share is still the normal attack's.
    assert damage(attacker(), skill_id: @bash, skill_ratio: 300) == 471 + 62
  end

  test "the share's base takes DEF even when the hit is critical" do
    assert damage(attacker(), force_crit: true) == 175 + 62
  end

  test "refine, weapon masteries, Star Crumb and spheres reach the share" do
    attacker =
      attacker()
      |> put_in([Access.key(:right_hand), Access.key(:refine_atk)], 7)
      |> update_in(
        [Access.key(:combat_stats), :physical_attack],
        &Map.merge(&1, %{mastery_atk: 4, weapon_mastery_atk: 4, star_atk: 10})
      )
      |> Map.put(:spirit_spheres, 2)

    # Hit: 156 + 7 refine + 4 mastery = 167, then + 10 Star Crumb + 2 * 3 spheres
    # after its attribute step = 183. Share base 167 doubled by fire, then the
    # same + 16 = 350, of which 20% is 70.
    assert damage(attacker, []) == 183 + 70

    # A skill passing its own sphere count replaces the spheres held, in the hit
    # (167 + 10 + 15) and in the share: (334 + 10 + 5 * 3) * 20 / 100 = 71.
    assert damage(attacker, skill_id: @bash, spirit_spheres: 5) == 192 + 71
  end

  test "an attack-card-ignoring skill takes no share" do
    assert damage(attacker(), skill_id: @sand_attack) == 156
  end

  describe "when the attribute step leaves the right hand no damage" do
    test "a single weapon takes no share" do
      assert damage(attacker(:holy), []) == 0
    end

    test "a katar's empty left hand still carries the share" do
      katar = attacker(:holy, :katar)

      # The katar's empty left hand keeps its status ATK, 75 * 90 / 100 - 1 = 66,
      # and its neutral step leaves it positive.
      assert damage(katar, []) == 62
    end

    test "a dual-wield normal attack checks the left hand's attribute-stage damage" do
      dual = with_left_hand(attacker(:holy), 50)

      assert {:ok, %{damage: 62, left_components: left}} =
               DamageCalculator.calculate_damage(dual, defender(), skip_crit: true)

      # Left: 75 + 50 = 125, * 90 / 100 - 1 = 111, neutral.
      assert left == 111

      assert {:ok, %{damage: 111}} =
               DamageCalculator.calculate_secondary_hand_damage(dual, defender(),
                 skip_crit: true,
                 left_components: left
               )
    end

    test "a dual wielder's skill checks the left hand's untouched normal-attack base" do
      dual = with_left_hand(attacker(:holy), 50)

      assert damage(dual, skill_id: @bash, skill_ratio: 300) == 62
      assert damage(attacker(:holy), skill_id: @bash, skill_ratio: 300) == 0
    end
  end

  test "a katar normal attack takes the attribute step on its empty left hand too" do
    stub(ElementModifiers, :adjust_damage, fn damage, adjustment ->
      send(self(), {:attribute_step, adjustment.attack_element})
      damage
    end)

    damage(attacker(:neutral, :katar), [], %{attack_element: :fire})

    assert_received {:attribute_step, :fire}
    assert_received {:attribute_step, :fire}
    refute_received {:attribute_step, _element}
  end

  test "a replaced-base skill's share comes from the player's normal attack" do
    opts = [skill_id: @bash, base_damage: 100, ignore_size: true]

    with_aura = damage(attacker(), opts)
    without_aura = damage(attacker(), opts, %{})

    assert with_aura - without_aura == 62
  end

  defp damage(attacker, opts, modifiers \\ @aura) do
    stub_modifiers(modifiers)

    {:ok, %{damage: damage}} =
      DamageCalculator.calculate_damage(
        attacker,
        defender(),
        Keyword.put_new(opts, :skip_crit, true)
      )

    damage
  end

  defp stub_modifiers(player_modifiers) do
    stub(ModifierCalculator, :get_battle_modifiers, fn
      :player, _id -> player_modifiers
      _type, _id -> %{}
    end)
  end

  defp attacker(element \\ :neutral, subtype \\ :dagger) do
    attacker =
      CombatTestHelper.create_player_combatant(
        str: 50,
        dex: 0,
        luk: 0,
        base_level: 0,
        weapon_type: subtype,
        weapon_element: element
      )

    hand = %WeaponHand{
      item_id: 1,
      subtype: subtype,
      element: element,
      base_atk: 100,
      weapon_level: 1,
      refine_atk: 0,
      overrefine_band: 0,
      slot: :right_hand
    }

    %{
      attacker
      | right_hand: hand,
        combat_stats: Map.put(attacker.combat_stats, :max_weapon_damage, true)
    }
  end

  defp with_left_hand(attacker, base_atk) do
    left = %{attacker.right_hand | element: :neutral, base_atk: base_atk, slot: :left_hand}
    %{attacker | left_hand: left}
  end

  defp defender,
    do: CombatTestHelper.create_mob_combatant(def: 10, soft_def: 0, element: {:earth, 1})
end
