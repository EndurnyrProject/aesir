defmodule Aesir.ZoneServer.Mmo.Combat.OnHitEffectsTest do
  @moduledoc """
  Tests for equipment-granted on-hit status infliction.
  """

  use ExUnit.Case, async: true

  import Mimic

  alias Aesir.ZoneServer.CombatTestHelper
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
end
