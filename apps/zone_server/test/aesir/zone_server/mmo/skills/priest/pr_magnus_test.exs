defmodule Aesir.ZoneServer.Mmo.Skills.Priest.PrMagnusTest do
  use ExUnit.Case, async: false

  import Mimic

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skills.Priest.PrMagnus
  alias Aesir.ZoneServer.Unit.SpatialIndex

  setup :verify_on_exit!

  @caster_id 1_000
  @map_name "prontera"
  @center {150, 150}

  defp group(level, cells \\ []) do
    %Group{
      group_id: 1,
      skill_id: 79,
      skill_name: :pr_magnus,
      level: level,
      caster_id: @caster_id,
      caster_type: :player,
      map_name: @map_name,
      center: @center,
      cells: cells
    }
  end

  describe "skill data" do
    test "loads rAthena's cast, cost, catalyst, interval, duration, and hit tables" do
      assert {:ok, definition} = Catalog.by_name(:pr_magnus)
      assert definition.id == 79
      assert definition.target_type == :ground
      assert definition.element == :holy
      assert definition.range == 9
      assert definition.hit_interval == 3_000
      assert definition.unit_duration == Enum.to_list(4_000..13_000//1_000)
      assert definition.sp_cost == Enum.to_list(40..58//2)
      assert definition.cast_time == List.duplicate(4_000, 10)
      assert definition.fixed_cast_time == List.duplicate(1_000, 10)
      assert definition.after_cast_delay == List.duplicate(1_000, 10)
      assert definition.cooldown == List.duplicate(6_000, 10)
      assert definition.item_cost == [%{id: 717, amount: 1}]
    end

    test "is registered as an active ground skill" do
      assert {:ok, PrMagnus} = Catalog.active_module_for(:pr_magnus)
      assert {:ok, PrMagnus} = Catalog.ground_module_for(:pr_magnus)
    end
  end

  describe "on_place/1" do
    test "returns rAthena's exact 33-cell layout with path checking and level duration" do
      assert {:ok, placement} = PrMagnus.on_place(group(10))

      assert MapSet.new(placement.cells) ==
               MapSet.new([
                 {149, 147},
                 {150, 147},
                 {151, 147},
                 {149, 148},
                 {150, 148},
                 {151, 148},
                 {147, 149},
                 {148, 149},
                 {149, 149},
                 {150, 149},
                 {151, 149},
                 {152, 149},
                 {153, 149},
                 {147, 150},
                 {148, 150},
                 {149, 150},
                 {150, 150},
                 {151, 150},
                 {152, 150},
                 {153, 150},
                 {147, 151},
                 {148, 151},
                 {149, 151},
                 {150, 151},
                 {151, 151},
                 {152, 151},
                 {153, 151},
                 {149, 152},
                 {150, 152},
                 {151, 152},
                 {149, 153},
                 {150, 153},
                 {151, 153}
               ])

      assert length(placement.cells) == 33
      assert placement.interval == 3_000
      assert placement.duration == 13_000
      assert placement.path_check
    end
  end

  describe "on_interval/2" do
    test "hits only targets on the 33-cell footprint and gives the +30 ratio only to undead and demon" do
      test_pid = self()
      stub(Combat, :resolve_combatant, fn @caster_id -> {:ok, %{unit_id: @caster_id}} end)

      stub(Combat, :resolve_combatant, fn
        :mob, 2_001 -> {:ok, %{race: :formless, element: {:neutral, 1}}}
        :mob, 2_002 -> {:ok, %{race: :undead, element: {:neutral, 1}}}
        :mob, 2_003 -> {:ok, %{race: :demon, element: {:fire, 1}}}
      end)

      stub(Combat, :splash_targets, fn @map_name, @center, 3, @caster_id ->
        [{:mob, 2_001}, {:mob, 2_002}, {:mob, 2_003}, {:mob, 2_004}]
      end)

      stub(SpatialIndex, :get_unit_position, fn
        :mob, 2_001 -> {:ok, {150, 150, @map_name}}
        :mob, 2_002 -> {:ok, {147, 149, @map_name}}
        :mob, 2_003 -> {:ok, {151, 153, @map_name}}
        :mob, 2_004 -> {:ok, {147, 147, @map_name}}
      end)

      stub(Combat, :apply_skill_unit_damage, fn
        %{unit_id: @caster_id}, :mob, target_id, 79, 10, :holy, ratio, hit_count: 10 ->
          send(test_pid, {:hit, target_id, ratio})
          :ok
      end)

      assert {:ok, %Group{}} =
               PrMagnus.on_interval(group(10, [{150, 150}, {147, 149}, {151, 153}]), 0)

      assert_received {:hit, 2_001, 100}
      assert_received {:hit, 2_002, 130}
      assert_received {:hit, 2_003, 130}
      refute_received {:hit, 2_004, _}
    end

    test "does not damage candidates whose combatant has disappeared" do
      stub(Combat, :resolve_combatant, fn @caster_id -> {:ok, %{unit_id: @caster_id}} end)
      stub(Combat, :resolve_combatant, fn :mob, 2_001 -> {:error, :target_not_found} end)

      stub(Combat, :splash_targets, fn @map_name, @center, 3, @caster_id -> [{:mob, 2_001}] end)
      stub(SpatialIndex, :get_unit_position, fn :mob, 2_001 -> {:ok, {150, 150, @map_name}} end)
      reject(&Combat.apply_skill_unit_damage/8)

      assert {:ok, %Group{}} = PrMagnus.on_interval(group(10, [@center]), 0)
    end
  end
end
