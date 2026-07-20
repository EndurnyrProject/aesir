defmodule Aesir.ZoneServer.Mmo.Skills.Acolyte.AlPneumaTest do
  use ExUnit.Case, async: false
  import Mimic

  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Layout
  alias Aesir.ZoneServer.Mmo.Skills.Acolyte.AlPneuma
  alias Aesir.ZoneServer.Mmo.SkillTree
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  @caster_id 1000
  @map_name "prontera"
  @center {150, 150}
  @footprint Layout.square(@center, 1)

  defp group(level, group_id \\ 9) do
    %Group{
      group_id: group_id,
      skill_id: 25,
      skill_name: :al_pneuma,
      level: level,
      caster_id: @caster_id,
      caster_type: :player,
      map_name: @map_name,
      center: @center,
      cells: @footprint,
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
    test "al_pneuma loads from the catalog as a no-damage ground skill" do
      assert {:ok, definition} = Catalog.by_id(25)
      assert definition.name == :al_pneuma
      assert definition.target_type == :ground
      assert definition.damage_type == :no_damage
      assert definition.max_level == 1
      assert definition.sp_cost == [10]
      assert definition.unit_duration == [10_000]
      assert definition.hit_interval == 1_000
      assert definition.splash_radius == 1
    end

    test "resolves by name" do
      assert {:ok, %{id: 25}} = Catalog.by_name(:al_pneuma)
    end

    test "is registered as both an active and a ground skill" do
      assert {:ok, AlPneuma} = Catalog.active_module_for(:al_pneuma)
      assert {:ok, AlPneuma} = Catalog.ground_module_for(:al_pneuma)
    end

    test "appears in the Acolyte skill tree" do
      {:ok, acolyte_id} = AvailableJobs.job_name_to_id(:acolyte)
      tree = SkillTree.tree_for(acolyte_id)
      assert Map.has_key?(tree, 25)
    end
  end

  describe "on_place/1" do
    test "places the 3x3 footprint with the level's duration and empty state" do
      assert {:ok, placement} = AlPneuma.on_place(group(1))
      assert Enum.sort(placement.cells) == Enum.sort(@footprint)
      assert length(placement.cells) == 9
      assert placement.duration == 10_000
      assert placement.interval == 1_000
      assert placement.state == %{}
    end
  end

  describe "on_interval/2" do
    test "grants sc_pneuma (with the field duration) to every occupant who does not already have it" do
      test_pid = self()
      stub_living_units()

      stub(SpatialIndex, :get_all_units_in_range, fn @map_name, 150, 150, 1 ->
        [{:player, @caster_id}, {:player, 2001}]
      end)

      stub(StatusStorage, :has_status?, fn _unit_type, _unit_id, :sc_pneuma -> false end)

      stub(StatusInterpreter, :apply_status, fn unit_type, target_id, :sc_pneuma, params ->
        send(test_pid, {:granted, unit_type, target_id, params})
        :ok
      end)

      assert {:ok, %Group{}} = AlPneuma.on_interval(group(1, 9), 0)

      assert_received {:granted, :player, @caster_id, params}
      assert params[:val1] == 1
      assert params[:caster_id] == @caster_id
      assert params[:duration] == 10_000

      assert_received {:granted, :player, 2001, _params}
    end

    test "ignores targetable skill-unit cells sharing the footprint" do
      test_pid = self()
      stub_living_units()

      stub(SpatialIndex, :get_all_units_in_range, fn @map_name, 150, 150, 1 ->
        [{:skill_unit, 777}, {:player, 2001}]
      end)

      stub(StatusStorage, :has_status?, fn _unit_type, _unit_id, :sc_pneuma -> false end)

      stub(StatusInterpreter, :apply_status, fn unit_type, target_id, :sc_pneuma, _params ->
        send(test_pid, {:granted, unit_type, target_id})
        :ok
      end)

      assert {:ok, %Group{}} = AlPneuma.on_interval(group(1, 9), 0)

      assert_received {:granted, :player, 2001}
      refute_received {:granted, :skill_unit, _}
    end

    test "does not re-grant to an occupant who already carries the buff" do
      stub_living_units()

      stub(SpatialIndex, :get_all_units_in_range, fn @map_name, 150, 150, 1 ->
        [{:player, @caster_id}]
      end)

      stub(StatusStorage, :has_status?, fn :player, @caster_id, :sc_pneuma -> true end)

      reject(&StatusInterpreter.apply_status/4)

      assert {:ok, %Group{}} = AlPneuma.on_interval(group(1, 9), 0)
    end

    test "does not grant the field status to a corpse" do
      corpse = %PlayerState{action_state: :dead, stats: %{current_state: %{hp: 0}}}

      stub(SpatialIndex, :get_all_units_in_range, fn @map_name, 150, 150, 1 ->
        [{:player, 2001}]
      end)

      stub(UnitRegistry, :get_unit, fn :player, 2001 ->
        {:ok, {PlayerState, corpse, self()}}
      end)

      reject(&StatusStorage.has_status?/3)
      reject(&StatusInterpreter.apply_status/4)

      assert {:ok, %Group{}} = AlPneuma.on_interval(group(1, 9), 0)
    end
  end

  describe "on_out/2" do
    test "removes sc_pneuma from the unit that left the footprint" do
      test_pid = self()

      stub(StatusInterpreter, :remove_status, fn unit_type, unit_id, :sc_pneuma ->
        send(test_pid, {:removed, unit_type, unit_id})
        :ok
      end)

      assert {:ok, %Group{}} = AlPneuma.on_out(group(1), {:player, 2001})

      assert_received {:removed, :player, 2001}
    end
  end
end
