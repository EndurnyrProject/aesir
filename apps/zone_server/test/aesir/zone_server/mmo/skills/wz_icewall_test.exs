defmodule Aesir.ZoneServer.Mmo.Skills.WzIcewallTest do
  use ExUnit.Case, async: true

  import Mimic

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skills.WzIcewall

  setup :verify_on_exit!

  @caster_id 1000
  @center {150, 150}

  defp group(level) do
    %Group{
      group_id: 1,
      skill_id: 87,
      skill_name: :wz_icewall,
      level: level,
      caster_id: @caster_id,
      caster_type: :player,
      map_name: "prontera",
      center: @center,
      cells: [],
      state: %{}
    }
  end

  test "registers as a water ground skill with canonical costs" do
    assert {:ok, definition} = Catalog.by_id(87)
    assert definition.name == :wz_icewall
    assert definition.target_type == :ground
    assert definition.damage_type == :no_damage
    assert definition.element == :water
    assert definition.sp_cost == List.duplicate(20, 10)

    assert definition.unit_duration == [
             8_000,
             12_000,
             16_000,
             20_000,
             24_000,
             28_000,
             32_000,
             36_000,
             40_000,
             44_000
           ]

    assert {:ok, WzIcewall} = Catalog.active_module_for(:wz_icewall)
    assert {:ok, WzIcewall} = Catalog.ground_module_for(:wz_icewall)
  end

  test "places five directional targetable terrain cells with canonical HP and decay" do
    stub(Combat, :resolve_combatant, fn @caster_id ->
      {:ok, %{position: {148, 148}}}
    end)

    assert {:ok, placement} = WzIcewall.on_place(group(3))

    assert placement.cells == [{152, 148}, {151, 149}, {150, 150}, {149, 151}, {148, 152}]
    assert placement.interval == 1_000
    assert placement.duration == 16_000
    assert placement.path_check
    assert placement.state == %{cell_decay: 50, terrain_source: :icewall}

    assert Enum.all?(placement.cell_attrs, fn {_cell, attrs} ->
             attrs.hp == 800 and attrs.max_hp == 800 and
               attrs.flags == [:targetable, :blocks_movement, :blocks_projectiles] and
               attrs.state == %{terrain_source: :icewall}
           end)
  end

  test "defaults to a horizontal wall when the caster targets its own cell" do
    stub(Combat, :resolve_combatant, fn @caster_id ->
      {:ok, %{position: @center}}
    end)

    assert {:ok, %{cells: cells}} = WzIcewall.on_place(group(1))
    assert cells == [{148, 150}, {149, 150}, {150, 150}, {151, 150}, {152, 150}]
  end
end
