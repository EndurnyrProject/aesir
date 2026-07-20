defmodule Aesir.ZoneServer.Mmo.Skills.WzSightblasterTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup
  import Mimic

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.WzSightblaster
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Movement
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  defmodule FixtureUnit do
    def get_entity_info(_state), do: %{stats: %{}}
  end

  setup :setup_ets_tables
  setup :verify_on_exit!

  setup do
    :ok = StatusInterpreter.init()
    :ok
  end

  test "definition matches Renewal data" do
    definition = WzSightblaster.definition()

    assert definition.id == 1006
    assert definition.name == :wz_sightblaster
    assert definition.max_level == 1
    assert definition.target_type == :self
    assert definition.damage_type == :no_damage
    assert definition.damage_kind == :magic
    assert definition.element == :fire
    assert definition.range == 1
    assert definition.splash_radius == 1
    assert definition.knockback == 3
    assert definition.cast_time == [1_280]
    assert definition.fixed_cast_time == [320]
    assert definition.duration == [900_000]
    assert definition.sp_cost == [80]
  end

  test "is available to the active skill interpreter through the catalog" do
    assert {:ok, WzSightblaster} = Catalog.active_module_for(:wz_sightblaster)
  end

  test "cast applies the self status" do
    caster = living_player(1001, 50, 50)
    register(:player, 1001, caster)

    assert {:ok, ^caster} = WzSightblaster.cast(caster, :self, 1, WzSightblaster.definition())
    assert StatusStorage.has_status?(:player, 1001, :sc_sightblaster)
  end

  test "cast immediately triggers an already-adjacent stationary target" do
    caster = living_player(1001, 50, 50)
    target = %{instance_id: 2001, x: 51, y: 50, map_name: "prontera"}
    register(:player, 1001, caster)
    register(:mob, 2001, target)

    expect(Combat, :execute_magic_attack, fn ^caster, 2001, _opts -> :ok end)
    expect(Combat, :knockback, fn :mob, 2001, 50, 50, 3 -> {:ok, {54, 50}} end)

    assert {:ok, ^caster} = WzSightblaster.cast(caster, :self, 1, WzSightblaster.definition())
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
    assert StatusStorage.has_status?(:player, 1001, :sc_sightblaster)
  end

  test "cast ignores an adjacent player without an authoritative snapshot" do
    caster = living_player(1001, 50, 50)
    register(:player, 1001, caster)
    SpatialIndex.add_unit(:player, 2001, 51, 50, "prontera")

    reject(&Combat.execute_magic_attack/3)
    reject(&Combat.knockback/5)

    assert {:ok, ^caster} = WzSightblaster.cast(caster, :self, 1, WzSightblaster.definition())
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

    expect(Combat, :execute_magic_attack, fn ^caster, 2001, _opts -> :ok end)
    expect(Combat, :knockback, fn :mob, 2001, 50, 50, 3 -> {:ok, {54, 50}} end)

    assert :ok = StatusInterpreter.process_tick(:player, 1001, :sc_sightblaster)
    refute StatusStorage.has_status?(:player, 1001, :sc_sightblaster)
  end

  test "movement contact damages, knocks back, and consumes the status" do
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
      assert opts == [skill_id: 1006, skill_level: 1, skill_ratio: 600, element: :fire]
      :ok
    end)

    expect(Combat, :knockback, fn :mob, 2001, 50, 50, 3 ->
      {:ok, {58, 50}}
    end)

    assert :ok = Movement.set_position(:mob, 2001, %{target | x: 51}, "prontera")
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
    assert StatusStorage.has_status?(:player, 1001, :sc_sightblaster)
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
