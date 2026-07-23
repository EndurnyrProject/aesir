defmodule Aesir.ZoneServer.Mmo.Skills.Knight.KnChargeatkTest do
  use ExUnit.Case, async: false

  import Mimic

  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.ForcedMovement
  alias Aesir.ZoneServer.Mmo.Skills.Knight.KnChargeatk
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @target_id 6001

  setup :verify_on_exit!

  setup do
    Mimic.copy(Cell)
    Mimic.copy(Combat)
    Mimic.copy(SpatialIndex)
    Mimic.copy(UnitRegistry)
    :ok
  end

  defp caster(x, y), do: %PlayerState{character_id: 4000, map_name: "prontera", x: x, y: y}

  defp stub_target_at(x, y) do
    stub(UnitRegistry, :unit_exists?, fn :mob, @target_id -> true end)
    stub(SpatialIndex, :get_unit_position, fn :mob, @target_id -> {:ok, {x, y, "prontera"}} end)
  end

  defp stub_clear_terrain do
    stub(Cell, :traversable?, fn "prontera", _x, _y -> true end)
    stub(Cell, :step_traversable?, fn "prontera", _prev, _cell -> true end)
  end

  defp stub_recording_strike do
    stub(Combat, :execute_skill_attack, fn _caster, @target_id, opts ->
      send(self(), {:strike, opts})
      :ok
    end)

    stub(Combat, :knockback, fn unit_type, target_id, from_x, from_y, distance ->
      send(self(), {:knockback, unit_type, target_id, from_x, from_y, distance})
      {:ok, {from_x, from_y}}
    end)
  end

  defp stub_strike_guard do
    stub(Combat, :execute_skill_attack, fn _caster, _target_id, _opts ->
      send(self(), :struck)
      :ok
    end)
  end

  test "declares Charge Attack id, cost, range and knockback" do
    {:ok, definition} = Catalog.by_id(1001)

    assert definition.name == :kn_chargeatk
    assert definition.display_name == "Charge Attack"
    assert definition.max_level == 1
    assert definition.target_type == :target_enemy
    assert definition.range == 14
    assert definition.knockback == 2
    assert definition.sp_cost == [40]
  end

  test "charges adjacent to the target, strikes for 700% and knocks it back 2" do
    stub_clear_terrain()
    stub_target_at(15, 10)
    stub_recording_strike()

    {:ok, definition} = Catalog.by_id(1001)

    assert {:ok, updated} = KnChargeatk.cast(caster(5, 10), {:unit, @target_id}, 1, definition)

    assert %ForcedMovement{map_name: "prontera", x: 14, y: 10} = updated.pending_forced_movement

    assert_received {:strike, opts}
    assert opts[:skill_ratio] == 700
    assert opts[:skip_range] == true

    assert_received {:knockback, :mob, @target_id, 14, 10, 2}
  end

  test "charges along a clear diagonal line and lands adjacent to the target" do
    stub_clear_terrain()
    stub_target_at(15, 15)
    stub_recording_strike()

    {:ok, definition} = Catalog.by_id(1001)

    assert {:ok, updated} = KnChargeatk.cast(caster(5, 5), {:unit, @target_id}, 1, definition)

    assert %ForcedMovement{map_name: "prontera", x: 14, y: 14} = updated.pending_forced_movement

    assert_received {:strike, opts}
    assert opts[:skill_ratio] == 700
    assert_received {:knockback, :mob, @target_id, 14, 14, 2}
  end

  test "a diagonal corner-cut on the line fails the cast with no movement and no strike" do
    stub(Cell, :traversable?, fn "prontera", _x, _y -> true end)

    stub(Cell, :step_traversable?, fn
      "prontera", {5, 5}, {6, 6} -> false
      "prontera", _prev, _cell -> true
    end)

    stub_target_at(15, 15)
    stub_strike_guard()

    {:ok, definition} = Catalog.by_id(1001)

    assert {:error, :path_blocked} =
             KnChargeatk.cast(caster(5, 5), {:unit, @target_id}, 1, definition)

    refute_received :struck
  end

  test "a wall on the line fails the cast with no movement and no strike" do
    stub(Cell, :traversable?, fn "prontera", _x, _y -> true end)

    stub(Cell, :step_traversable?, fn
      "prontera", _prev, {10, 10} -> false
      "prontera", _prev, _cell -> true
    end)

    stub_target_at(15, 10)
    stub_strike_guard()

    {:ok, definition} = Catalog.by_id(1001)

    assert {:error, :path_blocked} =
             KnChargeatk.cast(caster(5, 10), {:unit, @target_id}, 1, definition)

    assert {:error, :path_blocked} =
             KnChargeatk.validate(caster(5, 10), {:unit, @target_id}, 1, definition)

    refute_received :struck
  end

  test "an unwalkable landing cell fails the cast with no movement and no strike" do
    stub(Cell, :traversable?, fn
      "prontera", 14, 10 -> false
      "prontera", _x, _y -> true
    end)

    stub(Cell, :step_traversable?, fn "prontera", _prev, _cell -> true end)

    stub_target_at(15, 10)
    stub_strike_guard()

    {:ok, definition} = Catalog.by_id(1001)

    assert {:error, :invalid_destination} =
             KnChargeatk.cast(caster(5, 10), {:unit, @target_id}, 1, definition)

    refute_received :struck
  end
end
