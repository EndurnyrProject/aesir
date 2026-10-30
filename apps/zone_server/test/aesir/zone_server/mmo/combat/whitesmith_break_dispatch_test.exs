defmodule Aesir.ZoneServer.Mmo.Combat.WhitesmithBreakDispatchTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.TestMob
  alias Aesir.ZoneServer.CombatTestHelper
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Mmo.Combat.BattleFlags
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.EquipProcDispatch
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Mechanics
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Resistance
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.PlayerStateFixture
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Mob.Stats, as: MobStats
  alias Aesir.ZoneServer.Unit.Stats.CombatStats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_private
  setup :setup_ets_tables

  setup do
    stub(Config, :natural_break_rate, fn -> 0 end)
    stub(Resistance, :roll_success, fn _ -> true end)
    stub(Resistance, :roll_rate, fn _ -> true end)
    victim = player(301)
    :ok = UnitRegistry.register_player(victim, self())
    mob = mob(201)
    :ok = UnitRegistry.register_unit(:mob, 201, MobState, mob, self())
    target = mob(202)
    :ok = UnitRegistry.register_unit(:mob, 202, MobState, target, self())

    %{
      attacker: CombatTestHelper.create_mob_combatant(unit_id: 201),
      target: target,
      player_target: %{type: :player, id: 301, pid: self(), state: victim}
    }
  end

  test "monster_without_wearer_dispatches_meltdown", %{attacker: attacker, target: target} do
    assert :ok = meltdown(:mob, 201)
    before_ms = System.monotonic_time(:millisecond)
    seed()
    assert :ok = dispatch(attacker, %{type: :mob, id: 202, state: target})
    after_ms = System.monotonic_time(:millisecond)

    for {status, val2} <- [sc_stripweapon: 25, sc_striparmor: 40] do
      held = StatusStorage.get_status(:mob, 202, status)
      assert %{val1: 0, val2: ^val2, source_id: 201, source_type: :mob} = held
      assert held.expires_at >= before_ms + 75_000
      assert held.expires_at <= after_ms + 75_000
    end

    entries = StatusStorage.get_unit_statuses(:mob, 202)

    calculated =
      MobStats.recalculate(target, entries, Mechanics.mob_formulas().expand_calc_flags(["Vit"]))

    assert calculated.vit == target.base.vit - div(target.base.vit * 40, 100)
    source = CombatTestHelper.create_mob_combatant(unit_id: 202)
    victim = CombatTestHelper.create_mob_combatant(unit_id: 203, def: 0, soft_def: 0)

    {:ok, reduced} =
      DamageCalculator.calculate_damage(source, victim, base_damage: 100, skip_crit: true)

    Interpreter.remove_status(:mob, 202, :sc_stripweapon)

    {:ok, normal} =
      DamageCalculator.calculate_damage(source, victim, base_damage: 100, skip_crit: true)

    assert reduced.damage < normal.damage
  end

  test "summon_and_master_status_ownership_stays_separate", %{
    attacker: attacker,
    target: target,
    player_target: player_target
  } do
    master_state = player(101)
    :ok = UnitRegistry.register_player(master_state, self())

    master =
      CombatTestHelper.create_player_combatant(unit_id: 101, weapon_type: :one_handed_sword)

    master = %{master | equip_modifiers: %{break_weapon_rate: 100, break_armor_rate: 100}}
    stub(TargetResolver, :resolve_combatant, fn {:player, 101} -> {:ok, master} end)
    summon = %{attacker | proc_owner_id: 101}

    for {original?, master?} <- [{true, false}, {false, true}, {true, true}, {false, false}] do
      StatusStorage.clear_unit_statuses(:mob, 201)
      StatusStorage.clear_unit_statuses(:player, 101)
      StatusStorage.clear_unit_statuses(:mob, 202)
      if original?, do: meltdown(:mob, 201)
      if master?, do: meltdown(:player, 101)
      seed()
      assert :ok = dispatch(summon, player_target)

      if original? do
        assert_received {:"$gen_cast", {:inventory, {:break_equip, :right_hand}}}
        assert_received {:"$gen_cast", {:inventory, {:break_equip, :armor}}}
      else
        refute_received {:"$gen_cast", {:inventory, {:break_equip, _}}}
      end

      seed()
      assert :ok = dispatch(summon, %{type: :mob, id: 202, state: target})
      assert StatusStorage.has_status?(:mob, 202, :sc_stripweapon) == (original? and master?)

      if original? and master? do
        assert StatusStorage.get_status(:mob, 202, :sc_stripweapon).source_type == :player
        assert StatusStorage.get_status(:mob, 202, :sc_stripweapon).source_id == 101
      end
    end
  end

  test "connected_surviving_weapon_hits_dispatch_once", %{
    attacker: attacker,
    player_target: target
  } do
    assert :ok = meltdown(:mob, 201)

    for skill <- [nil, 5] do
      seed()
      assert :ok = dispatch(attacker, target, hit(skill_id: skill), weapon(), skill)
      assert_received {:"$gen_cast", {:inventory, {:break_equip, :right_hand}}}
      assert_received {:"$gen_cast", {:inventory, {:break_equip, :armor}}}
      refute_received {:"$gen_cast", {:inventory, {:break_equip, _}}}
    end

    for event <- [nil, hit(hit_class: :miss), hit(hit_class: :block), hit(attack_effects?: false)] do
      seed()
      assert :ok = dispatch(attacker, target, event)
      refute_received {:"$gen_cast", {:inventory, {:break_equip, _}}}
    end

    for type <- [:magic, :misc] do
      seed()
      assert :ok = dispatch(attacker, target, hit(), BattleFlags.build(type, :short, true))
      refute_received {:"$gen_cast", {:inventory, {:break_equip, _}}}
    end

    seed()
    assert :ok = dispatch(attacker, %{type: :skill_unit, id: 9}, hit())
    refute_received {:"$gen_cast", {:inventory, {:break_equip, _}}}
  end

  test "excluded_skills_retain_self_break_and_drop_target_break", %{player_target: target} do
    player = player(101)
    :ok = UnitRegistry.register_player(player, self())
    stub(Config, :natural_break_rate, fn -> 10_000 end)

    wearer =
      CombatTestHelper.create_player_combatant(unit_id: 101, weapon_type: :one_handed_sword)

    wearer = %{wearer | equip_modifiers: %{break_weapon_rate: 10_000, break_armor_rate: 10_000}}

    for id <- [337, 485] do
      assert :ok = dispatch(wearer, target, hit(skill_id: id), weapon(), id)
      assert_received {:"$gen_cast", {:inventory, {:break_equip, :right_hand}}}
      refute_received {:"$gen_cast", {:inventory, {:break_equip, _}}}
    end
  end

  test "non_player_strips_still_honor_protection_and_immunity", %{
    attacker: attacker,
    target: target
  } do
    assert :ok = meltdown(:mob, 201)
    :ok = StatusStorage.apply_status(:mob, 202, :sc_cp_weapon)
    seed()
    assert :ok = dispatch(attacker, %{type: :mob, id: 202, state: target})
    refute StatusStorage.has_status?(:mob, 202, :sc_stripweapon)
    assert StatusStorage.has_status?(:mob, 202, :sc_striparmor)

    StatusStorage.clear_unit_statuses(:mob, 202)

    boss =
      MobState.new(
        202,
        TestMob.definition(modes: [:status_immune, :knockback_immune, :detector]),
        target.spawn_ref,
        "prontera",
        10,
        10
      )

    :ok = UnitRegistry.register_unit(:mob, 202, MobState, boss, self())
    seed()
    assert :ok = dispatch(attacker, %{type: :mob, id: 202, state: boss})
    refute StatusStorage.has_status?(:mob, 202, :sc_stripweapon)
    refute StatusStorage.has_status?(:mob, 202, :sc_striparmor)
  end

  defp dispatch(attacker, target, event \\ hit(), flag \\ weapon(), skill \\ nil),
    do: EquipProcDispatch.dispatch_breaks(attacker, target, event, flag, skill)

  defp hit(overrides \\ []) do
    EquipProcDispatch.event(weapon(), 1, %{}, target_survives?: true)
    |> Map.merge(Map.new(overrides))
  end

  defp weapon, do: BattleFlags.build(:weapon, :short, false)
  defp seed, do: :rand.seed(:exsss, {102, 103, 104})

  defp meltdown(type, id),
    do: Interpreter.apply_status(type, id, :sc_meltdown, val1: 10, duration: 60_000)

  defp player(id),
    do:
      PlayerStateFixture.build(%{
        character_id: id,
        account_id: id,
        stats: %{combat_stats: %CombatStats{}, equipment: %{right_hand: 1_101}}
      })

  defp mob(id) do
    spawn = %MobSpawn{
      mob: 1_002,
      amount: 1,
      respawn_time: 5_000,
      spawn_area: %SpawnArea{x: 10, y: 10}
    }

    MobState.new(id, TestMob.definition(), spawn, "prontera", 10, 10)
  end
end
