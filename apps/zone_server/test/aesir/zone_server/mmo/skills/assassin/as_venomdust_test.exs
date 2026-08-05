defmodule Aesir.ZoneServer.Mmo.Skills.Assassin.AsVenomdustTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup
  import Mimic

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter
  alias Aesir.ZoneServer.Mmo.Skill.Unit
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.Skills.Assassin.AsVenomdust
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.PlayerStateFixture
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.Stats.CombatStats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables
  setup :verify_on_exit!

  @center {100, 100}

  defp group(level) do
    %Group{
      group_id: 1,
      skill_id: 140,
      skill_name: :as_venomdust,
      level: level,
      caster_id: 1_000,
      caster_type: :player,
      map_name: "prontera",
      center: @center,
      cells: [{100, 100}, {99, 100}, {101, 100}, {100, 99}, {100, 101}],
      state: %{}
    }
  end

  test "defines levels, range, costs, timing, and five range-one cells" do
    assert {:ok, definition} = Catalog.by_id(140)
    assert definition.name == :as_venomdust
    assert definition.max_level == 10
    assert definition.target_type == :ground
    assert definition.requires == []
    assert definition.range == 2
    assert definition.sp_cost == List.duplicate(20, 10)
    assert definition.item_cost == [%{id: 716, amount: 1}]
    assert definition.hit_interval == 1_000
    assert definition.unit_duration == Enum.to_list(5_000..50_000//5_000)

    assert {:ok, placement} = AsVenomdust.on_place(group(10))

    assert Enum.sort(placement.cells) ==
             Enum.sort([{100, 100}, {99, 100}, {101, 100}, {100, 99}, {100, 101}])

    assert placement.state == %{}
    assert placement.interval == 1_000
    assert placement.duration == 50_000
  end

  test "queries every cell at range one, deduplicates targets, and skips existing Poison" do
    caster = %{unit_type: :player, unit_id: 1_000, map_name: "prontera"}
    poisoned_target = 2_001
    :ok = StatusStorage.apply_status(:mob, poisoned_target, :sc_poison, duration: 5_000)

    expect(Combat, :resolve_combatant, fn :player, 1_000 -> {:ok, caster} end)

    expect(Combat, :splash_targets, 5, fn "prontera", cell, 1, ^caster ->
      assert cell in [{100, 100}, {99, 100}, {101, 100}, {100, 99}, {100, 101}]
      [{:mob, 2_000}, {:mob, poisoned_target}]
    end)

    expect(StatusInterpreter, :apply_status, fn :mob, 2_000, :sc_poison, params ->
      assert params == [duration: 18_000, caster_id: 1_000, source_type: :player]
      :ok
    end)

    assert {:ok, %Group{}} = AsVenomdust.on_interval(group(1), 1_000)
  end

  test "preserves a mob caster as the typed Poison source" do
    caster = %{unit_type: :mob, unit_id: 3_000, map_name: "prontera"}
    mob_group = %{group(1) | caster_type: :mob, caster_id: 3_000}

    expect(Combat, :resolve_combatant, fn :mob, 3_000 -> {:ok, caster} end)
    stub(Combat, :splash_targets, fn "prontera", _cell, 1, ^caster -> [{:player, 4_000}] end)

    expect(StatusInterpreter, :apply_status, fn :player, 4_000, :sc_poison, params ->
      assert params == [duration: 18_000, caster_id: 3_000, source_type: :mob]
      :ok
    end)

    assert {:ok, %Group{}} = AsVenomdust.on_interval(mob_group, 1_000)
  end

  test "commits one Red Gemstone only after player placement succeeds" do
    caster = player_caster()

    expect(Unit, :place, fn ^caster,
                            :as_venomdust,
                            3,
                            @center,
                            origin: :normal,
                            state: %{paid_return?: true} ->
      {:ok, group(3)}
    end)

    assert {:ok, updated} = Interpreter.complete_cast(caster, 140, 3, {:ground, 100, 100})
    assert updated.stats.current_state.sp == 80
    assert updated.inventory == %{}
    assert [_change] = updated.pending_inventory_persist
  end

  test "failed placement commits neither SP nor Red Gemstone" do
    caster = player_caster()

    expect(Unit, :place, fn ^caster,
                            :as_venomdust,
                            3,
                            @center,
                            origin: :normal,
                            state: %{paid_return?: true} ->
      {:error, :skill_unit_overlap}
    end)

    assert {:error, :skill_unit_overlap} =
             Interpreter.complete_cast(caster, 140, 3, {:ground, 100, 100})

    assert caster.stats.current_state.sp == 100
    assert %{0 => %InventoryItem{nameid: 716, amount: 1}} = caster.inventory
    assert caster.pending_inventory_persist == []
  end

  test "mob placement uses the shared ground path without player resource commitment" do
    definition = AsVenomdust.definition()

    mob = %MobState{
      instance_id: 3_000,
      mob_id: 1,
      mob_data: %{skill_range: 2},
      spawn_ref: nil,
      map_name: "prontera",
      x: 90,
      y: 90,
      hp: 100,
      max_hp: 100,
      sp: 0,
      max_sp: 0,
      spawned_at: 0
    }

    expect(Unit, :place, fn ^mob,
                            :as_venomdust,
                            4,
                            @center,
                            origin: :mob,
                            state: %{paid_return?: false} ->
      {:ok, %{group(4) | caster_type: :mob, caster_id: 3_000}}
    end)

    assert {:ok, ^mob} =
             AsVenomdust.cast_with_origin(mob, {:ground, 100, 100}, 4, definition, :mob)
  end

  test "a real manager interval applies one typed Poison across overlapping cell ranges" do
    caster = player_caster()
    target = mob_target(2_000)

    :ok = UnitRegistry.register_player(caster, self())
    :ok = SpatialIndex.add_player(caster.character_id, caster.x, caster.y, caster.map_name)
    :ok = UnitRegistry.register_unit(:mob, target.instance_id, MobState, target, self())
    :ok = SpatialIndex.add_unit(:mob, target.instance_id, 100, 100, "prontera")

    manager = start_manager(fn _type, _id, _map -> true end)
    interval_group = timed_group(9, next_tick_at: 1_000, expires_at: 5_000)

    assert :ok = Manager.register(manager, interval_group)
    assert :ok = Manager.tick(manager, 1_000)

    assert %{source_id: 1_000, source_type: :player} =
             StatusStorage.get_status(:mob, target.instance_id, :sc_poison)
  end

  test "manager records Fire Rain metadata and performs ordinary expiry and caster-loss cleanup" do
    expiry_manager = start_manager(fn _type, _id, _map -> true end)
    expiring = timed_group(10, next_tick_at: 20_000, expires_at: 5_000)

    assert :ok = Manager.register(expiry_manager, expiring)
    assert %Group{state: %{removed_by_fire_rain: true}} = Storage.get(10)
    assert :ok = Manager.tick(expiry_manager, 5_000)
    assert Storage.get(10) == nil

    loss_manager = start_manager(fn _type, _id, _map -> false end)
    lost = timed_group(11, next_tick_at: 1_000, expires_at: 10_000)

    assert :ok = Manager.register(loss_manager, lost)
    assert :ok = Manager.tick(loss_manager, 1_000)
    assert Storage.get(11) == nil
  end

  defp player_caster do
    %PlayerState{
      character_id: 1_000,
      map_name: "prontera",
      x: 100,
      y: 100,
      inventory: %{0 => %InventoryItem{nameid: 716, amount: 1, equip: 0}},
      pending_inventory_persist: [],
      stats: %{
        combat_stats: %CombatStats{},
        current_state: %{sp: 100},
        progression: %{learned_skills: %{140 => 3}}
      }
    }
    |> PlayerStateFixture.build()
  end

  defp mob_target(instance_id) do
    definition = %MobDefinition{
      id: 1,
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
      damage_motion: 500
    }

    %MobState{
      instance_id: instance_id,
      mob_id: definition.id,
      mob_data: definition,
      spawn_ref: nil,
      map_name: "prontera",
      x: 100,
      y: 100,
      hp: 100,
      max_hp: 100,
      sp: 0,
      max_sp: 0,
      spawned_at: 0
    }
  end

  defp timed_group(group_id, opts) do
    %{
      group(1)
      | group_id: group_id,
        created_at: 0,
        interval: 1_000,
        next_tick_at: Keyword.fetch!(opts, :next_tick_at),
        expires_at: Keyword.fetch!(opts, :expires_at)
    }
  end

  defp start_manager(unit_available?) do
    start_supervised!(
      {Manager,
       name: nil, schedule_tick: fn _pid, _interval -> :ok end, unit_available?: unit_available?},
      id: make_ref()
    )
  end
end
