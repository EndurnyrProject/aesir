defmodule Aesir.ZoneServer.Mmo.Combat.ClassicStatusWatkTest do
  @moduledoc """
  Where classic status weapon ATK joins a player's weapon roll.

  The attacker has STR 50 (status ATK 75) and Maximize Power on a 100 ATK
  dagger, so the roll lands on its maximum. The target has no DEF beyond the
  classic minimum soft DEF of 1.
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

  setup :set_mimic_from_context
  setup :verify_on_exit!

  setup do
    Mimic.copy(ElementModifiers)
    Mimic.copy(SizeModifiers)
    Mimic.copy(ModifierCalculator)

    stub(SizeModifiers, :get_modifier, fn _, _, _ -> 50 end)

    stub(ModifierCalculator, :get_all_modifiers, fn
      :player, _id -> %{level4_watk: 100}
      _type, _id -> %{}
    end)

    CombatTestHelper.stub_element_coefficient(fn _element, _, _, _ -> 1.0 end)
    :ok
  end

  test "Ring of Nibelungen raises a level-4 weapon's roll maximum, before the size fix" do
    # 75 + (100 + 100) * 50% - 1, against 75 + 100 * 50% - 1 for a level-3 weapon.
    assert damage(attacker(4)) == 174
    assert damage(attacker(3)) == 124
  end

  test "a left hand takes it from its own level-4 weapon, only when that weapon has ATK" do
    # 75 + (50 + 100) * 50% - 1; 75 + 50 * 50% - 1; 75 - 1.
    assert left_hand(attacker(3) |> with_left_hand(4, 50)) == 149
    assert left_hand(attacker(4) |> with_left_hand(3, 50)) == 99
    assert left_hand(attacker(4) |> with_left_hand(4, 0)) == 74
  end

  defp left_hand(attacker) do
    {:ok, %{left_components: left_components}} =
      DamageCalculator.calculate_damage(attacker, defender(), skip_crit: true)

    {:ok, %{damage: left}} =
      DamageCalculator.calculate_secondary_hand_damage(attacker, defender(),
        skip_crit: true,
        left_components: left_components
      )

    left
  end

  defp damage(attacker) do
    {:ok, %{damage: damage}} =
      DamageCalculator.calculate_damage(attacker, defender(), skip_crit: true)

    damage
  end

  defp attacker(weapon_level) do
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
      weapon_level: weapon_level,
      refine_atk: 0,
      overrefine_band: 0,
      slot: :right_hand
    }

    combat_stats = Map.put(attacker.combat_stats, :max_weapon_damage, true)
    %{attacker | right_hand: hand, combat_stats: combat_stats}
  end

  defp with_left_hand(attacker, weapon_level, base_atk) do
    left = %{
      attacker.right_hand
      | weapon_level: weapon_level,
        base_atk: base_atk,
        slot: :left_hand
    }

    %{attacker | left_hand: left}
  end

  defp defender,
    do: CombatTestHelper.create_mob_combatant(def: 0, soft_def: 0, element: {:earth, 1})
end
