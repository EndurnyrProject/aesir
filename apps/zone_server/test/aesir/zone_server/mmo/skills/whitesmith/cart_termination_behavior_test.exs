defmodule Aesir.ZoneServer.Mmo.Skills.Whitesmith.CartTerminationBehaviorTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.GameMode
  alias Aesir.Commons.Models.Character
  alias Aesir.TestMob
  alias Aesir.ZoneServer.CombatTestHelper
  alias Aesir.ZoneServer.Mmo.Combat.AttackValidator
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.HitCalculations
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Mmo.Skill.Caster.Player
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.Skills.Whitesmith.WsCarttermination
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.ReflectShield
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Resistance
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_private
  setup :setup_ets_tables

  setup do
    caster = player(101)
    target = player(201)
    :ok = UnitRegistry.register_player(caster, self())
    :ok = UnitRegistry.register_player(target, self())
    stub(AttackValidator, :validate, fn _, _, _ -> :ok end)
    stub(Targeting, :validate_enemy, fn _, _ -> :ok end)
    stub(HitCalculations, :calculate_hit_result, fn _, _ -> :hit end)

    stub(DamageCalculator, :calculate_damage, fn _, _, _ ->
      {:ok, %{damage: 10, is_critical: false}}
    end)

    stub(Resistance, :roll_rate, fn _ -> true end)
    %{caster: caster, target: target}
  end

  test "cart_ratio_preserves_empty_and_integer_steps" do
    assert WsCarttermination.skill_ratio(:player, 1, 0, 80_000) == 100
    assert WsCarttermination.skill_ratio(:player, 1, 1, 80_000) == 0
    assert WsCarttermination.skill_ratio(:player, 1, 149, 80_000) == 0
    assert WsCarttermination.skill_ratio(:player, 1, 150, 80_000) == 1
    assert WsCarttermination.skill_ratio(:player, 1, 80_000, 80_000) == 533
    assert WsCarttermination.skill_ratio(:player, 10, 80_000, 80_000) == 1_333
    assert WsCarttermination.skill_ratio(:player, 10, 119, 40_000) == 2
    assert WsCarttermination.skill_ratio(:player, 10, 120, 40_000) == 4
    assert WsCarttermination.skill_ratio(:non_player, 1, 0, 80_000) == 533
    assert WsCarttermination.skill_ratio(:non_player, 10, 0, 80_000) == 1_333
  end

  test "requires_boost_at_begin_only_and_keeps_costs_on_miss", %{caster: caster} do
    {:ok, definition} = Catalog.by_id(485)

    assert {:error, :skill_failed} =
             WsCarttermination.begin_attempt(caster, {:unit, 201}, 1, definition)

    :ok = StatusStorage.apply_status(:player, 101, :sc_cartboost)
    assert {:ok, ^caster} = WsCarttermination.begin_attempt(caster, {:unit, 201}, 1, definition)
    assert {:ok, prepared} = Player.cost(caster, WsCarttermination, {:unit, 201}, definition, 1)
    {paid, _} = Player.commit_primary(caster, prepared)
    assert paid.zeny == 9_400
    assert paid.stats.current_state.sp == caster.stats.current_state.sp - 15
    stub(HitCalculations, :calculate_hit_result, fn _, _ -> :miss end)
    assert {:ok, ^paid} = WsCarttermination.cast(paid, {:unit, 201}, 1, definition)
    assert StatusStorage.has_status?(:player, 101, :sc_cartboost)
    Interpreter.remove_status(:player, 101, :sc_cartboost)
    assert {:ok, ^paid} = WsCarttermination.cast(paid, {:unit, 201}, 1, definition)
  end

  test "native_stun_obeys_hit_survival_and_resistance", %{caster: caster, target: target} do
    {:ok, definition} = Catalog.by_id(485)
    before_ms = System.monotonic_time(:millisecond)
    assert {:ok, ^caster} = WsCarttermination.cast(caster, {:unit, 201}, 10, definition)
    after_ms = System.monotonic_time(:millisecond)
    held = StatusStorage.get_status(:player, 201, :sc_stun)
    # Renewal's normal stun resistance adds 500 ms to its 4,500 ms base at zero VIT.
    duration = 5_000
    assert %{val1: 10, source_type: :player, source_id: 101} = held
    assert held.expires_at >= before_ms + duration
    assert held.expires_at <= after_ms + duration
    Interpreter.remove_status(:player, 201, :sc_stun)

    stub(Resistance, :roll_rate, fn _ -> false end)
    assert {:ok, ^caster} = WsCarttermination.cast(caster, {:unit, 201}, 10, definition)
    refute StatusStorage.has_status?(:player, 201, :sc_stun)
    stub(Resistance, :roll_rate, fn _ -> flunk("ineligible native stun rolled") end)
    :ok = StatusStorage.apply_status(:player, 201, :sc_refresh)
    assert {:ok, ^caster} = WsCarttermination.cast(caster, {:unit, 201}, 10, definition)
    refute StatusStorage.has_status?(:player, 201, :sc_stun)
    Interpreter.remove_status(:player, 201, :sc_refresh)
    stub(HitCalculations, :calculate_hit_result, fn _, _ -> :miss end)
    assert {:ok, ^caster} = WsCarttermination.cast(caster, {:unit, 201}, 10, definition)
    stub(HitCalculations, :calculate_hit_result, fn _, _ -> :hit end)

    stub(DamageCalculator, :calculate_damage, fn _, _, _ ->
      {:ok, %{damage: 1_000, is_critical: false}}
    end)

    assert {:ok, ^caster} = WsCarttermination.cast(caster, {:unit, 201}, 10, definition)
    refute StatusStorage.has_status?(:player, target.character_id, :sc_stun)
  end

  test "delayed_devotion_blocks_cart_termination_stun", %{caster: caster} do
    {:ok, definition} = Catalog.by_id(485)
    crusader = player(202)
    :ok = UnitRegistry.register_player(crusader, self())
    SpatialIndex.add_player(201, 100, 100, "prontera")
    SpatialIndex.add_player(202, 101, 100, "prontera")
    link = make_ref()

    :ok =
      StatusStorage.apply_status(:player, 201, :sc_devotion,
        state: %{peer: {:player, 202}, link_id: link, range: 7}
      )

    :ok =
      StatusStorage.apply_status(:player, 202, :sc_devoted_by,
        state: %{links: %{201 => %{peer: {:player, 201}, link_id: link}}}
      )

    stub(Resistance, :roll_rate, fn _ -> flunk("delayed forwarded hit rolled native stun") end)
    assert {:ok, ^caster} = WsCarttermination.cast(caster, {:unit, 201}, 10, definition)
    refute StatusStorage.has_status?(:player, 201, :sc_stun)
    refute StatusStorage.has_status?(:player, 202, :sc_stun)
  end

  test "cart_termination_defenses_follow_mode", %{caster: caster} do
    {:ok, definition} = Catalog.by_id(485)

    for status <- [:sc_parrying, :sc_energycoat, :sc_reflectshield] do
      :ok = StatusStorage.apply_status(:player, 201, status, val1: 10)
    end

    assert {:ok, ^caster} = WsCarttermination.cast(caster, {:unit, 201}, 10, definition)
    assert StatusStorage.has_status?(:player, 201, :sc_stun)
    Interpreter.remove_status(:player, 201, :sc_stun)
    :ok = Interpreter.apply_status(:player, 201, :sc_autoguard, val1: 10)
    :rand.seed(:exsss, {1, 2, 3})
    assert {:ok, ^caster} = WsCarttermination.cast(caster, {:unit, 201}, 10, definition)

    assert StatusStorage.has_status?(:player, 201, :sc_stun) ==
             (GameMode.mode() == :pre_renewal)

    entry = %StatusEntry{type: :sc_reflectshield, val1: 10}
    hit = %{damage: 100, dmg_type: :physical, is_short: true, skill_id: 485}
    assert :ok = ReflectShield.after_damage_taken({:mob, 202}, entry, hit, %{})

    assert {:reflect, 40} =
             ReflectShield.after_damage_taken({:mob, 202}, entry, %{hit | skill_id: 5}, %{})
  end

  test "raw_monster_cast_uses_nonplayer_ratio_and_typed_stun" do
    {:ok, definition} = Catalog.by_id(485)

    spawn = %MobSpawn{
      mob: 1_002,
      amount: 1,
      respawn_time: 5_000,
      spawn_area: %SpawnArea{x: 100, y: 100}
    }

    mob = MobState.new(301, TestMob.definition(), spawn, "prontera", 100, 100)
    :ok = UnitRegistry.register_unit(:mob, 301, MobState, mob, self())
    assert :ok = WsCarttermination.mob_cast(mob, {:unit, :player, 201}, 10, definition, %{})
    assert %{source_type: :mob, source_id: 301} = StatusStorage.get_status(:player, 201, :sc_stun)
  end

  test "classic_card_exclusion_uses_real_damage_stage" do
    attacker = CombatTestHelper.create_player_combatant(unit_id: 102)
    carded = %{attacker | equip_modifiers: %{{:addrace, :brute} => 50}}

    defender =
      CombatTestHelper.create_mob_combatant(unit_id: 202, race: :brute, def: 0, soft_def: 0)

    opts = [skill_id: 485, base_damage: 1_000, skip_crit: true]
    {:ok, plain} = DamageCalculator.calculate_damage_ignoring_defense(attacker, defender, opts)
    {:ok, boosted} = DamageCalculator.calculate_damage_ignoring_defense(carded, defender, opts)

    if GameMode.mode() == :pre_renewal do
      assert boosted.damage == plain.damage
    else
      assert boosted.damage > plain.damage
    end
  end

  test "equipment_return_is_not_suppressed", %{caster: caster, target: target} do
    {:ok, definition} = Catalog.by_id(485)
    mods = %{target.stats.modifiers | equipment: %{short_weapon_damage_return: 20}}
    target = %{target | stats: %{target.stats | modifiers: mods}}
    :ok = UnitRegistry.register_player(target, self())
    :ok = StatusStorage.apply_status(:player, 201, :sc_reflectshield, val1: 10)
    assert {:ok, ^caster} = WsCarttermination.cast(caster, {:unit, 201}, 10, definition)

    assert_received {:"$gen_cast",
                     {:unit, {:apply_damage, 2, {:player, 201}, %{reflected: true}}}}
  end

  defp player(id) do
    PlayerState.new(%Character{
      id: id,
      account_id: id,
      name: "Smith#{id}",
      class: 0,
      sex: "M",
      last_map: "prontera",
      last_x: 100,
      last_y: 100,
      base_level: 50,
      hp: 1_000,
      sp: 100,
      zeny: 10_000,
      str: 1,
      agi: 1,
      vit: 0,
      int: 0,
      dex: 1,
      luk: 0
    })
  end
end
