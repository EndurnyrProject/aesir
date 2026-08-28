defmodule Aesir.ZoneServer.Mmo.CombatSkillUnitTest do
  @moduledoc """
  Tests `Combat.apply_skill_unit_damage/7`: the magic ground skill-unit hit path
  used by Storm Gust. Damage must come from `MagicDamageCalculator` (real
  MATK/MDEF/element), not a precomputed integer.
  """

  use ExUnit.Case, async: true
  import Mimic

  @moduletag :capture_log

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.Combat.EquipComa
  alias Aesir.ZoneServer.Mmo.Combat.MagicDamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Cell, as: SkillUnitCell
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.PlayerStateFixture
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  @caster_id 1000
  @target_id 2001
  @map_name "prontera"

  setup do
    Mimic.copy(Combat)
    Mimic.copy(EquipComa)
    Mimic.copy(ModifierCalculator)
    stub(ModifierCalculator, :get_all_modifiers, fn _, _ -> %{} end)
    :ok
  end

  defp caster(matk) do
    %Combatant{
      unit_id: @caster_id,
      unit_type: :player,
      base_stats: %{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
      combat_stats: %{
        atk: 1,
        def: 1,
        hit: 1,
        flee: 1,
        perfect_dodge: 1,
        matk: matk,
        mdef: 0,
        soft_mdef: 0
      },
      progression: %{base_level: 1, job_level: 1},
      element: {:neutral, 1},
      race: :player_human,
      size: :medium,
      weapon: %{type: :fist, element: :neutral, size: :medium},
      attack_range: 1,
      attack_delay_ms: 500
    }
  end

  defp build_mob_state(hard_mdef) do
    mob_definition = %MobDefinition{
      id: 1002,
      aegis_name: "TEST_MOB",
      name: "TestMob",
      level: 1,
      hp: 100,
      sp: 50,
      base_exp: 10,
      job_exp: 5,
      atk: 10,
      matk: 0,
      def: 5,
      mdef: hard_mdef,
      stats: %{str: 10, agi: 10, vit: 10, int: 0, dex: 10, luk: 5},
      attack_range: 1,
      skill_range: 10,
      chase_range: 12,
      element: {:water, 1},
      race: :formless,
      size: :medium,
      walk_speed: 200,
      attack_delay: 1000,
      attack_motion: 500,
      client_attack_motion: 500,
      damage_motion: 400,
      ai_type: 0,
      modes: [],
      drops: []
    }

    %MobState{
      instance_id: @target_id,
      mob_id: 1002,
      mob_data: mob_definition,
      spawn_ref: %MobSpawn{
        mob: 1002,
        amount: 1,
        respawn_time: 5_000,
        spawn_area: %MobSpawn.SpawnArea{x: 150, y: 150, xs: 0, ys: 0}
      },
      x: 150,
      y: 150,
      map_name: @map_name,
      hp: 100,
      max_hp: 100,
      sp: 50,
      max_sp: 50,
      spawned_at: System.system_time(:second),
      aggro_list: %{}
    }
  end

  test "player-owned ground damage marks eligible recipient for coma" do
    test_pid = self()
    mob_state = build_mob_state(0)
    attacker = caster(100)

    stub(UnitRegistry, :get_unit, fn :mob, @target_id ->
      {:ok, {MobState, mob_state, test_pid}}
    end)

    stub(SpatialIndex, :get_unit_position, fn :mob, @target_id ->
      {:ok, {150, 150, @map_name}}
    end)

    expect(MagicDamageCalculator, :calculate_magic_damage, fn ^attacker, _target, _opts ->
      {:ok, %{damage: 40, is_critical: false}}
    end)

    expect(EquipComa, :trigger?, fn ^attacker, target ->
      assert target.unit_type == :mob
      true
    end)

    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)
    reject(&MobSession.apply_damage/3)
    expect(MobSession, :apply_coma, fn ^test_pid, {:player, @caster_id} -> :ok end)

    assert :ok =
             Combat.apply_skill_unit_damage(attacker, :mob, @target_id, 89, 10, :water, 600)
  end

  test "zero ground damage never decides or delivers coma" do
    test_pid = self()
    mob_state = build_mob_state(0)
    attacker = caster(100)

    stub(UnitRegistry, :get_unit, fn :mob, @target_id ->
      {:ok, {MobState, mob_state, test_pid}}
    end)

    stub(SpatialIndex, :get_unit_position, fn :mob, @target_id ->
      {:ok, {150, 150, @map_name}}
    end)

    expect(MagicDamageCalculator, :calculate_magic_damage, fn ^attacker, _target, _opts ->
      {:ok, %{damage: 0, is_critical: false}}
    end)

    reject(&EquipComa.trigger?/2)

    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, packet ->
      assert packet.damage == 0
      :ok
    end)

    expect(MobSession, :apply_damage, fn ^test_pid, 0, @caster_id -> :ok end)
    reject(&MobSession.apply_coma/2)

    assert :ok =
             Combat.apply_skill_unit_damage(attacker, :mob, @target_id, 89, 10, :water, 600)
  end

  test "final 1-point fixed ground magic participates in coma" do
    test_pid = self()
    mob_state = build_mob_state(0)
    mob_state = %{mob_state | mob_data: %{mob_state.mob_data | element: {:poison, 1}}}
    attacker = caster(100)

    stub(UnitRegistry, :get_unit, fn :mob, @target_id ->
      {:ok, {MobState, mob_state, test_pid}}
    end)

    stub(SpatialIndex, :get_unit_position, fn :mob, @target_id ->
      {:ok, {150, 150, @map_name}}
    end)

    reject(&MagicDamageCalculator.calculate_magic_damage/3)
    expect(EquipComa, :trigger?, fn ^attacker, _target -> true end)

    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, packet ->
      assert packet.damage == 1
      :ok
    end)

    reject(&MobSession.apply_damage/3)
    expect(MobSession, :apply_coma, fn ^test_pid, {:player, @caster_id} -> :ok end)

    assert :ok =
             Combat.apply_skill_unit_damage(attacker, :mob, @target_id, 89, 10, :poison, 0,
               fixed_damage: 100
             )
  end

  test "player-owned ground damage reaches player and Homunculus owners" do
    attacker = caster(100)
    player_id = @target_id
    homunculus_id = @target_id + 1
    test_pid = self()

    player =
      PlayerStateFixture.build(%{
        character_id: player_id,
        account_id: player_id,
        map_name: @map_name,
        x: 150,
        y: 150,
        stats: %{}
      })

    owner =
      spawn(fn ->
        receive do
          {:"$gen_cast", message} -> send(test_pid, {:owner_cast, message})
        end
      end)

    homunculus = %HomunculusState{
      id: 1,
      owner_character_id: 3_000,
      owner_session_pid: owner,
      class_id: 6_001,
      name: "Lif",
      lifecycle: :active,
      action_state: :idle,
      hp: 100,
      max_hp: 100,
      sp: 50,
      max_sp: 50,
      world_gid: homunculus_id,
      map_name: @map_name,
      x: 151,
      y: 150
    }

    stub(TargetResolver, :resolve, fn
      :player, ^player_id -> {:ok, self(), player, :player}
      :homunculus, ^homunculus_id -> {:ok, owner, homunculus, :homunculus}
    end)

    stub(SpatialIndex, :get_unit_position, fn
      :player, ^player_id -> {:ok, {150, 150, @map_name}}
      :homunculus, ^homunculus_id -> {:ok, {151, 150, @map_name}}
    end)

    expect(MagicDamageCalculator, :calculate_magic_damage, 2, fn ^attacker, target, _opts ->
      assert target.unit_type in [:player, :homunculus]
      {:ok, %{damage: 40, is_critical: false}}
    end)

    expect(EquipComa, :trigger?, 2, fn ^attacker, target ->
      assert target.unit_type in [:player, :homunculus]
      true
    end)

    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)
    reject(&PlayerSession.apply_damage/3)
    expect(PlayerSession, :apply_coma, fn _pid, {:player, @caster_id} -> :ok end)

    assert :ok =
             Combat.apply_skill_unit_damage(attacker, :player, player_id, 89, 10, :water, 600)

    assert :ok =
             Combat.apply_skill_unit_damage(
               attacker,
               :homunculus,
               homunculus_id,
               89,
               10,
               :water,
               600
             )

    assert_received {:owner_cast,
                     {:homunculus, {:apply_coma, ^homunculus_id, {:player, @caster_id}}}}
  end

  test "mob and Homunculus ground attackers cannot source player equipment coma" do
    target = build_mob_state(0)
    test_pid = self()

    attackers =
      for {unit_type, unit_id} <- [mob: 3_001, homunculus: 3_002] do
        %{caster(100) | unit_type: unit_type, unit_id: unit_id}
      end

    stub(UnitRegistry, :get_unit, fn :mob, @target_id ->
      {:ok, {MobState, target, test_pid}}
    end)

    stub(SpatialIndex, :get_unit_position, fn :mob, @target_id ->
      {:ok, {150, 150, @map_name}}
    end)

    expect(MagicDamageCalculator, :calculate_magic_damage, 2, fn attacker, _target, _opts ->
      assert attacker.unit_type in [:mob, :homunculus]
      {:ok, %{damage: 40, is_critical: false}}
    end)

    expect(EquipComa, :trigger?, 2, fn attacker, _target ->
      assert attacker.unit_type in [:mob, :homunculus]
      false
    end)

    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)
    reject(&MobSession.apply_coma/2)

    stub(MobSession, :apply_damage, fn ^test_pid, 40, source ->
      send(test_pid, {:ordinary_damage, source})
      :ok
    end)

    Enum.each(attackers, fn attacker ->
      assert :ok =
               Combat.apply_skill_unit_damage(attacker, :mob, @target_id, 89, 10, :water, 600)
    end)

    assert_received {:ordinary_damage, 3_001}
    assert_received {:ordinary_damage, {:homunculus, 3_002}}
  end

  test "targetable skill-unit recipients remain ineligible for coma" do
    test_pid = self()
    attacker = caster(100)

    {:ok, cell} =
      SkillUnitCell.new(%{
        cell_id: @target_id,
        group_id: 1,
        map_name: @map_name,
        x: 150,
        y: 150,
        hp: 100,
        max_hp: 100,
        flags: [:targetable]
      })

    manager =
      spawn(fn ->
        receive do
          {:"$gen_call", from, {:damage_targetable_cell, @target_id, 40, {:player, @caster_id}}} ->
            send(test_pid, :skill_unit_damaged)
            GenServer.reply(from, {:ok, cell})
        end
      end)

    stub(TargetResolver, :resolve, fn :skill_unit, @target_id ->
      {:ok, manager, cell, :skill_unit}
    end)

    stub(SpatialIndex, :get_unit_position, fn :skill_unit, @target_id ->
      {:ok, {150, 150, @map_name}}
    end)

    expect(MagicDamageCalculator, :calculate_magic_damage, fn ^attacker, _target, _opts ->
      {:ok, %{damage: 40, is_critical: false}}
    end)

    expect(EquipComa, :trigger?, fn ^attacker, target ->
      assert target.unit_type == :skill_unit
      false
    end)

    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)

    assert :ok =
             Combat.apply_skill_unit_damage(
               attacker,
               :skill_unit,
               @target_id,
               89,
               10,
               :water,
               600
             )

    assert_received :skill_unit_damaged
  end

  test "computes magic damage from MATK/MDEF/element, broadcasts, and applies it" do
    test_pid = self()
    mob_state = build_mob_state(10)

    stub(UnitRegistry, :get_unit, fn :mob, @target_id ->
      {:ok, {MobState, mob_state, test_pid}}
    end)

    stub(SpatialIndex, :get_unit_position, fn :mob, @target_id ->
      {:ok, {150, 150, @map_name}}
    end)

    stub(Broadcast, :to_in_range, fn @map_name, 150, 150, _range, packet ->
      send(test_pid, {:broadcast, packet.damage, packet.skill_id, packet.src_id})
      :ok
    end)

    stub(MobSession, :apply_damage, fn ^test_pid, damage, @caster_id ->
      send(test_pid, {:damage, damage})
      :ok
    end)

    # MATK 100, water vs water (resist) modifier, hard 10 / soft 5.
    assert :ok =
             Combat.apply_skill_unit_damage(caster(100), :mob, @target_id, 89, 10, :water, 600)

    assert_received {:broadcast, damage, 89, @caster_id}
    assert_received {:damage, ^damage}
    assert damage > 0
  end

  test "preserves total damage while reporting requested skill-unit hit divisions" do
    test_pid = self()
    mob_state = build_mob_state(10)

    stub(UnitRegistry, :get_unit, fn :mob, @target_id ->
      {:ok, {MobState, mob_state, test_pid}}
    end)

    stub(SpatialIndex, :get_unit_position, fn :mob, @target_id ->
      {:ok, {150, 150, @map_name}}
    end)

    stub(Broadcast, :to_in_range, fn @map_name, 150, 150, _range, packet ->
      send(test_pid, {:broadcast, packet.damage, packet.div})
      :ok
    end)

    stub(MobSession, :apply_damage, fn ^test_pid, damage, @caster_id ->
      send(test_pid, {:damage, damage})
      :ok
    end)

    assert :ok =
             Combat.apply_skill_unit_damage(
               caster(100),
               :mob,
               @target_id,
               85,
               10,
               :wind,
               1_400,
               20
             )

    assert_received {:broadcast, damage, 20}
    assert_received {:damage, ^damage}
    assert damage > 0
  end

  test "negative hit divisions floor the total before reporting equal client hits" do
    test_pid = self()
    mob_state = build_mob_state(10)

    stub(UnitRegistry, :get_unit, fn :mob, @target_id ->
      {:ok, {MobState, mob_state, test_pid}}
    end)

    stub(SpatialIndex, :get_unit_position, fn :mob, @target_id ->
      {:ok, {150, 150, @map_name}}
    end)

    stub(Broadcast, :to_in_range, fn @map_name, 150, 150, _range, packet ->
      send(test_pid, {:broadcast, packet.damage, packet.div})
      :ok
    end)

    stub(MobSession, :apply_damage, fn ^test_pid, damage, @caster_id ->
      send(test_pid, {:damage, damage})
      :ok
    end)

    assert :ok =
             Combat.apply_skill_unit_damage(
               caster(100),
               :mob,
               @target_id,
               85,
               10,
               :wind,
               1_400,
               20
             )

    assert_received {:broadcast, raw_damage, 20}
    assert_received {:damage, ^raw_damage}
    assert rem(raw_damage, 20) != 0

    assert :ok =
             Combat.apply_skill_unit_damage(
               caster(100),
               :mob,
               @target_id,
               85,
               10,
               :wind,
               1_400,
               -20
             )

    assert_received {:broadcast, rounded_damage, 20}
    assert_received {:damage, ^rounded_damage}
    assert rounded_damage == div(raw_damage, 20) * 20
  end

  test "threads the skill id into the ground-unit magic calculation" do
    Mimic.copy(MagicDamageCalculator)
    test_pid = self()
    mob_state = build_mob_state(10)

    stub(UnitRegistry, :get_unit, fn :mob, @target_id ->
      {:ok, {MobState, mob_state, test_pid}}
    end)

    stub(SpatialIndex, :get_unit_position, fn :mob, @target_id ->
      {:ok, {150, 150, @map_name}}
    end)

    stub(Broadcast, :to_in_range, fn @map_name, 150, 150, _range, _packet -> :ok end)
    stub(MobSession, :apply_damage, fn ^test_pid, _damage, @caster_id -> :ok end)

    stub(MagicDamageCalculator, :calculate_magic_damage, fn _a, _t, opts ->
      send(test_pid, {:skill_id, opts[:skill_id]})
      {:ok, %{damage: 10, is_critical: false}}
    end)

    assert :ok =
             Combat.apply_skill_unit_damage(caster(100), :mob, @target_id, 89, 10, :water, 600)

    assert_received {:skill_id, 89}
  end

  test "skips cleanly when the target cannot be resolved" do
    stub(UnitRegistry, :get_unit, fn :mob, @target_id -> {:error, :not_found} end)
    stub(UnitRegistry, :get_player_pid, fn @target_id -> {:error, :not_found} end)

    reject(&EquipComa.trigger?/2)
    reject(&Broadcast.to_in_range/5)
    reject(&MobSession.apply_damage/3)

    assert {:error, :target_not_found} =
             Combat.apply_skill_unit_damage(caster(100), :mob, @target_id, 89, 10, :water, 600)
  end

  test "supports Fire Pillar's flat MATK, multi-hit, and target walk delay" do
    test_pid = self()
    mob_state = build_mob_state(0)

    stub(UnitRegistry, :get_unit, fn :mob, @target_id ->
      {:ok, {MobState, mob_state, test_pid}}
    end)

    stub(SpatialIndex, :get_unit_position, fn :mob, @target_id -> {:ok, {150, 150, @map_name}} end)

    stub(Broadcast, :to_in_range, fn @map_name, 150, 150, _range, packet ->
      send(test_pid, {:broadcast, packet.damage, packet.div, packet.dst_delay})
      :ok
    end)

    stub(MobSession, :apply_damage, fn ^test_pid, _damage, @caster_id -> :ok end)
    stub(MobSession, :apply_walk_delay, fn ^test_pid, 600 -> send(test_pid, :walk_delayed) end)

    assert :ok =
             Combat.apply_skill_unit_damage(caster(100), :mob, @target_id, 80, 1, :fire, 60,
               bonus_matk: 150,
               hit_count: 3,
               dst_delay: 600,
               divide_hits_for_player?: true
             )

    assert_received {:broadcast, damage, 3, 600}
    assert_received :walk_delayed
    assert damage > 150
  end
end
