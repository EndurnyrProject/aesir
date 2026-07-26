defmodule Aesir.ZoneServer.Mmo.Skills.Priest.PrSanctuaryTest do
  use ExUnit.Case, async: false
  import Aesir.TestEtsSetup
  import Mimic

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.DamageApplication
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter
  alias Aesir.ZoneServer.Mmo.Skill.Unit
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.Skills.Priest.PrSanctuary
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables
  setup :verify_on_exit!

  setup do
    Mimic.copy(DamageApplication)
    :ok
  end

  @center {150, 150}

  defp group(level, state \\ %{}) do
    %Group{
      group_id: 70_001,
      skill_id: 70,
      skill_name: :pr_sanctuary,
      level: level,
      caster_id: 1_000,
      caster_type: :player,
      map_name: "prontera",
      center: @center,
      cells: [@center],
      state: state
    }
  end

  defp mob(id, race, element, hp \\ 500, max_hp \\ 1_000) do
    definition = %MobDefinition{
      id: id,
      aegis_name: "SANCTUARY_TARGET",
      name: "Sanctuary Target",
      level: 1,
      hp: max_hp,
      sp: 1,
      base_exp: 0,
      job_exp: 0,
      atk: 1,
      matk: 1,
      def: 0,
      mdef: 0,
      stats: %{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
      attack_range: 1,
      skill_range: 1,
      chase_range: 1,
      element: {element, 1},
      race: race,
      size: :medium,
      walk_speed: 200,
      attack_delay: 1_000,
      attack_motion: 500,
      client_attack_motion: 500,
      damage_motion: 400,
      ai_type: 0,
      modes: [],
      drops: []
    }

    spawn = %MobSpawn{
      mob: id,
      amount: 1,
      respawn_time: 5_000,
      spawn_area: %MobSpawn.SpawnArea{x: 150, y: 150, xs: 0, ys: 0}
    }

    %MobState{
      instance_id: id,
      mob_id: id,
      mob_data: definition,
      spawn_ref: spawn,
      x: 150,
      y: 150,
      map_name: "prontera",
      hp: hp,
      max_hp: max_hp,
      sp: 1,
      max_sp: 1,
      spawned_at: 0
    }
  end

  defp stub_tick(targets, enemies \\ []) do
    stub(Combat, :resolve_combatant, fn 1_000 -> {:ok, %{unit_id: 1_000}} end)
    stub(Combat, :splash_targets, fn "prontera", @center, 2, 1_000 -> enemies end)

    stub(SpatialIndex, :get_all_units_in_range, fn
      "prontera", 150, 150, 0 -> targets
    end)

    stub(SpatialIndex, :get_unit_position, fn _type, _id ->
      {:ok, {150, 150, "prontera"}}
    end)
  end

  test "loads the exact Renewal cast, cost, and timing data" do
    assert {:ok, definition} = Catalog.by_id(70)
    assert definition.name == :pr_sanctuary
    assert definition.target_type == :ground
    assert definition.damage_type == :no_damage
    assert definition.element == :holy
    assert definition.range == 9
    assert definition.knockback == 2
    assert definition.hit_interval == 1_000
    assert definition.cast_time == List.duplicate(4_000, 10)
    assert definition.fixed_cast_time == List.duplicate(1_000, 10)
    assert definition.sp_cost == [15, 18, 21, 24, 27, 30, 33, 36, 39, 42]
    assert definition.item_cost == [%{id: 717, amount: 1}]

    assert definition.unit_duration ==
             [3_900, 6_900, 9_900, 12_900, 15_900, 18_900, 21_900, 24_900, 27_900, 30_900]
  end

  test "places the 21-cell path-checked field with a level plus three offensive quota" do
    assert {:ok, placement} = PrSanctuary.on_place(group(5))
    assert length(placement.cells) == 21
    assert Enum.uniq(placement.cells) == placement.cells
    refute {148, 148} in placement.cells
    assert {150, 150} in placement.cells
    assert {149, 148} in placement.cells
    assert placement.interval == 1_000
    assert placement.duration == 15_900
    assert placement.path_check
    assert placement.state == %{hits_remaining: 8}
  end

  test "registers a visible observer field with the exact first-level expiry" do
    test_pid = self()
    manager = start_supervised!({Manager, name: nil, schedule_tick: fn _, _ -> :ok end})
    Process.put({Manager, :server}, manager)
    on_exit(fn -> Process.delete({Manager, :server}) end)

    :ets.insert(
      EtsTable.table_for(:map_cache),
      {"prontera", MapData.new("prontera", 300, 300)}
    )

    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet ->
      send(test_pid, :observer_broadcast)
      :ok
    end)

    caster = %PlayerState{
      character_id: 1_000,
      map_name: "prontera",
      x: 150,
      y: 150
    }

    assert {:ok, placed} = Unit.place(caster, :pr_sanctuary, 1, {150, 150})
    assert placed.visible?
    assert placed.expires_at - placed.created_at == 3_900
    assert length(placed.cells) == 21
    assert_receive :observer_broadcast
  end

  test "two concurrent casts admit one visible field and consume one Blue Gemstone" do
    test_pid = self()
    manager = start_supervised!({Manager, name: nil, schedule_tick: fn _, _ -> :ok end})

    :ets.insert(
      EtsTable.table_for(:map_cache),
      {"prontera", MapData.new("prontera", 300, 300)}
    )

    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)

    stub(Unit, :place, fn caster, skill_name, level, target, options ->
      assert options == [origin: :normal, state: %{paid_return?: true}]
      send(test_pid, {:ready_to_place, self()})

      receive do
        :place -> call_original(Unit, :place, [caster, skill_name, level, target, options])
      end
    end)

    casters =
      for caster_id <- [1_000, 1_001] do
        %PlayerState{
          character_id: caster_id,
          map_name: "prontera",
          x: 150,
          y: 150,
          inventory: %{0 => %InventoryItem{nameid: 717, amount: 1, equip: 0}},
          pending_inventory_persist: [],
          stats: %{current_state: %{sp: 100}}
        }
      end

    tasks =
      Enum.map(casters, fn caster ->
        Task.async(fn ->
          receive do
            :cast ->
              Process.put({Manager, :server}, manager)
              Interpreter.complete_cast(caster, 70, 1, {:ground, 150, 150})
          end
        end)
      end)

    Enum.each(tasks, fn task ->
      allow(Unit, self(), task.pid)
      allow(Broadcast, self(), task.pid)
      send(task.pid, :cast)
    end)

    placing = for _ <- tasks, do: receive(do: ({:ready_to_place, pid} -> pid))
    Enum.each(placing, &send(&1, :place))
    results = Task.await_many(tasks)

    assert Enum.count(results, &match?({:ok, %PlayerState{}}, &1)) == 1
    assert Enum.count(results, &(&1 == {:error, :skill_unit_overlap})) == 1

    assert {:ok,
            %PlayerState{
              inventory: %{},
              pending_inventory_persist: [_catalyst_change]
            }} = Enum.find(results, &match?({:ok, %PlayerState{}}, &1))

    assert [%Group{skill_id: 70, visible?: true}] = Storage.all()
  end

  test "heals living injured mobs every second without spending offensive quota" do
    target = mob(2_001, :formless, :neutral)
    stub_tick([{:mob, 2_001}])
    stub(UnitRegistry, :get_unit, fn :mob, 2_001 -> {:ok, {MobState, target, self()}} end)
    expect(MobSession, :heal, fn pid, 600 -> assert pid == self() end)
    reject(&Combat.apply_skill_unit_damage/8)

    assert {:ok, %Group{state: %{hits_remaining: 9}}} =
             PrSanctuary.on_interval(group(6, %{hits_remaining: 9}), 1_000)
  end

  test "heals an injured player through the existing player damage application path" do
    target = %PlayerState{
      character_id: 2_001,
      action_state: :idle,
      stats: %{current_state: %{hp: 100}, derived_stats: %{max_hp: 1_000}}
    }

    stub_tick([{:player, 2_001}])

    stub(UnitRegistry, :get_unit, fn :player, 2_001 ->
      {:ok, {PlayerState, target, self()}}
    end)

    expect(DamageApplication, :apply_heal, fn :player, 2_001, 500, 1_000 -> :ok end)

    assert {:ok, %Group{state: %{hits_remaining: 8}}} =
             PrSanctuary.on_interval(group(5, %{hits_remaining: 8}), 1_000)
  end

  test "uses 777 healing above level six and skips full HP, corpses, and Emperium" do
    injured = mob(2_001, :formless, :neutral)
    full = mob(2_002, :formless, :neutral, 1_000)
    corpse = %{mob(2_003, :formless, :neutral, 0) | is_dead: true}
    emperium = mob(1_288, :angel, :holy)
    targets = [{:mob, 2_001}, {:mob, 2_002}, {:mob, 2_003}, {:mob, 1_288}]
    states = %{2_001 => injured, 2_002 => full, 2_003 => corpse, 1_288 => emperium}
    stub_tick(targets)

    stub(UnitRegistry, :get_unit, fn :mob, id ->
      {:ok, {MobState, Map.fetch!(states, id), self()}}
    end)

    expect(MobSession, :heal, 1, fn _pid, 777 -> :ok end)

    assert {:ok, %Group{state: %{hits_remaining: 10}}} =
             PrSanctuary.on_interval(group(7, %{hits_remaining: 10}), 1_000)
  end

  test "damages enemy undead and demons with fixed Holy damage and spends quota only on success" do
    targets = [{:mob, 2_001}, {:mob, 2_002}, {:mob, 2_003}]

    states = %{
      2_001 => mob(2_001, :undead, :neutral),
      2_002 => mob(2_002, :demon, :neutral),
      2_003 => mob(2_003, :formless, :undead)
    }

    stub_tick(targets, targets)
    stub(UnitRegistry, :get_unit, fn :mob, id -> {:ok, {MobState, states[id], self()}} end)

    expect(Combat, :apply_skill_unit_damage, 3, fn
      _caster, :mob, id, 70, 7, :holy, 0, [fixed_damage: 777] ->
        if id == 2_002, do: {:error, :miss}, else: :ok
    end)

    expect(Combat, :knockback, 2, fn :mob, id, 150, 150, 2 ->
      assert id in [2_001, 2_003]
      {:ok, {150, 150}}
    end)

    assert {:ok, %Group{state: %{hits_remaining: 8}}} =
             PrSanctuary.on_interval(group(7, %{hits_remaining: 10}), 1_000)
  end

  test "stops offensive processing exactly when the shared quota reaches zero" do
    targets = Enum.map(2_001..2_006, &{:mob, &1})
    states = Map.new(2_001..2_006, &{&1, mob(&1, :undead, :neutral)})
    stub_tick(targets, targets)
    stub(UnitRegistry, :get_unit, fn :mob, id -> {:ok, {MobState, states[id], self()}} end)

    expect(Combat, :apply_skill_unit_damage, 4, fn _,
                                                   :mob,
                                                   _,
                                                   70,
                                                   1,
                                                   :holy,
                                                   0,
                                                   [fixed_damage: 100] ->
      :ok
    end)

    stub(Combat, :knockback, fn :mob, _, 150, 150, 2 -> {:ok, {150, 150}} end)

    assert {:expire, %Group{state: %{hits_remaining: 0}}} =
             PrSanctuary.on_interval(group(1, %{hits_remaining: 4}), 1_000)
  end

  test "an exhausted field expires without looking up targets" do
    reject(&Combat.resolve_combatant/1)
    reject(&SpatialIndex.get_all_units_in_range/4)

    assert {:expire, %Group{state: %{hits_remaining: 0}}} =
             PrSanctuary.on_interval(group(1, %{hits_remaining: 0}), 1_000)
  end
end
