defmodule Aesir.ZoneServer.Mmo.Combat.OnHitEffectsTest do
  @moduledoc """
  Tests for equipment-granted on-hit status infliction.
  """

  use ExUnit.Case, async: true

  import Mimic

  alias Aesir.ZoneServer.CombatTestHelper
  alias Aesir.ZoneServer.Mmo.AutoTriggerFlag
  alias Aesir.ZoneServer.Mmo.Combat.BattleFlags
  alias Aesir.ZoneServer.Mmo.Combat.OnHitEffects
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  setup :verify_on_exit!

  @landed %{damage: 100, is_critical: false}

  defp always_hit(_effective), do: true
  defp never_hit(_effective), do: false

  defp with_mods(combatant, mods), do: %{combatant | equip_modifiers: mods}

  defp record_applications do
    pid = self()

    stub(StatusInterpreter, :apply_status, fn unit_type, unit_id, sc, params ->
      send(pid, {:applied, unit_type, unit_id, sc, params})
      :ok
    end)
  end

  describe "after_hit/4 add_eff (attacker -> defender)" do
    test "fires on a landed hit, applying to the defender with the attacker as source" do
      record_applications()

      attacker =
        CombatTestHelper.create_player_combatant(unit_id: 1001)
        |> with_mods(%{{:add_eff, :sc_stun} => 500})

      defender = CombatTestHelper.create_mob_combatant(unit_id: 2001)

      assert :ok = OnHitEffects.after_hit(attacker, defender, @landed, roll: &always_hit/1)

      assert_received {:applied, :mob, 2001, :sc_stun, params}
      assert params[:caster_id] == 1001
      assert params[:source_type] == :player
      assert params[:res_eff_exempt] == true
    end

    test "a failed roll applies nothing" do
      reject(&StatusInterpreter.apply_status/4)

      attacker =
        CombatTestHelper.create_player_combatant()
        |> with_mods(%{{:add_eff, :sc_stun} => 500})

      defender = CombatTestHelper.create_mob_combatant()

      assert :ok = OnHitEffects.after_hit(attacker, defender, @landed, roll: &never_hit/1)
    end

    test "res_eff subtracts before the roll" do
      pid = self()

      stub(StatusInterpreter, :apply_status, fn _t, _id, _sc, _p -> :ok end)

      roll = fn effective ->
        send(pid, {:rolled, effective})
        true
      end

      attacker =
        CombatTestHelper.create_player_combatant()
        |> with_mods(%{{:add_eff, :sc_stun} => 500})

      defender =
        CombatTestHelper.create_mob_combatant()
        |> with_mods(%{{:res_eff, :sc_stun} => 200})

      assert :ok = OnHitEffects.after_hit(attacker, defender, @landed, roll: roll)
      assert_received {:rolled, 300}
    end

    test "rate 500 vs res 500 never attempts (floor 0, no roll)" do
      reject(&StatusInterpreter.apply_status/4)

      rolled = fn _ -> flunk("roll must not run when the effective rate floors to 0") end

      attacker =
        CombatTestHelper.create_player_combatant()
        |> with_mods(%{{:add_eff, :sc_stun} => 500})

      defender =
        CombatTestHelper.create_mob_combatant()
        |> with_mods(%{{:res_eff, :sc_stun} => 500})

      assert :ok = OnHitEffects.after_hit(attacker, defender, @landed, roll: rolled)
    end
  end

  describe "after_hit/4 add_eff_when_hit (defender -> attacker)" do
    test "targets the attacker with the defender as source" do
      record_applications()

      attacker = CombatTestHelper.create_player_combatant(unit_id: 1001)

      defender =
        CombatTestHelper.create_mob_combatant(unit_id: 2001)
        |> with_mods(%{{:add_eff_when_hit, :sc_freeze} => 400})

      assert :ok = OnHitEffects.after_hit(attacker, defender, @landed, roll: &always_hit/1)

      assert_received {:applied, :player, 1001, :sc_freeze, params}
      assert params[:caster_id] == 2001
      assert params[:source_type] == :mob
    end

    test "subtracts the attacker's res_eff symmetrically" do
      pid = self()
      stub(StatusInterpreter, :apply_status, fn _t, _id, _sc, _p -> :ok end)

      roll = fn effective ->
        send(pid, {:rolled, effective})
        true
      end

      attacker =
        CombatTestHelper.create_player_combatant()
        |> with_mods(%{{:res_eff, :sc_freeze} => 150})

      defender =
        CombatTestHelper.create_mob_combatant()
        |> with_mods(%{{:add_eff_when_hit, :sc_freeze} => 400})

      assert :ok = OnHitEffects.after_hit(attacker, defender, @landed, roll: roll)
      assert_received {:rolled, 250}
    end
  end

  describe "after_hit/4 add_eff2 (attacker -> attacker)" do
    test "targets the attacker with the attacker as source" do
      record_applications()

      attacker =
        CombatTestHelper.create_player_combatant(unit_id: 1001)
        |> with_mods(%{{:add_eff2, :sc_curse} => 500})

      defender = CombatTestHelper.create_mob_combatant(unit_id: 2001)

      assert :ok = OnHitEffects.after_hit(attacker, defender, @landed, roll: &always_hit/1)

      assert_received {:applied, :player, 1001, :sc_curse, params}
      assert params[:caster_id] == 1001
      assert params[:source_type] == :player
    end

    test "a failed roll applies nothing" do
      reject(&StatusInterpreter.apply_status/4)

      attacker =
        CombatTestHelper.create_player_combatant()
        |> with_mods(%{{:add_eff2, :sc_curse} => 500})

      defender = CombatTestHelper.create_mob_combatant()

      assert :ok = OnHitEffects.after_hit(attacker, defender, @landed, roll: &never_hit/1)
    end
  end

  describe "after_hit/4 gates" do
    test "a zero-damage hit rolls nothing" do
      reject(&StatusInterpreter.apply_status/4)

      attacker =
        CombatTestHelper.create_player_combatant()
        |> with_mods(%{{:add_eff, :sc_stun} => 10_000})

      defender = CombatTestHelper.create_mob_combatant()

      assert :ok = OnHitEffects.after_hit(attacker, defender, %{damage: 0}, roll: &always_hit/1)
    end

    test "a skill-unit defender is skipped" do
      reject(&StatusInterpreter.apply_status/4)

      attacker =
        CombatTestHelper.create_player_combatant()
        |> with_mods(%{{:add_eff, :sc_stun} => 10_000})

      defender = %{CombatTestHelper.create_mob_combatant() | unit_type: :skill_unit}

      assert :ok = OnHitEffects.after_hit(attacker, defender, @landed, roll: &always_hit/1)
    end

    test "boss immunity flows through without crashing the attack" do
      pid = self()

      stub(StatusInterpreter, :apply_status, fn unit_type, unit_id, sc, params ->
        send(pid, {:applied, unit_type, unit_id, sc, params})
        {:error, :boss_immune}
      end)

      attacker =
        CombatTestHelper.create_player_combatant(unit_id: 1001)
        |> with_mods(%{{:add_eff, :sc_stun} => 10_000})

      defender = CombatTestHelper.create_boss_mob(unit_id: 2999)

      assert :ok = OnHitEffects.after_hit(attacker, defender, @landed, roll: &always_hit/1)
      assert_received {:applied, :mob, 2999, :sc_stun, _params}
    end
  end

  describe "after_hit/4 add_eff_on_skill" do
    test "inflicts only when the named skill landed the hit" do
      record_applications()

      attacker =
        CombatTestHelper.create_player_combatant(unit_id: 1001)
        |> with_mods(%{{:add_eff_on_skill, 110, :sc_stun} => 10_000})

      defender = CombatTestHelper.create_mob_combatant(unit_id: 2001)

      assert :ok =
               OnHitEffects.after_hit(attacker, defender, @landed,
                 roll: &always_hit/1,
                 skill_id: 110
               )

      assert_received {:applied, :mob, 2001, :sc_stun, _params}

      assert :ok =
               OnHitEffects.after_hit(attacker, defender, @landed,
                 roll: &always_hit/1,
                 skill_id: 111
               )

      refute_received {:applied, _type, _id, _sc, _params}
    end

    test "a normal attack carries no skill and inflicts nothing" do
      record_applications()

      attacker =
        CombatTestHelper.create_player_combatant(unit_id: 1001)
        |> with_mods(%{{:add_eff_on_skill, 110, :sc_stun} => 10_000})

      defender = CombatTestHelper.create_mob_combatant(unit_id: 2001)

      assert :ok = OnHitEffects.after_hit(attacker, defender, @landed, roll: &always_hit/1)

      refute_received {:applied, _type, _id, _sc, _params}
    end

    test "the victim's tolerance subtracts from the proc rate" do
      pid = self()
      stub(StatusInterpreter, :apply_status, fn _t, _i, _sc, _p -> :ok end)

      attacker =
        CombatTestHelper.create_player_combatant(unit_id: 1001)
        |> with_mods(%{{:add_eff_on_skill, 110, :sc_stun} => 3_000})

      defender =
        CombatTestHelper.create_mob_combatant(unit_id: 2001)
        |> with_mods(%{{:res_eff, :sc_stun} => 1_000})

      roll = fn effective ->
        send(pid, {:rolled, effective})
        false
      end

      assert :ok = OnHitEffects.after_hit(attacker, defender, @landed, roll: roll, skill_id: 110)

      assert_received {:rolled, 2_000}
    end
  end

  describe "after_hit/4 trigger-flagged bonuses" do
    defp trigger_flag(names) do
      names
      |> Enum.reduce(0, &Bitwise.bor(AutoTriggerFlag.id(&1), &2))
      |> BattleFlags.fill_trigger()
    end

    test "a flagged bonus only rolls on an attack its flag matches" do
      record_applications()

      attacker =
        CombatTestHelper.create_player_combatant(unit_id: 1001)
        |> with_mods(%{{:add_eff, {:sc_stun, trigger_flag([:magic])}} => 10_000})

      defender = CombatTestHelper.create_mob_combatant(unit_id: 2001)

      assert :ok =
               OnHitEffects.after_hit(attacker, defender, @landed,
                 roll: &always_hit/1,
                 attack_flag: BattleFlags.build(:weapon, :short, false)
               )

      refute_received {:applied, _type, _id, _sc, _params}

      assert :ok =
               OnHitEffects.after_hit(attacker, defender, @landed,
                 roll: &always_hit/1,
                 attack_flag: BattleFlags.build(:magic, :long, true)
               )

      assert_received {:applied, :mob, 2001, :sc_stun, _params}
    end

    test "passes a positive bonus4 duration override to the status interpreter" do
      record_applications()
      flag = trigger_flag([:target])

      attacker =
        CombatTestHelper.create_player_combatant(unit_id: 1001)
        |> with_mods(%{
          {:add_eff, {:sc_stun, flag}} => 10_000,
          {:add_eff_duration, {:sc_stun, flag}} => 5_000
        })

      defender = CombatTestHelper.create_mob_combatant(unit_id: 2001)

      assert :ok =
               OnHitEffects.after_hit(attacker, defender, @landed,
                 roll: &always_hit/1,
                 attack_flag: BattleFlags.build(:weapon, :short, false)
               )

      assert_received {:applied, :mob, 2001, :sc_stun, params}
      assert params[:duration] == 5_000
    end

    test "zero duration keeps the status definition default" do
      record_applications()
      flag = trigger_flag([:target])

      attacker =
        CombatTestHelper.create_player_combatant(unit_id: 1001)
        |> with_mods(%{
          {:add_eff, {:sc_stun, flag}} => 10_000,
          {:add_eff_duration, {:sc_stun, flag}} => 0
        })

      defender = CombatTestHelper.create_mob_combatant(unit_id: 2001)

      assert :ok =
               OnHitEffects.after_hit(attacker, defender, @landed,
                 roll: &always_hit/1,
                 attack_flag: BattleFlags.build(:weapon, :short, false)
               )

      assert_received {:applied, :mob, 2001, :sc_stun, params}
      refute Keyword.has_key?(params, :duration)
    end

    test "the self bit inflicts on the wearer instead of the victim" do
      record_applications()

      attacker =
        CombatTestHelper.create_player_combatant(unit_id: 1001)
        |> with_mods(%{{:add_eff, {:sc_stun, trigger_flag([:self])}} => 10_000})

      defender = CombatTestHelper.create_mob_combatant(unit_id: 2001)

      assert :ok =
               OnHitEffects.after_hit(attacker, defender, @landed,
                 roll: &always_hit/1,
                 attack_flag: BattleFlags.build(:weapon, :short, false)
               )

      assert_received {:applied, :player, 1001, :sc_stun, _params}
      refute_received {:applied, :mob, 2001, :sc_stun, _params}
    end

    test "naming both victims inflicts on each once" do
      record_applications()

      attacker =
        CombatTestHelper.create_player_combatant(unit_id: 1001)
        |> with_mods(%{{:add_eff, {:sc_stun, trigger_flag([:self, :target])}} => 10_000})

      defender = CombatTestHelper.create_mob_combatant(unit_id: 2001)

      assert :ok =
               OnHitEffects.after_hit(attacker, defender, @landed,
                 roll: &always_hit/1,
                 attack_flag: BattleFlags.build(:weapon, :short, false)
               )

      assert_received {:applied, :mob, 2001, :sc_stun, _params}
      assert_received {:applied, :player, 1001, :sc_stun, _params}
      refute_received {:applied, _type, _id, :sc_stun, _params}
    end

    test "a flagged when-hit bonus targets the attacker" do
      record_applications()

      attacker = CombatTestHelper.create_player_combatant(unit_id: 1001)

      defender =
        CombatTestHelper.create_player_combatant(unit_id: 2001)
        |> with_mods(%{{:add_eff_when_hit, {:sc_blind, trigger_flag([:target])}} => 10_000})

      assert :ok =
               OnHitEffects.after_hit(attacker, defender, @landed,
                 roll: &always_hit/1,
                 attack_flag: BattleFlags.build(:weapon, :short, false)
               )

      assert_received {:applied, :player, 1001, :sc_blind, _params}
    end

    test "a failed roll inflicts nothing" do
      record_applications()

      attacker =
        CombatTestHelper.create_player_combatant(unit_id: 1001)
        |> with_mods(%{{:add_eff, {:sc_stun, trigger_flag([:target])}} => 10_000})

      defender = CombatTestHelper.create_mob_combatant(unit_id: 2001)

      assert :ok =
               OnHitEffects.after_hit(attacker, defender, @landed,
                 roll: &never_hit/1,
                 attack_flag: BattleFlags.build(:weapon, :short, false)
               )

      refute_received {:applied, _type, _id, _sc, _params}
    end

    test "the victim's tolerance still subtracts from a flagged proc rate" do
      pid = self()

      stub(StatusInterpreter, :apply_status, fn _type, _id, _sc, _params -> :ok end)

      attacker =
        CombatTestHelper.create_player_combatant(unit_id: 1001)
        |> with_mods(%{{:add_eff, {:sc_stun, trigger_flag([:target])}} => 3_000})

      defender =
        CombatTestHelper.create_mob_combatant(unit_id: 2001)
        |> with_mods(%{{:res_eff, :sc_stun} => 1_000})

      roll = fn effective ->
        send(pid, {:rolled, effective})
        false
      end

      assert :ok =
               OnHitEffects.after_hit(attacker, defender, @landed,
                 roll: roll,
                 attack_flag: BattleFlags.build(:weapon, :short, false)
               )

      assert_received {:rolled, 2_000}
    end
  end
end
