defmodule Aesir.ZoneServer.Mmo.Skills.Assassin.AsGrimtoothTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup
  import Mimic

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.SplashTargets
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobSkill.Executor
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.Skill.Unit.TrapState
  alias Aesir.ZoneServer.Mmo.Skills.Assassin.AsGrimtooth
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats.Equipment
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables
  setup :verify_on_exit!

  setup do
    Catalog.reload()
    :ok
  end

  test "defines Grimtooth's complete static formulas" do
    definition = AsGrimtooth.definition()

    assert definition.id == 137
    assert definition.name == :as_grimtooth
    assert definition.max_level == 5
    assert definition.target_type == :target_enemy
    assert definition.damage_type == :damage
    assert definition.damage_kind == :weapon
    assert definition.range == [3, 4, 5, 6, 7]
    assert definition.splash_radius == 1
    assert definition.sp_cost == List.duplicate(3, 5)
    assert definition.requires == []
    assert {:ok, ^definition} = Catalog.by_id(137)

    assert AsGrimtooth.skill_ratio(1) == 120
    assert AsGrimtooth.skill_ratio(5) == 200
  end

  test "players require both a Katar and active Hiding while mobs bypass both gates" do
    katar_user = player_state(1, 1250)
    dagger_user = player_state(2, 1201)
    target = {:unit, 100}
    definition = AsGrimtooth.definition()

    :ok = StatusStorage.apply_status(:player, 1, :sc_hiding, duration: 5_000)
    :ok = StatusStorage.apply_status(:player, 2, :sc_hiding, duration: 5_000)

    assert :ok = AsGrimtooth.validate(katar_user, target, 1, definition)

    assert {:error, :katar_not_equipped} =
             AsGrimtooth.validate(dagger_user, target, 1, definition)

    :ok = StatusStorage.remove_status(:player, 1, :sc_hiding)
    :ok = StatusStorage.apply_status(:player, 1, :sc_cloaking, duration: 5_000)

    assert {:error, :hiding_required} = AsGrimtooth.validate(katar_user, target, 1, definition)

    mob = %MobState{
      instance_id: 300,
      mob_id: 1,
      mob_data: %{modes: []},
      spawn_ref: nil,
      map_name: "prontera",
      x: 50,
      y: 50,
      hp: 100,
      max_hp: 100,
      sp: 0,
      max_sp: 0,
      spawned_at: 0
    }

    assert :ok = AsGrimtooth.validate(mob, target, 1, definition)
  end

  test "directly targeting a live trap fails before SP commitment" do
    caster = player_state(1, 1250)
    caster = put_in(caster.stats.progression.learned_skills, %{137 => 1})
    caster = put_in(caster.stats.current_state.sp, 20)

    :ok = UnitRegistry.register_player(caster, self())
    :ok = SpatialIndex.add_player(caster.character_id, 50, 50, caster.map_name)
    :ok = StatusStorage.apply_status(:player, caster.character_id, :sc_hiding, duration: 5_000)

    trap_owner = mob_state(300, [])
    register_mob(trap_owner, 60, 60)

    manager =
      start_supervised!(
        {Manager,
         name: nil,
         clock: fn -> 0 end,
         schedule_tick: fn _pid, _interval -> :ok end,
         unit_available?: fn _type, _id, _map -> true end},
        id: make_ref()
      )

    trap = %Group{
      group_id: 1,
      skill_id: 116,
      skill_name: :ht_landmine,
      level: 1,
      caster_id: trap_owner.instance_id,
      caster_type: :mob,
      map_name: "prontera",
      center: {53, 50},
      cells: [{53, 50}],
      next_tick_at: 1_000,
      expires_at: 10_000,
      interval: 1_000,
      visibility: :public,
      state: %{
        trap: %TrapState{reclaim_item_id: 1065},
        cell_attrs: %{{53, 50} => %{hp: 10, max_hp: 10, flags: [:targetable]}}
      }
    }

    assert :ok = Manager.register(manager, trap)
    assert [cell] = Storage.get_cells_by_group(trap.group_id)

    assert {:error, :invalid_target} =
             Interpreter.cast(caster, 137, 1, {:unit, cell.cell_id})

    assert caster.stats.current_state.sp == 20

    attacker = PlayerState.to_combatant(caster)

    assert [{:skill_unit, cell.cell_id}] ==
             SplashTargets.select("prontera", {53, 50}, 1, attacker, false,
               target_skill_units: true
             )
  end

  test "casts one ranged target-centered 3x3 weapon splash at the level ratio" do
    caster = player_state(1, 1250)
    definition = AsGrimtooth.definition()

    expect(Combat, :resolve_target_position, fn 100 ->
      {:ok, :mob, {55, 50, "prontera"}}
    end)

    expect(Combat, :execute_splash_attack, fn ^caster, {55, 50}, 1, opts ->
      assert opts[:skill_id] == 137
      assert opts[:skill_level] == 4
      assert opts[:skill_ratio] == 180
      assert opts[:hit_count] == 1
      assert opts[:skip_crit]
      assert opts[:ranged]
      assert opts[:typed_results]
      assert opts[:target_skill_units]
      []
    end)

    assert {:ok, ^caster} = AsGrimtooth.cast(caster, {:unit, 100}, 4, definition)
  end

  test "real splash damages a live enemy trap exactly once" do
    caster = combat_ready_player(1)
    primary_target = mob_state(100, [])
    trap_owner = mob_state(300, [])

    :ok = UnitRegistry.register_player(caster, self())
    :ok = SpatialIndex.add_player(caster.character_id, 50, 50, caster.map_name)
    register_mob(primary_target, 55, 50)
    register_mob(trap_owner, 60, 60)

    manager =
      start_supervised!(
        {Manager,
         name: nil,
         clock: fn -> 0 end,
         schedule_tick: fn _pid, _interval -> :ok end,
         unit_available?: fn _type, _id, _map -> true end},
        id: make_ref()
      )

    trap = %Group{
      group_id: 1,
      skill_id: 116,
      skill_name: :ht_landmine,
      level: 1,
      caster_id: trap_owner.instance_id,
      caster_type: :mob,
      map_name: "prontera",
      center: {54, 50},
      cells: [{54, 50}],
      next_tick_at: 1_000,
      expires_at: 10_000,
      interval: 1_000,
      visibility: :public,
      state: %{
        trap: %TrapState{reclaim_item_id: 1065},
        cell_attrs: %{{54, 50} => %{hp: 100, max_hp: 100, flags: [:targetable]}}
      }
    }

    assert :ok = Manager.register(manager, trap)
    assert [cell] = Storage.get_cells_by_group(trap.group_id)
    cell_id = cell.cell_id

    Mimic.copy(Manager)

    expect(Manager, :damage_targetable_cell, fn ^manager, ^cell_id, damage, {:player, 1} ->
      assert damage > 0
      send(self(), :trap_damage_delivered)
      call_original(Manager, :damage_targetable_cell, [manager, cell_id, damage, {:player, 1}])
    end)

    assert {:ok, ^caster} =
             AsGrimtooth.cast(
               caster,
               {:unit, primary_target.instance_id},
               1,
               AsGrimtooth.definition()
             )

    assert_received :trap_damage_delivered
    assert %_{hp: hp, max_hp: 100} = Storage.get_cell(cell_id)
    assert hp < 100
    assert_received {:"$gen_cast", {:send_packet, %{cell_id: ^cell_id}}}
    refute_received :trap_damage_delivered
  end

  test "one-second Quagmire rides a connected mob whose ranged hit is fully absorbed" do
    caster = combat_ready_player(1)
    target = mob_state(100, [])

    :ok = UnitRegistry.register_player(caster, self())
    :ok = SpatialIndex.add_player(caster.character_id, 50, 50, caster.map_name)
    register_mob(target, 55, 50)
    :ok = StatusInterpreter.apply_status(:mob, target.instance_id, :sc_pneuma, duration: 5_000)

    Mimic.copy(StatusInterpreter)

    expect(StatusInterpreter, :apply_status, fn :mob, 100, :sc_quagmire, params ->
      assert params[:duration] == 1_000
      send(self(), :quagmire_applied)
      call_original(StatusInterpreter, :apply_status, [:mob, 100, :sc_quagmire, params])
    end)

    assert {:ok, ^caster} =
             AsGrimtooth.cast(caster, {:unit, target.instance_id}, 3, AsGrimtooth.definition())

    assert_received :quagmire_applied
    assert_received {:"$gen_cast", {:combat, {:apply_damage, 0, 1}}}

    assert %{val1: 3, val2: 30, expires_at: expires_at} =
             StatusStorage.get_status(:mob, target.instance_id, :sc_quagmire)

    assert_in_delta expires_at - System.monotonic_time(:millisecond), 1_000, 100
    refute_received :quagmire_applied
  end

  test "one-second Quagmire rides connected non-immune mobs only" do
    caster = player_state(1, 1250)
    target = mob_state(100, [])
    immune_target = mob_state(101, [:status_immune])
    player_target = player_state(2, 1201)

    register_mob(target, 55, 50)
    register_mob(immune_target, 55, 51)
    :ok = UnitRegistry.register_player(player_target, self())
    :ok = SpatialIndex.add_player(player_target.character_id, 54, 50, player_target.map_name)

    stub(Combat, :resolve_target_position, fn 100 -> {:ok, :mob, {55, 50, "prontera"}} end)

    expect(Combat, :execute_splash_attack, fn _caster, {55, 50}, 1, _opts ->
      [{:mob, 100}, {:mob, 101}, {:player, 2}, {:skill_unit, 0x4000_0001}]
    end)

    assert {:ok, ^caster} =
             AsGrimtooth.cast(caster, {:unit, target.instance_id}, 3, AsGrimtooth.definition())

    assert status = StatusStorage.get_status(:mob, target.instance_id, :sc_quagmire)
    assert status.val1 == 3
    assert status.val2 == 30
    assert_in_delta status.expires_at - System.monotonic_time(:millisecond), 1_000, 100

    refute StatusStorage.has_status?(:mob, immune_target.instance_id, :sc_quagmire)
    refute StatusStorage.has_status?(:player, player_target.character_id, :sc_quagmire)
  end

  test "MobSkill Executor casts Grimtooth without player equipment or Hiding" do
    target = player_state(2, 1201)
    :ok = UnitRegistry.register_player(target, self())

    caster = %{mob_state(300, []) | target_ref: {:player, target.character_id}}

    expect(Combat, :resolve_target_position, fn 2 ->
      {:ok, :player, {52, 50, "prontera"}}
    end)

    expect(Combat, :execute_splash_attack, fn ^caster, {52, 50}, 1, opts ->
      assert opts[:skill_id] == 137
      assert opts[:skill_level] == 2
      assert opts[:skill_ratio] == 140
      []
    end)

    row = %{skill_id: 137, skill: :as_grimtooth, level: 2, target: :target}

    assert :ok = Executor.execute(caster, row)
  end

  defp combat_ready_player(id) do
    player = player_state(id, 1250)
    put_in(player.stats.combat_stats.hit, 1_000)
  end

  defp register_mob(mob, x, y) do
    :ok = UnitRegistry.register_unit(:mob, mob.instance_id, MobState, mob, self())
    :ok = SpatialIndex.add_unit(:mob, mob.instance_id, x, y, mob.map_name)
  end

  defp mob_state(id, modes) do
    definition = %MobDefinition{
      id: id,
      aegis_name: "PORING",
      name: "Poring",
      level: 1,
      hp: 100,
      stats: %{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
      attack_range: 1,
      size: :medium,
      race: :brute,
      element: {:water, 1},
      walk_speed: 200,
      attack_delay: 1_000,
      attack_motion: 500,
      client_attack_motion: 500,
      damage_motion: 500,
      modes: modes
    }

    %MobState{
      instance_id: id,
      mob_id: definition.id,
      mob_data: definition,
      spawn_ref: nil,
      map_name: "prontera",
      x: 55,
      y: 50,
      hp: 100,
      max_hp: 100,
      sp: 0,
      max_sp: 0,
      spawned_at: 0
    }
  end

  defp player_state(id, weapon_id) do
    state =
      PlayerState.new(%Character{
        id: id,
        account_id: id,
        name: "Player #{id}",
        last_map: "prontera",
        last_x: 50,
        last_y: 50,
        sex: "M",
        str: 1,
        agi: 1,
        vit: 1,
        int: 1,
        dex: 1,
        luk: 1,
        base_level: 50,
        job_level: 50,
        class: 12
      })

    put_in(state.stats.equipment, %Equipment{right_hand: weapon_id})
  end
end
