defmodule Aesir.ZoneServer.Mmo.Skills.Wizard.WzWaterballTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup
  import Mimic

  alias Aesir.Net.SkillUnitDespawn
  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.Cell, as: MapCell
  alias Aesir.ZoneServer.Map.GatType
  alias Aesir.ZoneServer.Map.LineOfSight
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.Skills.Sage.SaDeluge
  alias Aesir.ZoneServer.Mmo.Skills.Sage.SaLandprotector
  alias Aesir.ZoneServer.Mmo.Skills.Wizard.WzWaterball
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables

  setup do
    Mimic.copy(MapCell)
    Mimic.copy(LineOfSight)
    verify_on_exit!()
  end

  defp start_manager do
    manager =
      start_supervised!(
        {Manager,
         [
           name: nil,
           schedule_tick: fn _pid, _interval -> :ok end,
           unit_available?: fn _unit_type, _unit_id, _map_name -> true end
         ]}
      )

    Process.put({Manager, :server}, manager)
    manager
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

  defp stub_living_target do
    stub(UnitRegistry, :get_unit, fn :mob, 200 ->
      {:ok, {MobState, struct(MobState, %{hp: 1, is_dead: false}), self()}}
    end)
  end

  test "is registered as an active ground skill" do
    assert {:ok, definition} = Catalog.by_name(:wz_waterball)
    assert definition.id == 86
    assert definition.target_type == :target_enemy
    assert {:ok, WzWaterball} = Catalog.active_module_for(:wz_waterball)
    assert {:ok, WzWaterball} = Catalog.ground_module_for(:wz_waterball)
  end

  test "applies one water magic hit for a manager-claimed source cell" do
    stub_living_target()
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

  test "expires when its target leaves the map" do
    stub(Combat, :resolve_combatant, fn 100 -> {:ok, %{unit_id: 100}} end)
    stub(SpatialIndex, :get_unit_position, fn :mob, 200 -> {:ok, {101, 100, "geffen"}} end)
    reject(&Combat.apply_skill_unit_damage/7)

    assert {:expire, %Group{}} = WzWaterball.on_interval(group(), 0)
  end

  test "excludes water sources standing on a land protector" do
    manager = start_manager()

    :ok =
      Storage.insert(%Group{
        group_id: 99,
        skill_id: 288,
        skill_name: :sa_landprotector,
        level: 1,
        caster_id: 500,
        caster_type: :player,
        map_name: "prontera",
        center: {99, 100},
        cells: for(y <- 99..101, do: {99, y}),
        interval: 1_000,
        expires_at: 1_000_000,
        state: %{land_protector: true}
      })

    stub(Combat, :resolve_combatant, fn 200 -> {:ok, %{unit_type: :mob}} end)

    stub(MapCell, :water_source, fn "prontera", _x, _y ->
      %MapCell.WaterSource{origin: :base, cell_id: nil}
    end)

    allow(MapCell, self(), manager)

    assert {:ok, _caster} =
             WzWaterball.cast(
               %{character_id: 100, map_name: "prontera", x: 100, y: 100},
               {:unit, 200},
               2,
               %{}
             )

    [%Group{group_id: group_id, skill_name: :wz_waterball}] =
      Storage.all() |> Enum.reject(&(&1.group_id == 99))

    sources = group_id |> Storage.get_cells_by_group() |> Enum.map(&{&1.x, &1.y})
    assert Enum.sort(sources) == for(x <- 100..101, y <- 99..101, do: {x, y})
  end

  test "rejects a cast when the caster's water cell sits on a land protector" do
    :ok =
      Storage.insert(%Group{
        group_id: 99,
        skill_id: 288,
        skill_name: :sa_landprotector,
        level: 1,
        caster_id: 500,
        caster_type: :player,
        map_name: "prontera",
        center: {100, 100},
        cells: [{100, 100}],
        interval: 1_000,
        expires_at: 1_000_000,
        state: %{land_protector: true}
      })

    stub(Combat, :resolve_combatant, fn 200 -> {:ok, %{unit_type: :mob}} end)

    stub(MapCell, :water_source, fn "prontera", 100, 100 ->
      %MapCell.WaterSource{origin: :base, cell_id: nil}
    end)

    assert {:error, :water_required} =
             WzWaterball.cast(
               %{character_id: 100, map_name: "prontera", x: 100, y: 100},
               {:unit, 200},
               1,
               %{}
             )
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

  test "signals a skipped shot without dealing damage when line of sight is blocked" do
    stub_living_target()
    stub(Combat, :resolve_combatant, fn 100 -> {:ok, %{unit_id: 100}} end)
    stub(SpatialIndex, :get_unit_position, fn :mob, 200 -> {:ok, {101, 100, "prontera"}} end)
    stub(LineOfSight, :clear?, fn "prontera", {100, 100}, {101, 100} -> false end)
    reject(&Combat.apply_skill_unit_damage/7)

    assert {:ok, %Group{state: %{water_ball_fired: false}}} = WzWaterball.on_interval(group(), 0)
  end

  test "marks a fired shot so the manager consumes exactly one charge" do
    stub_living_target()
    stub(Combat, :resolve_combatant, fn 100 -> {:ok, %{unit_id: 100}} end)
    stub(SpatialIndex, :get_unit_position, fn :mob, 200 -> {:ok, {101, 100, "prontera"}} end)
    stub(LineOfSight, :clear?, fn "prontera", {100, 100}, {101, 100} -> true end)
    stub(Combat, :apply_skill_unit_damage, fn _, _, _, _, _, _, _ -> :ok end)

    assert {:ok, %Group{state: %{water_ball_fired: true}}} = WzWaterball.on_interval(group(), 0)
  end

  test "expires without damaging a corpse target" do
    corpse = struct(MobState, %{hp: 0, is_dead: true})
    stub(Combat, :resolve_combatant, fn 100 -> {:ok, %{unit_id: 100}} end)
    stub(UnitRegistry, :get_unit, fn :mob, 200 -> {:ok, {MobState, corpse, self()}} end)
    reject(&SpatialIndex.get_unit_position/2)
    reject(&Combat.apply_skill_unit_damage/7)

    assert {:expire, %Group{}} = WzWaterball.on_interval(group(), 0)
  end

  describe "deluge fields as water sources" do
    test "draws its charge count from the deluge cells surrounding the caster" do
      manager = start_manager()
      put_dry_map()
      place_deluge(manager, 10)

      group_id = cast_water_ball({20, 20}, 2)

      assert length(Storage.get_cells_by_group(group_id)) == 9
    end

    test "claiming a deluge cell consumes exactly that cell and despawns it" do
      manager = start_manager()
      put_dry_map()
      place_deluge(manager, 10)
      [deluge_cell] = deluge_cells_at(10, {20, 20})
      capture_broadcasts(manager)

      cast_water_ball({20, 20}, 1)

      %Group{cells: cells} = Storage.get(10)
      refute {20, 20} in cells
      assert length(cells) == 48
      assert deluge_cells_at(10, {20, 20}) == []
      assert %MapCell.WaterSource{origin: :water_ball} = MapCell.water_source("prontera", 20, 20)

      assert_receive {:packet,
                      %SkillUnitDespawn{
                        group_id: 10,
                        cell_ids: [^deluge_cell],
                        reason: :SKILL_UNIT_DESPAWN_REASON_DESTROYED
                      }}
    end

    test "two water balls racing for one cell claim it exactly once" do
      manager = start_manager()
      put_dry_map()
      place_deluge(manager, 10)

      first = cast_water_ball({20, 20}, 1)
      assert cell_coordinates(first) == [{20, 20}]

      second = cast_water_ball({21, 21}, 2)

      refute {20, 20} in cell_coordinates(second)
      assert length(cell_coordinates(second)) == 8
      assert length(Storage.get(10).cells) == 49 - 1 - 8
    end

    test "a deluge field over natural water does not double-count the shared cells" do
      manager = start_manager()
      put_watery_map()
      place_deluge(manager, 10)

      group_id = cast_water_ball({20, 20}, 2)

      assert length(cell_coordinates(group_id)) == 9
      assert length(Storage.get(10).cells) == 49 - 9
    end

    test "does not claim the deluge cells a land protector covers" do
      manager = start_manager()
      put_dry_map()
      place_deluge(manager, 10)
      place_land_protector(manager, 11, {24, 20})

      group_id = cast_water_ball({20, 20}, 5)

      sources = cell_coordinates(group_id)
      assert Enum.sort(sources) == for(x <- 18..20, y <- 18..22, do: {x, y})
      assert Enum.all?(Storage.get(10).cells, fn {x, _y} -> x < 21 end)
    end
  end

  defp put_watery_map do
    map =
      Enum.reduce(for(x <- 19..21, y <- 19..21, do: {x, y}), MapData.new("prontera", 40, 40), fn
        {x, y}, map -> MapData.set_cell(map, x, y, GatType.water())
      end)

    :ets.insert(EtsTable.table_for(:map_cache), {"prontera", map})
  end

  defp place_land_protector(manager, group_id, center) do
    group = %Group{
      group_id: group_id,
      skill_id: 288,
      skill_name: :sa_landprotector,
      level: 1,
      caster_id: 501,
      caster_type: :player,
      map_name: "prontera",
      center: center,
      interval: 1_000,
      expires_at: 1_000_000
    }

    {:ok, placement} = SaLandprotector.on_place(group)

    :ok =
      Manager.register(manager, %{
        group
        | cells: placement.cells,
          visibility: :public,
          state: placement.state,
          next_tick_at: nil
      })
  end

  defp capture_broadcasts(manager) do
    test = self()

    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, packet ->
      send(test, {:packet, packet})
      :ok
    end)

    allow(Broadcast, test, manager)
  end

  defp deluge_cells_at(group_id, {x, y}) do
    group_id
    |> Storage.get_cells_by_group()
    |> Enum.filter(&(&1.x == x and &1.y == y))
    |> Enum.map(& &1.cell_id)
  end

  defp cast_water_ball({x, y}, level) do
    stub(Combat, :resolve_combatant, fn 200 -> {:ok, %{unit_type: :mob}} end)
    before = water_ball_group_ids()

    assert {:ok, _caster} =
             WzWaterball.cast(
               %{character_id: 100, map_name: "prontera", x: x, y: y},
               {:unit, 200},
               level,
               %{}
             )

    [group_id] = water_ball_group_ids() -- before
    group_id
  end

  defp water_ball_group_ids do
    Storage.all() |> Enum.filter(&(&1.skill_name == :wz_waterball)) |> Enum.map(& &1.group_id)
  end

  defp cell_coordinates(group_id) do
    group_id |> Storage.get_cells_by_group() |> Enum.map(&{&1.x, &1.y})
  end

  defp put_dry_map do
    :ets.insert(EtsTable.table_for(:map_cache), {"prontera", MapData.new("prontera", 40, 40)})
  end

  defp place_deluge(manager, group_id) do
    group = %Group{
      group_id: group_id,
      skill_id: 286,
      skill_name: :sa_deluge,
      level: 1,
      caster_id: 500,
      caster_type: :player,
      map_name: "prontera",
      center: {20, 20},
      interval: 1_000,
      expires_at: 1_000_000
    }

    {:ok, placement} = SaDeluge.on_place(group)

    :ok =
      Manager.register(manager, %{
        group
        | cells: placement.cells,
          visibility: :public,
          state: Map.put(placement.state, :cell_attrs, placement.cell_attrs),
          lifecycle_policy: placement.lifecycle_policy,
          next_tick_at: nil
      })
  end
end
