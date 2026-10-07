defmodule Aesir.ZoneServer.Mmo.Combat.CriticalTest do
  use ExUnit.Case, async: false

  alias Aesir.ZoneServer.CombatTestHelper
  alias Aesir.ZoneServer.Mmo.Combat.Critical
  alias Aesir.ZoneServer.Mmo.StatusStorage

  setup do
    on_exit(fn ->
      StatusStorage.clear_unit_statuses(:mob, 2001)
      StatusStorage.clear_unit_statuses(:player, 1001)
    end)
  end

  defp player(critical_rate, opts \\ []) do
    attacker = CombatTestHelper.create_player_combatant(opts)
    %{attacker | combat_stats: Map.put(attacker.combat_stats, :critical_rate, critical_rate)}
  end

  defp mob(opts \\ []), do: CombatTestHelper.create_mob_combatant(opts)

  describe "chance/3" do
    test "a player's chance loses twice the target's LUK" do
      assert Critical.chance(player(300), mob(luk: 20), []) == 300 - 40
    end

    test "units outside the critical-capable types never crit" do
      attacker = %{mob() | combat_stats: Map.put(mob().combat_stats, :critical_rate, 500)}
      defender = CombatTestHelper.create_player_combatant(luk: 1)

      assert Critical.chance(attacker, defender, []) == 0
    end

    test "a sleeping target doubles the chance before the skill's bonus is added" do
      StatusStorage.apply_status(:mob, 2001, :sc_sleep, val1: 1)

      assert Critical.chance(player(300), mob(luk: 20), skill_bonus: 200) == (300 - 40) * 2 + 200
    end

    test "adds the per-race and all-race equipment bonus in tenths" do
      modifiers = %{{:critical_add_race, :brute} => 5, {:critical_add_race, :all} => 2}
      attacker = %{player(300) | equip_modifiers: modifiers}

      assert Critical.chance(attacker, mob(luk: 0), []) == 300 + 70
    end

    test "a normal arrow attack adds the ammunition and long-range critical bonuses" do
      modifiers = %{arrow_critical: 20, critical_long: 3}
      attacker = %{player(300, weapon_type: :bow) | equip_modifiers: modifiers}

      assert Critical.chance(attacker, mob(luk: 0), normal_attack: true) == 300 + 200 + 30
      assert Critical.chance(attacker, mob(luk: 0), []) == 300
    end

    test "a melee normal attack takes no ranged critical bonus" do
      attacker = %{player(300) | equip_modifiers: %{arrow_critical: 20, critical_long: 3}}

      assert Critical.chance(attacker, mob(luk: 0), normal_attack: true) == 300
    end

    test "a mercenary attacking a player loses three times its LUK" do
      attacker = %{player(300) | unit_type: :mercenary}
      defender = CombatTestHelper.create_player_combatant(unit_id: 1002, luk: 10)

      assert Critical.chance(attacker, defender, []) == 300 - 30
    end

    test "a player without critical rate never crits whatever its bonuses" do
      attacker = %{player(0) | equip_modifiers: %{{:critical_add_race, :all} => 50}}

      assert Critical.chance(attacker, mob(luk: 0), skill_bonus: 300) == 0
    end
  end

  describe "normal_attack?/3" do
    test "rolls the chance: certain at 1000, never at zero or below" do
      assert Critical.normal_attack?(player(1_040), mob(luk: 20), [])
      refute Critical.normal_attack?(player(40), mob(luk: 20), [])
    end

    test "a Double Attack swing never crits" do
      refute Critical.normal_attack?(player(2_000), mob(luk: 0), multi_hit: true)
    end

    test "a holder of Auto Counter crits for certain and ends the stance" do
      StatusStorage.apply_status(:player, 1001, :sc_auto_counter, val1: 5)

      assert Critical.normal_attack?(player(10), mob(luk: 90), [])
      refute StatusStorage.has_status?(:player, 1001, :sc_auto_counter)
    end

    test "Auto Counter is kept when the swing cannot crit" do
      StatusStorage.apply_status(:player, 1001, :sc_auto_counter, val1: 5)

      refute Critical.normal_attack?(player(500), mob(luk: 0), multi_hit: true)
      refute Critical.normal_attack?(player(0), mob(luk: 0), [])
      assert StatusStorage.has_status?(:player, 1001, :sc_auto_counter)
    end

    test "non-players never crit" do
      defender = CombatTestHelper.create_player_combatant(luk: 0)
      attacker = %{mob() | combat_stats: Map.put(mob().combat_stats, :critical_rate, 2_000)}

      refute Critical.normal_attack?(attacker, defender, [])
    end
  end

  describe "roll?/3" do
    test "rolls the chance with the skill's bonus" do
      assert Critical.roll?(player(10), mob(luk: 0), skill_bonus: 990)
      refute Critical.roll?(player(10), mob(luk: 5), skill_bonus: 0)
    end
  end

  describe "multiply/2" do
    test "multiplies in single precision and floors" do
      assert Critical.multiply(45, 0) == 63
      assert Critical.multiply(300, 3) == 428
      assert Critical.multiply(5_000, 3) == 7_149
    end
  end
end
