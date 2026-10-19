defmodule Aesir.ZoneServer.Mmo.Skills.Wizard.WzSightblasterTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup
  import Mimic

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Cell
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.Trap
  alias Aesir.ZoneServer.Mmo.Skills.Wizard.WzSightblaster
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Movement
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  defmodule FixtureUnit do
    def get_entity_info(state) do
      %{stats: %{}, magic_reduction: Map.get(state, :magic_reduction, 0)}
    end
  end

  setup :setup_ets_tables
  setup :verify_on_exit!

  setup do
    :ok = StatusInterpreter.init()
    :ok
  end

  @tag game_mode: :renewal

  test "definition matches Renewal data" do
    definition = WzSightblaster.definition()

    assert definition.max_level == 1
    assert definition.target_type == :self
    assert definition.damage_type == :damage
    assert definition.damage_kind == :magic
    assert definition.element == :fire
    assert definition.splash_radius == 1
    assert definition.knockback == 3
    assert definition.cast_time == [1_280]
    assert definition.fixed_cast_time == [320]
    assert definition.duration == [900_000]
    assert definition.sp_cost == [80]
    assert definition.range == 0
    assert WzSightblaster.definition(:pre_renewal).sp_cost == [40]
    assert WzSightblaster.definition(:pre_renewal).duration == [120_000]
    assert WzSightblaster.definition(:pre_renewal).cast_time == [2000]
    assert WzSightblaster.definition(:pre_renewal).fixed_cast_time == []
  end

  test "cast applies the self status" do
    caster = living_player(1001, 50, 50)
    register(:player, 1001, caster)

    assert {:ok, ^caster} = WzSightblaster.cast(caster, :self, 1, WzSightblaster.definition())
    assert StatusStorage.has_status?(:player, 1001, :sc_sightblaster)
  end

  test "the first tick strikes an already-adjacent stationary target" do
    caster = living_player(1001, 50, 50)
    target = %{instance_id: 2001, x: 51, y: 50, map_name: "prontera"}
    register(:player, 1001, caster)
    register(:mob, 2001, target)

    expect(Combat, :execute_magic_attack, fn ^caster, 2001, _opts ->
      {:ok, %{hit?: true, damage: 100}}
    end)

    expect(Combat, :knockback, fn :mob, 2001, 50, 50, 3 -> {:ok, {54, 50}} end)

    assert {:ok, ^caster} = WzSightblaster.cast(caster, :self, 1, WzSightblaster.definition())
    assert StatusStorage.has_status?(:player, 1001, :sc_sightblaster)
    assert :ok = StatusInterpreter.process_tick(:player, 1001, :sc_sightblaster)
    refute StatusStorage.has_status?(:player, 1001, :sc_sightblaster)
  end

  test "cast ignores an adjacent corpse" do
    caster = living_player(1001, 50, 50)

    corpse = %PlayerState{
      character_id: 2001,
      x: 51,
      y: 50,
      map_name: "prontera",
      action_state: :dead,
      stats: %{current_state: %{hp: 0}}
    }

    register(:player, 1001, caster)
    register(:player, 2001, corpse)

    reject(&Combat.execute_magic_attack/3)
    reject(&Combat.knockback/5)

    assert {:ok, ^caster} = WzSightblaster.cast(caster, :self, 1, WzSightblaster.definition())
    assert :ok = StatusInterpreter.process_tick(:player, 1001, :sc_sightblaster)
    assert StatusStorage.has_status?(:player, 1001, :sc_sightblaster)
  end

  test "cast ignores an adjacent player without an authoritative snapshot" do
    caster = living_player(1001, 50, 50)
    register(:player, 1001, caster)
    SpatialIndex.add_unit(:player, 2001, 51, 50, "prontera")

    reject(&Combat.execute_magic_attack/3)
    reject(&Combat.knockback/5)

    assert {:ok, ^caster} = WzSightblaster.cast(caster, :self, 1, WzSightblaster.definition())
    assert :ok = StatusInterpreter.process_tick(:player, 1001, :sc_sightblaster)
    assert StatusStorage.has_status?(:player, 1001, :sc_sightblaster)
  end

  test "status tick triggers a stationary target that enters range without movement dispatch" do
    caster = living_player(1001, 50, 50)
    target = %{instance_id: 2001, x: 55, y: 50, map_name: "prontera"}
    register(:player, 1001, caster)
    register(:mob, 2001, target)

    :ok =
      StatusInterpreter.apply_status(:player, 1001, :sc_sightblaster,
        caster_id: 1001,
        val1: 1
      )

    :ok = SpatialIndex.update_unit_position(:mob, 2001, 51, 50, "prontera")

    expect(Combat, :execute_magic_attack, fn ^caster, 2001, _opts ->
      {:ok, %{hit?: true, damage: 100}}
    end)

    expect(Combat, :knockback, fn :mob, 2001, 50, 50, 3 -> {:ok, {54, 50}} end)

    assert :ok = StatusInterpreter.process_tick(:player, 1001, :sc_sightblaster)
    refute StatusStorage.has_status?(:player, 1001, :sc_sightblaster)
  end

  @tag game_mode: :renewal

  test "a tick after movement damages, knocks back, and consumes the status" do
    caster = living_player(1001, 50, 50)
    target = %{instance_id: 2001, x: 55, y: 50, map_name: "prontera", movement_state: :moving}
    register(:player, 1001, caster)
    register(:mob, 2001, target)

    :ok =
      StatusInterpreter.apply_status(:player, 1001, :sc_sightblaster,
        caster_id: 1001,
        val1: 1
      )

    expect(Combat, :execute_magic_attack, fn ^caster, 2001, opts ->
      assert opts == [
               skill_id: 1006,
               skill_level: 1,
               skill_ratio: 600,
               element: :fire,
               report_hit: true
             ]

      {:ok, %{hit?: true, damage: 100}}
    end)

    expect(Combat, :knockback, fn :mob, 2001, 50, 50, 3 ->
      {:ok, {58, 50}}
    end)

    assert :ok = Movement.set_position(:mob, 2001, %{target | x: 51}, "prontera")
    assert :ok = StatusInterpreter.process_tick(:player, 1001, :sc_sightblaster)
    refute StatusStorage.has_status?(:player, 1001, :sc_sightblaster)
  end

  test "a reflected contact keeps the status armed without knocking the reflector back" do
    caster = living_player(1001, 50, 50)
    target = %{instance_id: 2001, x: 55, y: 50, map_name: "prontera", movement_state: :moving}
    register(:player, 1001, caster)
    register(:mob, 2001, target)

    :ok =
      StatusInterpreter.apply_status(:player, 1001, :sc_sightblaster,
        caster_id: 1001,
        val1: 1
      )

    expect(Combat, :execute_magic_attack, fn ^caster, 2001, _opts ->
      {:ok, %{hit?: false, damage: 0}}
    end)

    reject(&Combat.knockback/5)

    assert :ok = Movement.set_position(:mob, 2001, %{target | x: 51}, "prontera")
    assert :ok = StatusInterpreter.process_tick(:player, 1001, :sc_sightblaster)
    assert StatusStorage.has_status?(:player, 1001, :sc_sightblaster)
  end

  test "a missed contact on a magic-immune player keeps the status armed without knockback" do
    caster = living_player(1001, 50, 50)
    immune = Map.put(living_player(2001, 55, 50), :magic_reduction, 100)
    register(:player, 1001, caster)
    register(:player, 2001, immune)

    :ok =
      StatusInterpreter.apply_status(:player, 1001, :sc_sightblaster,
        caster_id: 1001,
        val1: 1
      )

    expect(Combat, :execute_magic_attack, fn ^caster, 2001, _opts ->
      {:ok, %{hit?: false, damage: 0}}
    end)

    reject(&Combat.knockback/5)

    assert :ok = Movement.set_position(:player, 2001, %{immune | x: 51}, "prontera")
    assert :ok = StatusInterpreter.process_tick(:player, 1001, :sc_sightblaster)
    assert StatusStorage.has_status?(:player, 1001, :sc_sightblaster)
  end

  test "a partially magic-resistant player that takes the hit is still knocked back" do
    caster = living_player(1001, 50, 50)
    resistant = Map.put(living_player(2001, 55, 50), :magic_reduction, 99)
    register(:player, 1001, caster)
    register(:player, 2001, resistant)

    :ok =
      StatusInterpreter.apply_status(:player, 1001, :sc_sightblaster,
        caster_id: 1001,
        val1: 1
      )

    expect(Combat, :execute_magic_attack, fn ^caster, 2001, _opts ->
      {:ok, %{hit?: true, damage: 1}}
    end)

    expect(Combat, :knockback, fn :player, 2001, 50, 50, 3 -> {:ok, {58, 50}} end)

    assert :ok = Movement.set_position(:player, 2001, %{resistant | x: 51}, "prontera")
    assert :ok = StatusInterpreter.process_tick(:player, 1001, :sc_sightblaster)
    refute StatusStorage.has_status?(:player, 1001, :sc_sightblaster)
  end

  test "non-damaging contact keeps the status armed" do
    caster = living_player(1001, 50, 50)
    target = %{instance_id: 2001, x: 55, y: 50, map_name: "prontera", movement_state: :moving}
    register(:player, 1001, caster)
    register(:mob, 2001, target)

    :ok =
      StatusInterpreter.apply_status(:player, 1001, :sc_sightblaster,
        caster_id: 1001,
        val1: 1
      )

    expect(Combat, :execute_magic_attack, fn ^caster, 2001, _opts -> {:error, :invalid_target} end)

    reject(&Combat.knockback/5)

    assert :ok = Movement.set_position(:mob, 2001, %{target | x: 51}, "prontera")
    assert :ok = StatusInterpreter.process_tick(:player, 1001, :sc_sightblaster)
    assert StatusStorage.has_status?(:player, 1001, :sc_sightblaster)
  end

  test "a contact the caster's own Gravitation Field suppressed keeps the status armed" do
    caster = living_player(1001, 50, 50)
    target = %{instance_id: 2001, x: 55, y: 50, map_name: "prontera", movement_state: :moving}
    register(:player, 1001, caster)
    register(:mob, 2001, target)

    :ok =
      StatusInterpreter.apply_status(:player, 1001, :sc_sightblaster,
        caster_id: 1001,
        val1: 1
      )

    expect(Combat, :execute_magic_attack, fn ^caster, 2001, _opts -> {:ok, :suppressed} end)

    reject(&Combat.knockback/5)

    assert :ok = Movement.set_position(:mob, 2001, %{target | x: 51}, "prontera")
    assert :ok = StatusInterpreter.process_tick(:player, 1001, :sc_sightblaster)
    assert StatusStorage.has_status?(:player, 1001, :sc_sightblaster)
  end

  test "an adjacent enemy is not struck before the first 20 ms tick" do
    caster = living_player(1001, 50, 50)
    target = %{instance_id: 2001, x: 51, y: 50, map_name: "prontera"}
    register(:player, 1001, caster)
    register(:mob, 2001, target)
    reject(&Combat.execute_magic_attack/3)

    assert {:ok, ^caster} = WzSightblaster.cast(caster, :self, 1, WzSightblaster.definition())
    assert StatusStorage.has_status?(:player, 1001, :sc_sightblaster)
    instance = StatusStorage.get_status(:player, 1001, :sc_sightblaster)
    assert instance.next_tick_at == instance.started_at + 20
  end

  test "one tick strikes every adjacent enemy in block order before consuming the status" do
    caster = living_player(1001, 50, 50)
    register(:player, 1001, caster)
    register(:mob, 2001, %{instance_id: 2001, x: 51, y: 50, map_name: "prontera"})
    register(:mob, 2002, %{instance_id: 2002, x: 50, y: 51, map_name: "prontera"})

    :ok =
      StatusInterpreter.apply_status(:player, 1001, :sc_sightblaster, caster_id: 1001, val1: 1)

    expect(Combat, :execute_magic_attack, fn ^caster, 2002, _ ->
      {:ok, %{hit?: true, damage: 100}}
    end)

    expect(Combat, :execute_magic_attack, fn ^caster, 2001, _ ->
      {:ok, %{hit?: true, damage: 100}}
    end)

    stub(Combat, :knockback, fn :mob, _, 50, 50, 3 -> {:ok, {54, 50}} end)

    assert :ok = StatusInterpreter.process_tick(:player, 1001, :sc_sightblaster)
    refute StatusStorage.has_status?(:player, 1001, :sc_sightblaster)
  end

  test "entering the radius does not strike until a status tick" do
    caster = living_player(1001, 50, 50)
    target = %{instance_id: 2001, x: 55, y: 50, map_name: "prontera", movement_state: :moving}
    register(:player, 1001, caster)
    register(:mob, 2001, target)

    :ok =
      StatusInterpreter.apply_status(:player, 1001, :sc_sightblaster, caster_id: 1001, val1: 1)

    reject(&Combat.execute_magic_attack/3)

    assert :ok = Movement.set_position(:mob, 2001, %{target | x: 51}, "prontera")
    assert StatusStorage.has_status?(:player, 1001, :sc_sightblaster)
  end

  test "a trap strike keeps the status and lifts immunity only until the next tick" do
    caster = living_player(1001, 50, 50)
    register(:player, 1001, caster)

    group = %Group{
      group_id: 10,
      skill_id: 116,
      skill_name: :ht_landmine,
      caster_type: :mob,
      caster_id: 900,
      map_name: "prontera",
      cells: [{51, 50}]
    }

    cell = %Cell{cell_id: 2001, group_id: 10, map_name: "prontera", x: 51, y: 50, hp: 3_500}
    Storage.insert(group)
    Storage.insert_cell(cell)
    register(:skill_unit, 2001, cell)

    :ok =
      StatusInterpreter.apply_status(:player, 1001, :sc_sightblaster, caster_id: 1001, val1: 1)

    expect(Combat, :execute_magic_attack, fn ^caster, 2001, _ ->
      Storage.delete_cell(2001)
      Storage.delete(10)
      {:ok, %{hit?: true, damage: 1}}
    end)

    stub(Combat, :knockback, fn :skill_unit, 2001, 50, 50, 3 -> :ok end)

    assert :ok = StatusInterpreter.process_tick(:player, 1001, :sc_sightblaster)

    assert %{state: %{trap_immunity: false}} =
             StatusStorage.get_status(:player, 1001, :sc_sightblaster)

    SpatialIndex.remove_unit(:skill_unit, 2001)
    assert :ok = StatusInterpreter.process_tick(:player, 1001, :sc_sightblaster)

    assert %{state: %{trap_immunity: true}} =
             StatusStorage.get_status(:player, 1001, :sc_sightblaster)
  end

  test "an armed Sight Blaster refuses a monster's trap trigger" do
    caster = living_player(1001, 50, 50)
    register(:player, 1001, caster)

    group = %Group{
      group_id: 10,
      skill_id: 116,
      skill_name: :ht_landmine,
      caster_type: :mob,
      caster_id: 900,
      map_name: "prontera",
      cells: [{51, 50}]
    }

    :ok =
      StatusInterpreter.apply_status(:player, 1001, :sc_sightblaster, caster_id: 1001, val1: 1)

    refute Trap.enemy?(group, {:player, 1001})
  end

  test "trap damage delivery also respects immunity after another unit triggered the trap" do
    caster = living_player(1001, 50, 50)
    register(:player, 1001, caster)

    :ok =
      StatusInterpreter.apply_status(:player, 1001, :sc_sightblaster, caster_id: 1001, val1: 1)

    attacker = %{unit_type: :mob, unit_id: 900}
    target = %{unit_type: :player, unit_id: 1001}

    assert {:error, :target_trap_immune} =
             Targeting.validate_delivery(attacker, target, 116, :unit)

    assert :ok = Targeting.validate_delivery(attacker, target, 116, :direct)
  end

  test "an Ice Wall hit consumes the status after the rest of the sweep" do
    caster = living_player(1001, 50, 50)
    register(:player, 1001, caster)

    group = %Group{
      group_id: 10,
      skill_id: 87,
      skill_name: :wz_icewall,
      caster_type: :player,
      caster_id: 1001,
      map_name: "prontera",
      cells: [{51, 50}]
    }

    cell = %Cell{cell_id: 2001, group_id: 10, map_name: "prontera", x: 51, y: 50, hp: 400}
    Storage.insert(group)
    Storage.insert_cell(cell)
    register(:skill_unit, 2001, cell)
    register(:mob, 2002, %{instance_id: 2002, x: 50, y: 51, map_name: "prontera"})

    :ok =
      StatusInterpreter.apply_status(:player, 1001, :sc_sightblaster, caster_id: 1001, val1: 1)

    expect(Combat, :execute_magic_attack, fn ^caster, 2001, _ ->
      {:ok, %{hit?: true, damage: 100}}
    end)

    expect(Combat, :execute_magic_attack, fn ^caster, 2002, _ ->
      assert %{state: %{trap_immunity: false}} =
               StatusStorage.get_status(:player, 1001, :sc_sightblaster)

      {:ok, %{hit?: false, damage: 0}}
    end)

    expect(Combat, :knockback, fn :skill_unit, 2001, 50, 50, 3 -> :ok end)

    assert :ok = StatusInterpreter.process_tick(:player, 1001, :sc_sightblaster)
    refute StatusStorage.has_status?(:player, 1001, :sc_sightblaster)
  end

  test "a tick skips a hidden adjacent enemy but reaches it after Hiding ends" do
    caster = living_player(1001, 50, 50)
    register(:player, 1001, caster)
    register(:mob, 2001, %{instance_id: 2001, x: 51, y: 50, map_name: "prontera"})
    :ok = StatusStorage.apply_status(:mob, 2001, :sc_hiding, val1: 1)

    :ok =
      StatusInterpreter.apply_status(:player, 1001, :sc_sightblaster, caster_id: 1001, val1: 1)

    test_pid = self()

    stub(Combat, :execute_magic_attack, fn ^caster, 2001, _ ->
      send(test_pid, :struck)
      {:ok, %{hit?: true, damage: 100}}
    end)

    stub(Combat, :knockback, fn :mob, 2001, 50, 50, 3 -> {:ok, {54, 50}} end)

    assert :ok = StatusInterpreter.process_tick(:player, 1001, :sc_sightblaster)
    assert StatusStorage.has_status?(:player, 1001, :sc_sightblaster)
    refute_received :struck

    :ok = StatusStorage.remove_status(:mob, 2001, :sc_hiding)
    assert :ok = StatusInterpreter.process_tick(:player, 1001, :sc_sightblaster)
    refute StatusStorage.has_status?(:player, 1001, :sc_sightblaster)
    assert_received :struck
  end

  defp register(unit_type, unit_id, state) do
    :ok = UnitRegistry.register_unit(unit_type, unit_id, FixtureUnit, state, nil)
    :ok = SpatialIndex.add_unit(unit_type, unit_id, state.x, state.y, state.map_name)
  end

  defp living_player(character_id, x, y) do
    %PlayerState{
      character_id: character_id,
      x: x,
      y: y,
      map_name: "prontera",
      action_state: :idle,
      movement_state: :standing,
      stats: %{current_state: %{hp: 100}}
    }
  end
end
