defmodule Aesir.ZoneServer.Mmo.Combat.EquipAutocastTest do
  @moduledoc """
  Tests for equipment-granted autocast procs.
  """

  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.CombatTestHelper
  alias Aesir.ZoneServer.Mmo.AutospellForceFlag
  alias Aesir.ZoneServer.Mmo.Combat.BattleFlags
  alias Aesir.ZoneServer.Mmo.Combat.EquipAutocast

  @cold_bolt 14

  defp with_mods(combatant, mods), do: %{combatant | equip_modifiers: mods}

  defp always_hit(_effective), do: true
  defp never_hit(_effective), do: false

  # The default arming of `bonus3 bAutoSpell`: a weapon proc, either range,
  # normal swings and skills alike.
  defp default_flag, do: BattleFlags.fill_battle(0)

  defp entry(opts) do
    trigger = Keyword.get(opts, :trigger, :attack)
    level = Keyword.get(opts, :level, 3)
    flag = Keyword.get(opts, :flag, default_flag())
    force = Keyword.get(opts, :force, AutospellForceFlag.id(:target))

    {{:auto_cast, {trigger, @cold_bolt, level, flag, force}}, Keyword.get(opts, :rate, 1_000)}
  end

  defp melee_swing, do: BattleFlags.build(:weapon, :short, false)

  describe "on_attack/4" do
    test "a matching proc casts the armed skill at the target" do
      attacker =
        CombatTestHelper.create_player_combatant(unit_id: 1001)
        |> with_mods(Map.new([entry([])]))

      defender = CombatTestHelper.create_mob_combatant(unit_id: 2001)

      assert [{:auto_cast, @cold_bolt, 3, {:unit, 2001}}] =
               EquipAutocast.on_attack(attacker, defender, melee_swing(), roll: &always_hit/1)
    end

    test "without the target bit the proc casts on the wearer" do
      attacker =
        CombatTestHelper.create_player_combatant(unit_id: 1001)
        |> with_mods(Map.new([entry(force: AutospellForceFlag.id(:self))]))

      defender = CombatTestHelper.create_mob_combatant(unit_id: 2001)

      assert [{:auto_cast, @cold_bolt, 3, :self}] =
               EquipAutocast.on_attack(attacker, defender, melee_swing(), roll: &always_hit/1)
    end

    test "a proc armed for magic never fires on a weapon swing" do
      magic_flag = BattleFlags.fill_battle(BattleFlags.type_bit(:magic))

      attacker =
        CombatTestHelper.create_player_combatant(unit_id: 1001)
        |> with_mods(Map.new([entry(flag: magic_flag)]))

      defender = CombatTestHelper.create_mob_combatant(unit_id: 2001)

      assert [] =
               EquipAutocast.on_attack(attacker, defender, melee_swing(), roll: &always_hit/1)

      assert [_proc] =
               EquipAutocast.on_attack(
                 attacker,
                 defender,
                 BattleFlags.build(:magic, :long, true),
                 roll: &always_hit/1
               )
    end

    test "a failed roll casts nothing" do
      attacker =
        CombatTestHelper.create_player_combatant(unit_id: 1001)
        |> with_mods(Map.new([entry([])]))

      defender = CombatTestHelper.create_mob_combatant(unit_id: 2001)

      assert [] = EquipAutocast.on_attack(attacker, defender, melee_swing(), roll: &never_hit/1)
    end

    test "the roll sees the armed per-mille chance, capped" do
      parent = self()

      attacker =
        CombatTestHelper.create_player_combatant(unit_id: 1001)
        |> with_mods(Map.new([entry(rate: 4_000)]))

      defender = CombatTestHelper.create_mob_combatant(unit_id: 2001)

      roll = fn effective ->
        send(parent, {:rolled, effective})
        false
      end

      EquipAutocast.on_attack(attacker, defender, melee_swing(), roll: roll)

      assert_received {:rolled, 1_000}
    end

    test "the random-level bit rolls the cast level" do
      force = Bitwise.bor(AutospellForceFlag.id(:target), AutospellForceFlag.id(:random_level))

      attacker =
        CombatTestHelper.create_player_combatant(unit_id: 1001)
        |> with_mods(Map.new([entry(level: 10, force: force)]))

      defender = CombatTestHelper.create_mob_combatant(unit_id: 2001)

      assert [{:auto_cast, @cold_bolt, 4, _target}] =
               EquipAutocast.on_attack(attacker, defender, melee_swing(),
                 roll: &always_hit/1,
                 level_roll: fn 10 -> 4 end
               )
    end

    test "a mob attacker carries no equipment and procs nothing" do
      mob = CombatTestHelper.create_mob_combatant(unit_id: 3001)
      player = CombatTestHelper.create_player_combatant(unit_id: 1001)

      assert [] = EquipAutocast.on_attack(mob, player, melee_swing(), roll: &always_hit/1)
    end

    test "when-hit entries never fire on the attack trigger" do
      attacker =
        CombatTestHelper.create_player_combatant(unit_id: 1001)
        |> with_mods(Map.new([entry(trigger: :when_hit)]))

      defender = CombatTestHelper.create_mob_combatant(unit_id: 2001)

      assert [] = EquipAutocast.on_attack(attacker, defender, melee_swing(), roll: &always_hit/1)
    end
  end

  describe "when_hit/4" do
    test "the defender's proc targets the attacker" do
      defender =
        CombatTestHelper.create_player_combatant(unit_id: 2001)
        |> with_mods(Map.new([entry(trigger: :when_hit)]))

      attacker = CombatTestHelper.create_mob_combatant(unit_id: 1001)

      assert [{:auto_cast, @cold_bolt, 3, {:unit, 1001}}] =
               EquipAutocast.when_hit(defender, attacker, melee_swing(), roll: &always_hit/1)
    end

    test "long-range weapon damage halves the chance" do
      parent = self()

      defender =
        CombatTestHelper.create_player_combatant(unit_id: 2001)
        |> with_mods(Map.new([entry(trigger: :when_hit, rate: 600)]))

      attacker = CombatTestHelper.create_mob_combatant(unit_id: 1001)

      roll = fn effective ->
        send(parent, {:rolled, effective})
        false
      end

      EquipAutocast.when_hit(defender, attacker, BattleFlags.build(:weapon, :long, false),
        roll: roll
      )

      assert_received {:rolled, 300}

      EquipAutocast.when_hit(defender, attacker, melee_swing(), roll: roll)

      assert_received {:rolled, 600}
    end

    test "attack entries never fire on the when-hit trigger" do
      defender =
        CombatTestHelper.create_player_combatant(unit_id: 2001)
        |> with_mods(Map.new([entry(trigger: :attack)]))

      attacker = CombatTestHelper.create_mob_combatant(unit_id: 1001)

      assert [] = EquipAutocast.when_hit(defender, attacker, melee_swing(), roll: &always_hit/1)
    end
  end
end
