defmodule Aesir.ZoneServer.Mmo.Combat.EquipVanishTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.CombatTestHelper
  alias Aesir.ZoneServer.Mmo.Combat.BattleFlags
  alias Aesir.ZoneServer.Mmo.Combat.EquipVanish

  defp with_modifiers(combatant, modifiers), do: %{combatant | equip_modifiers: modifiers}

  describe "after_hit/5" do
    test "rolls matching category entries and delivers summed percentages" do
      weapon_flag = BattleFlags.build(:weapon, :short, false)
      magic_flag = BattleFlags.build(:magic, :long, true)

      attacker =
        CombatTestHelper.create_player_combatant(unit_id: 1001)
        |> with_modifiers(%{
          {:hp_vanish_rate, weapon_flag} => 500,
          {:hp_vanish_percent, weapon_flag} => 4,
          {:sp_vanish_rate, weapon_flag} => 1_000,
          {:sp_vanish_percent, weapon_flag} => 7,
          {:sp_vanish_rate, magic_flag} => 1_000,
          {:sp_vanish_percent, magic_flag} => 99
        })

      target = CombatTestHelper.create_player_combatant(unit_id: 2001)
      roll = fn rate -> rate == 500 end

      assert :ok = EquipVanish.after_hit(attacker, target, self(), weapon_flag, roll: roll)

      assert_receive {:"$gen_cast", {:unit, {:apply_vanish, 4, 7, {:player, 1001}}}}
    end

    test "a mismatched or failed entry delivers nothing" do
      weapon_flag = BattleFlags.build(:weapon, :short, false)
      magic_flag = BattleFlags.build(:magic, :long, true)

      attacker =
        CombatTestHelper.create_player_combatant()
        |> with_modifiers(%{
          {:sp_vanish_rate, magic_flag} => 1_000,
          {:sp_vanish_percent, magic_flag} => 10,
          {:hp_vanish_rate, weapon_flag} => 500,
          {:hp_vanish_percent, weapon_flag} => 5
        })

      target = CombatTestHelper.create_player_combatant()

      assert :ok =
               EquipVanish.after_hit(attacker, target, self(), weapon_flag,
                 roll: fn _ -> false end
               )

      refute_receive {:"$gen_cast", _message}
    end
  end

  describe "normal_attack_override/3" do
    test "combines the exact and all-race HP values before SP" do
      attacker =
        CombatTestHelper.create_player_combatant()
        |> with_modifiers(%{
          {:hp_vanish_race_rate, :player_human} => 600,
          {:hp_vanish_race_rate, :all} => 400,
          {:hp_vanish_race_percent, :player_human} => 8,
          {:hp_vanish_race_percent, :all} => 2,
          {:sp_vanish_race_rate, :player_human} => 1_000,
          {:sp_vanish_race_percent, :player_human} => 50
        })

      target = %{
        CombatTestHelper.create_player_combatant()
        | race: :player_human,
          max_hp: 2_000,
          max_sp: 500
      }

      assert EquipVanish.normal_attack_override(attacker, target) == {:hp, 200}
    end

    test "tries SP when the HP chance fails" do
      attacker =
        CombatTestHelper.create_player_combatant()
        |> with_modifiers(%{
          {:hp_vanish_race_rate, :player_human} => 500,
          {:hp_vanish_race_percent, :player_human} => 10,
          {:sp_vanish_race_rate, :player_human} => 1_000,
          {:sp_vanish_race_percent, :player_human} => 20
        })

      target = %{
        CombatTestHelper.create_player_combatant()
        | race: :player_human,
          max_hp: 2_000,
          max_sp: 500
      }

      assert EquipVanish.normal_attack_override(attacker, target, roll: fn _ -> false end) ==
               {:sp, 100}
    end

    test "returns none without a matching race entry" do
      attacker = CombatTestHelper.create_player_combatant()
      target = %{CombatTestHelper.create_mob_combatant(race: :demon) | max_hp: 1_000, max_sp: 100}

      assert EquipVanish.normal_attack_override(attacker, target) == :none
    end
  end
end
