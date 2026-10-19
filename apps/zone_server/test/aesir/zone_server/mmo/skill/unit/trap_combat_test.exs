defmodule Aesir.ZoneServer.Mmo.Skill.Unit.TrapCombatTest do
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Map.GatType
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.HitCalculations
  alias Aesir.ZoneServer.Mmo.Combat.Knockback
  alias Aesir.ZoneServer.Mmo.Combat.SplashTargets
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.MobManagement.Mobs
  alias Aesir.ZoneServer.Mmo.Skill.Unit
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.Skills.Rogue.RgRaid
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @map "trap_combat"
  setup :setup_ets_tables
  setup :set_mimic_private

  setup do
    :ets.insert(EtsTable.table_for(:map_cache), {@map, MapData.new(@map, 40, 40)})
    now = System.monotonic_time(:millisecond)

    manager =
      start_supervised!(
        {Manager,
         name: nil,
         clock: fn -> now end,
         schedule_tick: fn _, _ -> :ok end,
         unit_available?: fn _, _, _ -> true end}
      )

    Process.put({Manager, :server}, manager)

    player =
      PlayerState.new(%Character{
        id: 1,
        account_id: 1,
        name: "TrapOwner",
        last_map: @map,
        last_x: 8,
        last_y: 8,
        class: 11,
        sex: "F",
        base_level: 20,
        job_level: 20,
        hp: 100,
        sp: 100,
        str: 20,
        dex: 20,
        vit: 10,
        agi: 10,
        int: 10,
        luk: 0
      })

    UnitRegistry.register_unit(:player, 1, PlayerState, player, self())
    %{manager: manager, now: now, player: player}
  end

  test "a trap push moves its registered cell without resetting its identity or lifetime", %{
    manager: manager,
    player: player
  } do
    assert {:ok, group} = Unit.place(player, :ht_landmine, 1, {10, 10})
    [original] = Storage.get_cells_by_group(group.group_id)
    deadline = Storage.get(group.group_id).expires_at

    assert {:ok, {13, 10}} = Knockback.knockback(:skill_unit, original.cell_id, 9, 10, 3)
    assert {:ok, moved} = Manager.targetable_cell(manager, original.cell_id)
    assert {moved.x, moved.y, moved.hp, moved.cell_id} == {13, 10, 3_500, original.cell_id}

    assert %{cells: [{13, 10}], center: {13, 10}, expires_at: ^deadline} =
             Storage.get(group.group_id)

    assert {:ok, {13, 10, @map}} = SpatialIndex.get_unit_position(:skill_unit, original.cell_id)
    assert {:ok, {_, ^moved, ^manager}} = UnitRegistry.get_unit(:skill_unit, original.cell_id)
    assert Storage.get_groups_at_cell(@map, 10, 10) == []
    assert [%{group_id: id}] = Storage.get_groups_at_cell(@map, 13, 10)
    assert id == group.group_id

    assert {:ok, %{hp: 0}} =
             Manager.damage_targetable_cell(manager, original.cell_id, 3_500, {:player, 1})

    assert {:ok, {16, 10}} = Knockback.knockback(:skill_unit, original.cell_id, 12, 10, 3)
    assert {:ok, %{x: 16, y: 10, hp: 0}} = Manager.targetable_cell(manager, original.cell_id)
    assert {:ok, {16, 10, @map}} = SpatialIndex.get_unit_position(:skill_unit, original.cell_id)
    assert {:ok, {_, %{hp: 0}, ^manager}} = UnitRegistry.get_unit(:skill_unit, original.cell_id)
  end

  test "a stale trap push is ignored and a wall bounds the next push", %{
    manager: manager,
    player: player
  } do
    assert {:ok, group} = Unit.place(player, :ht_landmine, 1, {10, 10})
    [cell] = Storage.get_cells_by_group(group.group_id)

    assert {:ok, {14, 10}} =
             Knockback.knockback(:skill_unit, cell.cell_id, 9, 10, 3, position: {11, 10})

    assert {:ok, ^cell} = Manager.targetable_cell(manager, cell.cell_id)

    map = MapData.new(@map, 40, 40) |> MapData.set_cell(12, 10, GatType.wall())
    :ets.insert(EtsTable.table_for(:map_cache), {@map, map})
    assert {:ok, {11, 10}} = Knockback.knockback(:skill_unit, cell.cell_id, 9, 10, 5)
    assert {:ok, %{x: 11, y: 10}} = Manager.targetable_cell(manager, cell.cell_id)
  end

  test "Ankle Snare and Ice Wall refuse knockback", %{manager: manager, player: player} do
    for {skill, position} <- [{:ht_anklesnare, {10, 10}}, {:wz_icewall, {20, 20}}] do
      assert {:ok, group} = Unit.place(player, skill, 1, position)
      [cell | _] = Storage.get_cells_by_group(group.group_id)

      assert {:ok, {cell.x, cell.y}} ==
               Knockback.knockback(:skill_unit, cell.cell_id, cell.x - 1, cell.y, 3)

      assert {:ok, ^cell} = Manager.targetable_cell(manager, cell.cell_id)
    end
  end

  test "a real trap stays targetable after lethal durability damage until the cell timer marks it used",
       %{manager: manager, now: now, player: player} do
    reject(&Coordinator.drop_items/4)
    allow(Coordinator, self(), manager)

    assert {:ok, group} =
             Unit.place(player, :ht_landmine, 1, {10, 10},
               origin: :normal,
               state: %{paid_return?: true}
             )

    assert [cell] = Storage.get_cells_by_group(group.group_id)
    stored = Storage.get(group.group_id)
    Storage.update(%{stored | expires_at: now + 200})
    assert {:ok, %{hp: 3_500}} = Manager.targetable_cell(manager, cell.cell_id)

    assert {:ok, %{hp: 0}} =
             Manager.damage_targetable_cell(manager, cell.cell_id, 3_500, {:player, 1})

    assert {:ok, _, pending, :skill_unit} = TargetResolver.resolve(:skill_unit, cell.cell_id)
    assert :ok = TargetResolver.ensure_targetable(pending, :skill_unit)

    assert :ok = Manager.tick(manager, now + 100)
    assert %{state: %{trap: %{phase: :used}}, expires_at: deadline} = Storage.get(group.group_id)
    assert deadline == now + 1_600
    assert {:error, _} = Manager.targetable_cell(manager, cell.cell_id)
    assert :ok = Manager.tick(manager, deadline)
    assert Storage.get(group.group_id) == nil
  end

  test "Raid and opt-in physical splashes hit traps regardless of their owner", %{player: player} do
    Mimic.copy(HitCalculations)
    stub(HitCalculations, :calculate_hit_result, fn _, _ -> :hit end)
    assert {:ok, group} = Unit.place(player, :ht_landmine, 1, {9, 8})
    [cell] = Storage.get_cells_by_group(group.group_id)
    ref = {:skill_unit, cell.cell_id}
    caster = PlayerState.to_combatant(player)
    assert SplashTargets.select(@map, {9, 8}, 1, caster, false, target_skill_units: true) == [ref]

    {:ok, data} = Mobs.by_id(1002)

    mob =
      %MobState{
        instance_id: 3,
        mob_id: 1002,
        mob_data: data,
        spawn_ref: nil,
        x: 8,
        y: 8,
        map_name: @map,
        hp: 55,
        sp: 1,
        spawned_at: 0
      }
      |> Aesir.TestMob.publish(max_hp: 55, max_sp: 1)

    UnitRegistry.register_unit(:mob, 3, MobState, mob, self())
    assert {:ok, ^mob} = RgRaid.cast(mob, :self, 1, RgRaid.definition())
    first_hp = Storage.get_cell(cell.cell_id).hp
    assert first_hp < 3_500

    assert Combat.execute_splash_attack(mob, {9, 8}, 1,
             skill_id: 137,
             skill_level: 1,
             skill_ratio: 100,
             ignore_flee: true,
             target_skill_units: true,
             typed_results: true
           ) == [ref]

    assert Storage.get_cell(cell.cell_id).hp < first_hp
  end

  test "exhausting a captured Ankle Snare ends the hold on the next timer pass", %{
    manager: manager,
    now: now,
    player: player
  } do
    assert {:ok, group} = Unit.place(player, :ht_anklesnare, 1, {10, 10})
    target = %{player | character_id: 2, x: 10, y: 10}
    UnitRegistry.register_unit(:player, 2, PlayerState, target, self())

    assert :ok =
             Interpreter.apply_status(:player, 2, :sc_ankle,
               val1: 1,
               val2: group.group_id,
               caster_id: 1,
               duration: 5_000,
               no_avoid: true
             )

    stored = Storage.get(group.group_id)

    state =
      stored.state
      |> Map.put(:trap, %{stored.state.trap | phase: :captured})
      |> Map.put(:caught, {:player, 2})

    Storage.update(%{stored | state: state, visibility: :public})
    [cell] = Storage.get_cells_by_group(group.group_id)

    assert {:ok, %{hp: 0}} =
             Manager.damage_targetable_cell(manager, cell.cell_id, 3_500, {:player, 1})

    assert StatusStorage.has_status?(:player, 2, :sc_ankle)
    Manager.tick(manager, now + 100)
    assert Storage.get(group.group_id) == nil
    refute StatusStorage.has_status?(:player, 2, :sc_ankle)
  end

  test "Talkie Box remains an indestructible attack target after activation", %{
    manager: manager,
    player: player
  } do
    assert {:ok, group} =
             Unit.place(player, :ht_talkiebox, 1, {10, 10}, state: %{message: "Hello"})

    [cell] = Storage.get_cells_by_group(group.group_id)

    assert {:ok, %{hp: 1}} =
             Manager.damage_targetable_cell(manager, cell.cell_id, 9_999, {:player, 1})

    stored = Storage.get(group.group_id)
    state = Map.put(stored.state, :trap, %{stored.state.trap | phase: :used})
    Storage.update(%{stored | state: state})
    assert {:ok, %{hp: 1}} = Manager.targetable_cell(manager, cell.cell_id)

    assert {:ok, %{hp: 1}} =
             Manager.damage_targetable_cell(manager, cell.cell_id, 9_999, {:player, 1})
  end

  test "a trap whose natural deadline meets its exhaustion never returns an item", %{
    manager: manager,
    now: now,
    player: player
  } do
    reject(&Coordinator.drop_items/4)
    allow(Coordinator, self(), manager)

    assert {:ok, group} =
             Unit.place(player, :ht_landmine, 1, {10, 10},
               origin: :normal,
               state: %{paid_return?: true}
             )

    stored = Storage.get(group.group_id)
    Storage.update(%{stored | expires_at: now + 100})
    [cell] = Storage.get_cells_by_group(group.group_id)
    Manager.damage_targetable_cell(manager, cell.cell_id, 3_500, {:player, 1})
    Manager.tick(manager, now + 100)
    assert Storage.get(group.group_id) == nil
  end
end
