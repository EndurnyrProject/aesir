defmodule Aesir.ZoneServer.Mmo.Skills.WzWaterballTest do
  use ExUnit.Case, async: false

  import Mimic

  alias Aesir.ZoneServer.Map.Cell, as: MapCell
  alias Aesir.ZoneServer.Map.LineOfSight
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skills.WzWaterball
  alias Aesir.ZoneServer.Unit.SpatialIndex

  setup do
    Mimic.copy(MapCell)
    Mimic.copy(LineOfSight)
    verify_on_exit!()
  end

  defp group do
    %Group{
      group_id: 1,
      skill_id: 86,
      skill_name: :wz_waterball,
      level: 5,
      caster_id: 100,
      caster_type: :player,
      target_id: 200,
      target_type: :mob,
      map_name: "prontera",
      center: {100, 100},
      interval: 150,
      state: %{water_ball_sequence: true}
    }
  end

  test "is registered as an active ground skill" do
    assert {:ok, definition} = Catalog.by_name(:wz_waterball)
    assert definition.id == 86
    assert definition.target_type == :target_enemy
    assert {:ok, WzWaterball} = Catalog.active_module_for(:wz_waterball)
    assert {:ok, WzWaterball} = Catalog.ground_module_for(:wz_waterball)
  end

  test "applies one water magic hit for a manager-claimed source cell" do
    stub(Combat, :resolve_combatant, fn 100 -> {:ok, %{unit_id: 100}} end)
    stub(SpatialIndex, :get_unit_position, fn :mob, 200 -> {:ok, {101, 100, "prontera"}} end)
    stub(LineOfSight, :clear?, fn "prontera", {100, 100}, {101, 100} -> true end)

    expect(Combat, :apply_skill_unit_damage, fn %{unit_id: 100}, :mob, 200, 86, 5, :water, 250 ->
      :ok
    end)

    assert {:ok, %Group{}} = WzWaterball.on_interval(group(), 0)
  end

  test "expires without spending another source when its caster is unavailable" do
    stub(Combat, :resolve_combatant, fn 100 -> {:error, :not_found} end)
    reject(&Combat.apply_skill_unit_damage/7)

    assert {:expire, %Group{}} = WzWaterball.on_interval(group(), 0)
  end

  test "rejects a cast when the caster is not in a water state" do
    stub(Combat, :resolve_combatant, fn 200 -> {:ok, %{unit_type: :mob}} end)
    stub(MapCell, :water_source, fn "prontera", 100, 100 -> nil end)

    assert {:error, :water_required} =
             WzWaterball.cast(
               %{character_id: 100, map_name: "prontera", x: 100, y: 100},
               {:unit, 200},
               1,
               %{}
             )
  end

  test "does not treat a pending Water Ball token as a caster water state" do
    stub(Combat, :resolve_combatant, fn 200 -> {:ok, %{unit_type: :mob}} end)

    stub(MapCell, :water_source, fn "prontera", 100, 100 ->
      %MapCell.WaterSource{origin: :water_ball, cell_id: 1}
    end)

    assert {:error, :water_required} =
             WzWaterball.cast(
               %{character_id: 100, map_name: "prontera", x: 100, y: 100},
               {:unit, 200},
               1,
               %{}
             )
  end

  test "consumes its already-claimed source without dealing damage when line of sight is blocked" do
    stub(Combat, :resolve_combatant, fn 100 -> {:ok, %{unit_id: 100}} end)
    stub(SpatialIndex, :get_unit_position, fn :mob, 200 -> {:ok, {101, 100, "prontera"}} end)
    stub(LineOfSight, :clear?, fn "prontera", {100, 100}, {101, 100} -> false end)
    reject(&Combat.apply_skill_unit_damage/7)

    assert {:ok, %Group{}} = WzWaterball.on_interval(group(), 0)
  end
end
