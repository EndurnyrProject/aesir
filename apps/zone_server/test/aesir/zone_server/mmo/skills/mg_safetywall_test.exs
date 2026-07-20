defmodule Aesir.ZoneServer.Mmo.Skills.MgSafetywallTest do
  use ExUnit.Case, async: false
  import Mimic

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skills.MgSafetywall
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  @caster_id 1000
  @map_name "prontera"
  @center {150, 150}

  defp group(level, group_id \\ 7) do
    %Group{
      group_id: group_id,
      skill_id: 12,
      skill_name: :mg_safetywall,
      level: level,
      caster_id: @caster_id,
      caster_type: :player,
      map_name: @map_name,
      center: @center,
      cells: [@center],
      interval: 1_000,
      state: %{}
    }
  end

  defp stub_living_units do
    stub(UnitRegistry, :get_unit, fn :player, player_id ->
      state = %PlayerState{
        character_id: player_id,
        action_state: :idle,
        stats: %{current_state: %{hp: 1}}
      }

      {:ok, {PlayerState, state, self()}}
    end)
  end

  describe "skill data" do
    test "mg_safetywall loads from the catalog as a no-damage ground skill" do
      assert {:ok, definition} = Catalog.by_id(12)
      assert definition.name == :mg_safetywall
      assert definition.target_type == :ground
      assert definition.damage_type == :no_damage
      assert definition.element == :ghost
      assert definition.range == 9
      assert definition.max_level == 10

      assert definition.cast_time ==
               [3200, 2880, 2560, 2240, 1920, 1600, 1280, 960, 640, 320]

      assert definition.fixed_cast_time == [800, 720, 640, 560, 480, 400, 320, 240, 160, 80]

      assert definition.unit_duration ==
               [5000, 10_000, 15_000, 20_000, 25_000, 30_000, 35_000, 40_000, 45_000, 50_000]

      assert definition.sp_cost == [30, 30, 30, 35, 35, 35, 40, 40, 40, 40]
    end

    test "consumes one Blue Gemstone (item 717)" do
      assert {:ok, %{item_cost: [%{id: 717, amount: 1}]}} = Catalog.by_id(12)
    end

    test "is registered as both an active and a ground skill" do
      assert {:ok, MgSafetywall} = Catalog.active_module_for(:mg_safetywall)
      assert {:ok, MgSafetywall} = Catalog.ground_module_for(:mg_safetywall)
    end
  end

  describe "on_place/1" do
    test "places the single target cell with the level's duration and shared budget" do
      stub(UnitRegistry, :get_unit_info, fn :player, @caster_id ->
        {:ok, %{stats: %{int: 50, base_level: 70, max_sp: 200}}}
      end)

      assert {:ok, placement} = MgSafetywall.on_place(group(3))
      assert placement.cells == [@center]
      assert placement.duration == 15_000

      # hits_remaining = level + 1
      assert placement.state.hits_remaining == 4
      # shield_hp = 300*3 + 65*(50 + 70) + 200 = 900 + 7800 + 200 = 8900
      assert placement.state.shield_hp == 8_900
    end
  end

  describe "on_interval/2" do
    test "grants sc_safetywall to every occupant who does not already have it" do
      test_pid = self()
      stub_living_units()

      stub(SpatialIndex, :get_all_units_in_range, fn @map_name, 150, 150, 0 ->
        [{:player, @caster_id}, {:player, 2001}]
      end)

      stub(StatusStorage, :has_status?, fn _unit_type, _unit_id, :sc_safetywall -> false end)

      stub(StatusInterpreter, :apply_status, fn unit_type, target_id, :sc_safetywall, params ->
        send(test_pid, {:granted, unit_type, target_id, params})
        :ok
      end)

      assert {:ok, %Group{}} = MgSafetywall.on_interval(group(5, 7), 0)

      assert_received {:granted, :player, @caster_id, params}
      assert params[:val1] == 5
      assert params[:val2] == 7

      assert_received {:granted, :player, 2001, _params}
    end

    test "ignores targetable skill-unit cells on the wall cell" do
      test_pid = self()
      stub_living_units()

      stub(SpatialIndex, :get_all_units_in_range, fn @map_name, 150, 150, 0 ->
        [{:skill_unit, 777}, {:player, 2001}]
      end)

      stub(StatusStorage, :has_status?, fn _unit_type, _unit_id, :sc_safetywall -> false end)

      stub(StatusInterpreter, :apply_status, fn unit_type, target_id, :sc_safetywall, _params ->
        send(test_pid, {:granted, unit_type, target_id})
        :ok
      end)

      assert {:ok, %Group{}} = MgSafetywall.on_interval(group(5, 7), 0)

      assert_received {:granted, :player, 2001}
      refute_received {:granted, :skill_unit, _}
    end

    test "does not re-grant to an occupant who already carries the buff" do
      stub_living_units()

      stub(SpatialIndex, :get_all_units_in_range, fn @map_name, 150, 150, 0 ->
        [{:player, @caster_id}]
      end)

      stub(StatusStorage, :has_status?, fn :player, @caster_id, :sc_safetywall -> true end)

      reject(&StatusInterpreter.apply_status/4)

      assert {:ok, %Group{}} = MgSafetywall.on_interval(group(5, 7), 0)
    end

    test "does not grant the wall status to a corpse" do
      corpse = %PlayerState{action_state: :dead, stats: %{current_state: %{hp: 0}}}

      stub(SpatialIndex, :get_all_units_in_range, fn @map_name, 150, 150, 0 ->
        [{:player, 2001}]
      end)

      stub(UnitRegistry, :get_unit, fn :player, 2001 ->
        {:ok, {PlayerState, corpse, self()}}
      end)

      reject(&StatusStorage.has_status?/3)
      reject(&StatusInterpreter.apply_status/4)

      assert {:ok, %Group{}} = MgSafetywall.on_interval(group(5, 7), 0)
    end
  end
end
