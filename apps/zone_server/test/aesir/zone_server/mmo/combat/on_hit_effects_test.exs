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

  @landed %{hit_class: :hit, attack_effects?: true, counter_effects?: true}
  @weapon_short BattleFlags.build(:weapon, :short, false)

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

      assert :ok =
               OnHitEffects.after_hit(attacker, defender, @landed,
                 roll: &always_hit/1,
                 attack_flag: @weapon_short
               )

      assert_received {:applied, :mob, 2001, :sc_stun, params}
      assert params[:caster_id] == 1001
      assert params[:source_type] == :player
      assert params[:success_rate] == 5.0
    end

    test "forwards the per-10000 rate and the roll to the status defense" do
      record_applications()

      attacker =
        CombatTestHelper.create_player_combatant()
        |> with_mods(%{{:add_eff, :sc_stun} => 500})

      defender = CombatTestHelper.create_mob_combatant()

      assert :ok =
               OnHitEffects.after_hit(attacker, defender, @landed,
                 roll: &never_hit/1,
                 attack_flag: @weapon_short
               )

      assert_received {:applied, :mob, _id, :sc_stun, params}
      assert params[:success_rate] == 5.0
      refute params[:resistance_roll].(500)
    end

    test "leaves the victim's res_eff to the status defense" do
      record_applications()
      roll = fn _rate -> flunk("the status defense makes the only roll") end

      attacker =
        CombatTestHelper.create_player_combatant()
        |> with_mods(%{{:add_eff, :sc_stun} => 500})

      defender =
        CombatTestHelper.create_mob_combatant()
        |> with_mods(%{{:res_eff, :sc_stun} => 500})

      assert :ok =
               OnHitEffects.after_hit(attacker, defender, @landed,
                 roll: roll,
                 attack_flag: @weapon_short
               )

      assert_received {:applied, :mob, _id, :sc_stun, params}
      assert params[:success_rate] == 5.0
    end

    test "a zero rate never reaches the status system" do
      reject(&StatusInterpreter.apply_status/4)

      attacker =
        CombatTestHelper.create_player_combatant()
        |> with_mods(%{{:add_eff, :sc_stun} => 0})

      defender = CombatTestHelper.create_mob_combatant()

      assert :ok = OnHitEffects.after_hit(attacker, defender, @landed, roll: &always_hit/1)
    end
  end

  describe "after_hit/4 add_eff_when_hit (defender -> attacker)" do
    test "targets the attacker with the attacker as source" do
      record_applications()

      attacker = CombatTestHelper.create_mob_combatant(unit_id: 1001)

      defender =
        CombatTestHelper.create_player_combatant(unit_id: 2001)
        |> with_mods(%{{:add_eff_when_hit, :sc_freeze} => 400})

      assert :ok =
               OnHitEffects.after_hit(attacker, defender, @landed,
                 roll: &always_hit/1,
                 attack_flag: @weapon_short
               )

      assert_received {:applied, :mob, 1001, :sc_freeze, params}
      assert params[:caster_id] == 1001
      assert params[:source_type] == :mob
    end

    test "forwards the when-hit rate unreduced by the attacker's res_eff" do
      record_applications()

      attacker =
        CombatTestHelper.create_player_combatant(unit_id: 1001)
        |> with_mods(%{{:res_eff, :sc_freeze} => 150})

      defender =
        CombatTestHelper.create_player_combatant(unit_id: 2001)
        |> with_mods(%{{:add_eff_when_hit, :sc_freeze} => 400})

      assert :ok =
               OnHitEffects.after_hit(attacker, defender, @landed,
                 roll: &always_hit/1,
                 attack_flag: @weapon_short
               )

      assert_received {:applied, :player, 1001, :sc_freeze, params}
      assert params[:success_rate] == 4.0
    end
  end

  describe "after_hit/4 add_eff2 (attacker -> attacker)" do
    test "targets the attacker with the attacker as source" do
      record_applications()

      attacker =
        CombatTestHelper.create_player_combatant(unit_id: 1001)
        |> with_mods(%{{:add_eff2, :sc_curse} => 500})

      defender = CombatTestHelper.create_mob_combatant(unit_id: 2001)

      assert :ok =
               OnHitEffects.after_hit(attacker, defender, @landed,
                 roll: &always_hit/1,
                 attack_flag: @weapon_short
               )

      assert_received {:applied, :player, 1001, :sc_curse, params}
      assert params[:caster_id] == 1001
      assert params[:source_type] == :player
    end

    test "forwards its rate and roll to the status defense" do
      record_applications()

      attacker =
        CombatTestHelper.create_player_combatant(unit_id: 1001)
        |> with_mods(%{{:add_eff2, :sc_curse} => 500})

      defender = CombatTestHelper.create_mob_combatant()

      assert :ok =
               OnHitEffects.after_hit(attacker, defender, @landed,
                 roll: &never_hit/1,
                 attack_flag: @weapon_short
               )

      assert_received {:applied, :player, 1001, :sc_curse, params}
      assert params[:success_rate] == 5.0
      refute params[:resistance_roll].(500)
    end
  end

  describe "after_hit/4 gates" do
    test "a miss rolls nothing" do
      reject(&StatusInterpreter.apply_status/4)

      attacker =
        CombatTestHelper.create_player_combatant()
        |> with_mods(%{{:add_eff, :sc_stun} => 10_000})

      defender =
        CombatTestHelper.create_mob_combatant()
        |> with_mods(%{{:add_eff_when_hit, :sc_freeze} => 10_000})

      miss = %{hit_class: :miss, attack_effects?: true, counter_effects?: false}
      assert :ok = OnHitEffects.after_hit(attacker, defender, miss, roll: &always_hit/1)
    end

    test "a blocked hit rolls the attacker's bAddEff but no when-hit or race proc" do
      record_applications()

      attacker =
        CombatTestHelper.create_player_combatant(unit_id: 1001)
        |> with_mods(%{
          {:add_eff, :sc_stun} => 10_000,
          {:def_set_race_rate, :player_human} => 10_000,
          {:def_set_race_duration, :player_human} => 5_000
        })

      defender =
        %{CombatTestHelper.create_player_combatant(unit_id: 2001) | race: :player_human}
        |> with_mods(%{{:add_eff_when_hit, :sc_freeze} => 10_000})

      block = %{hit_class: :block, attack_effects?: true, counter_effects?: false}

      assert :ok =
               OnHitEffects.after_hit(attacker, defender, block,
                 roll: &always_hit/1,
                 attack_flag: BattleFlags.build(:weapon, :short, false)
               )

      assert_received {:applied, :player, 2001, :sc_stun, _params}
      refute_received {:applied, _type, _id, _sc, _params}
    end

    test "a target the hit killed takes no bAddEff, while the when-hit stage still rolls" do
      record_applications()

      attacker =
        CombatTestHelper.create_player_combatant(unit_id: 1001)
        |> with_mods(%{{:add_eff, :sc_stun} => 10_000})

      defender =
        CombatTestHelper.create_player_combatant(unit_id: 2001)
        |> with_mods(%{{:add_eff_when_hit, :sc_freeze} => 10_000})

      killed = %{hit_class: :hit, attack_effects?: false, counter_effects?: true}

      assert :ok =
               OnHitEffects.after_hit(attacker, defender, killed,
                 roll: &always_hit/1,
                 attack_flag: @weapon_short
               )

      assert_received {:applied, :player, 1001, :sc_freeze, _params}
      refute_received {:applied, :player, 2001, :sc_stun, _params}
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

      assert :ok =
               OnHitEffects.after_hit(attacker, defender, @landed,
                 roll: &always_hit/1,
                 attack_flag: @weapon_short
               )

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

    test "forwards the proc rate unreduced by the victim's tolerance" do
      record_applications()

      attacker =
        CombatTestHelper.create_player_combatant(unit_id: 1001)
        |> with_mods(%{{:add_eff_on_skill, 110, :sc_stun} => 3_000})

      defender =
        CombatTestHelper.create_mob_combatant(unit_id: 2001)
        |> with_mods(%{{:res_eff, :sc_stun} => 1_000})

      assert :ok =
               OnHitEffects.after_hit(attacker, defender, @landed,
                 roll: &never_hit/1,
                 skill_id: 110
               )

      assert_received {:applied, :mob, 2001, :sc_stun, params}
      assert params[:success_rate] == 30.0
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

    test "a flagged proc forwards its rate and roll, unreduced by the victim's tolerance" do
      record_applications()

      attacker =
        CombatTestHelper.create_player_combatant(unit_id: 1001)
        |> with_mods(%{{:add_eff, {:sc_stun, trigger_flag([:target])}} => 3_000})

      defender =
        CombatTestHelper.create_mob_combatant(unit_id: 2001)
        |> with_mods(%{{:res_eff, :sc_stun} => 1_000})

      assert :ok =
               OnHitEffects.after_hit(attacker, defender, @landed,
                 roll: &never_hit/1,
                 attack_flag: BattleFlags.build(:weapon, :short, false)
               )

      assert_received {:applied, :mob, 2001, :sc_stun, params}
      assert params[:success_rate] == 30.0
      refute params[:resistance_roll].(3_000)
    end
  end

  describe "after_hit/4 defender-status procs" do
    test "a matching normal weapon hit applies DEF and MDEF replacements to a player" do
      record_applications()

      attacker =
        CombatTestHelper.create_player_combatant(unit_id: 1001)
        |> with_mods(%{
          {:def_set_race_rate, :player_human} => 10_000,
          {:def_set_race_duration, :player_human} => 5_000,
          {:def_set_race_value, :player_human} => 1,
          {:mdef_set_race_rate, :player_human} => 10_000,
          {:mdef_set_race_duration, :player_human} => 4_000,
          {:mdef_set_race_value, :player_human} => 2
        })

      defender = %{
        CombatTestHelper.create_player_combatant(unit_id: 2001)
        | race: :player_human
      }

      assert :ok =
               OnHitEffects.after_hit(attacker, defender, @landed,
                 roll: &always_hit/1,
                 attack_flag: BattleFlags.build(:weapon, :short, false)
               )

      assert_received {:applied, :player, 2001, :sc_defset, def_params}
      assert def_params[:duration] == 5_000
      assert def_params[:val1] == 1

      assert_received {:applied, :player, 2001, :sc_mdefset, mdef_params}
      assert mdef_params[:duration] == 4_000
      assert mdef_params[:val1] == 2
    end

    test "defender procs reject skills, magic and non-player victims" do
      reject(&StatusInterpreter.apply_status/4)

      attacker =
        CombatTestHelper.create_player_combatant()
        |> with_mods(%{
          {:def_set_race_rate, :player_human} => 10_000,
          {:def_set_race_duration, :player_human} => 5_000,
          {:def_set_race_value, :player_human} => 1
        })

      player = %{CombatTestHelper.create_player_combatant() | race: :player_human}
      mob = %{CombatTestHelper.create_mob_combatant() | race: :player_human}

      assert :ok =
               OnHitEffects.after_hit(attacker, player, @landed,
                 roll: &always_hit/1,
                 attack_flag: BattleFlags.build(:weapon, :short, true)
               )

      assert :ok =
               OnHitEffects.after_hit(attacker, player, @landed,
                 roll: &always_hit/1,
                 attack_flag: BattleFlags.build(:magic, :long, true)
               )

      assert :ok =
               OnHitEffects.after_hit(attacker, mob, @landed,
                 roll: &always_hit/1,
                 attack_flag: BattleFlags.build(:weapon, :short, false)
               )
    end

    test "no-recover forwards its rate, roll and duration to the status defense" do
      record_applications()

      attacker =
        CombatTestHelper.create_player_combatant(unit_id: 1001)
        |> with_mods(%{
          {:no_recover_race_rate, :player_human} => 10_000,
          {:no_recover_race_duration, :player_human} => 10_000
        })

      defender =
        %{CombatTestHelper.create_player_combatant(unit_id: 2001, luk: 10) | race: :player_human}
        |> with_mods(%{:luk => 2, {:res_eff, :sc_norecover_state} => 2_000})

      assert :ok =
               OnHitEffects.after_hit(attacker, defender, @landed,
                 roll: &always_hit/1,
                 attack_flag: BattleFlags.build(:weapon, :long, false)
               )

      assert_received {:applied, :player, 2001, :sc_norecover_state, params}
      assert params[:success_rate] == 100.0
      assert params[:duration] == 10_000
      assert params[:resistance_roll].(10_000)
      refute Keyword.has_key?(params, :val1)
    end
  end

  describe "pc_bonus_addeff reading" do
    @magic_long BattleFlags.build(:magic, :long, true)
    @weapon_long BattleFlags.build(:weapon, :long, true)

    defp mob_target, do: CombatTestHelper.create_mob_combatant(unit_id: 2001)

    defp player_with(mods),
      do: CombatTestHelper.create_player_combatant(unit_id: 1001) |> with_mods(mods)

    test "an unflagged bAddEff is a weapon proc: it never rolls on a magic hit" do
      record_applications()
      attacker = player_with(%{{:add_eff, :sc_stun} => 10_000})

      OnHitEffects.after_hit(attacker, mob_target(), @landed, attack_flag: @magic_long)
      refute_received {:applied, _type, _id, _sc, _params}
    end

    test "entries of one status and one flag roll once at their summed rate, at level 7" do
      record_applications()
      weapon_target = Bitwise.bor(AutoTriggerFlag.id(:weapon), AutoTriggerFlag.id(:target))

      attacker =
        player_with(%{
          {:add_eff, :sc_stun} => 300,
          {:add_eff, {:sc_stun, BattleFlags.fill_trigger(weapon_target)}} => 200
        })

      OnHitEffects.after_hit(attacker, mob_target(), @landed,
        roll: &always_hit/1,
        attack_flag: @weapon_short
      )

      assert_received {:applied, :mob, 2001, :sc_stun, params}
      assert params[:success_rate] == 5.0
      assert params[:val1] == 7
      refute_received {:applied, _type, _id, _sc, _params}
    end

    test "the ammunition's chance counts only for a ranged attack" do
      record_applications()
      attacker = player_with(%{{:arrow_add_eff, :sc_stun} => 400, {:add_eff, :sc_stun} => 100})

      OnHitEffects.after_hit(attacker, mob_target(), @landed, attack_flag: @weapon_short)
      assert_received {:applied, :mob, 2001, :sc_stun, short}
      assert short[:success_rate] == 1.0

      OnHitEffects.after_hit(attacker, mob_target(), @landed, attack_flag: @weapon_long)
      assert_received {:applied, :mob, 2001, :sc_stun, long}
      assert long[:success_rate] == 5.0
    end

    test "Cart Termination rolls no bAddEff but its own bAddEffOnSkill" do
      record_applications()

      attacker =
        player_with(%{
          {:add_eff, :sc_stun} => 10_000,
          {:add_eff_on_skill, 485, :sc_bleeding} => 500
        })

      OnHitEffects.after_hit(attacker, mob_target(), @landed,
        attack_flag: BattleFlags.build(:weapon, :short, true),
        skill_id: 485
      )

      assert_received {:applied, :mob, 2001, :sc_bleeding, _params}
      refute_received {:applied, _type, _id, _sc, _params}
    end

    @tag game_mode: :pre_renewal
    test "classic Soul Breaker rolls no bAddEff" do
      record_applications()
      attacker = player_with(%{{:add_eff, :sc_stun} => 10_000})

      OnHitEffects.after_hit(attacker, mob_target(), @landed,
        attack_flag: BattleFlags.build(:weapon, :long, true),
        skill_id: 379
      )

      refute_received {:applied, _type, _id, _sc, _params}
    end
  end

  describe "counter stage" do
    test "a monster's when-hit entries roll nothing" do
      reject(&StatusInterpreter.apply_status/4)

      attacker = CombatTestHelper.create_player_combatant(unit_id: 1001)

      defender =
        CombatTestHelper.create_mob_combatant(unit_id: 2001)
        |> with_mods(%{{:add_eff_when_hit, :sc_freeze} => 10_000})

      OnHitEffects.after_hit(attacker, defender, @landed, attack_flag: @weapon_short)
    end

    test "a when-hit enemy entry spares a wearer that hit itself; its self entry lands" do
      record_applications()
      self_target = Bitwise.bor(AutoTriggerFlag.id(:self), AutoTriggerFlag.id(:weapon))

      wearer =
        CombatTestHelper.create_player_combatant(unit_id: 1001)
        |> with_mods(%{
          {:add_eff_when_hit, :sc_freeze} => 10_000,
          {:add_eff_when_hit, {:sc_curse, BattleFlags.fill_trigger(self_target)}} => 10_000
        })

      OnHitEffects.after_hit(wearer, wearer, @landed,
        roll: &always_hit/1,
        attack_flag: @weapon_short
      )

      assert_received {:applied, :player, 1001, :sc_curse, params}
      assert params[:caster_id] == 1001
      refute_received {:applied, _type, _id, :sc_freeze, _params}
    end
  end

  describe "direct/5" do
    test "a no-damage misc effect rolls a misc proc that names both ranges" do
      record_applications()
      misc_target = Bitwise.bor(AutoTriggerFlag.id(:misc), AutoTriggerFlag.id(:target))
      misc_short = Bitwise.bor(misc_target, AutoTriggerFlag.id(:short))

      attacker =
        player_with(%{
          {:add_eff, {:sc_blind, BattleFlags.fill_trigger(misc_target)}} => 10_000,
          {:add_eff, {:sc_stun, BattleFlags.fill_trigger(misc_short)}} => 10_000
        })

      OnHitEffects.direct(attacker, {:mob, 2001}, BattleFlags.type_bit(:misc), 119,
        roll: &always_hit/1
      )

      assert_received {:applied, :mob, 2001, :sc_blind, _params}
      refute_received {:applied, _type, _id, :sc_stun, _params}
    end

    test "a monster attacker rolls nothing" do
      reject(&StatusInterpreter.apply_status/4)
      mob = CombatTestHelper.create_mob_combatant(unit_id: 3001)

      OnHitEffects.direct(mob, {:player, 1001}, BattleFlags.type_bit(:misc), 119)
    end
  end
end
