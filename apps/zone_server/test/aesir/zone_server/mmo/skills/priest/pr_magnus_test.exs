defmodule Aesir.ZoneServer.Mmo.Skills.Priest.PrMagnusTest do
  use ExUnit.Case, async: false

  import Mimic

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skills.Priest.PrMagnus

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
    @tag game_mode: :renewal
    test "loads rAthena's cast, cost, catalyst, interval, duration, and hit tables" do
      assert {:ok, definition} = Catalog.by_name(:pr_magnus)
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

    @tag game_mode: :pre_renewal
    test "loads the classic 15 second cast, 4 second delay, and longer field" do
      assert {:ok, definition} = Catalog.by_name(:pr_magnus)
      assert definition.unit_duration == Enum.to_list(5_000..14_000//1_000)
      assert definition.cast_time == List.duplicate(15_000, 10)
      assert definition.fixed_cast_time == []
      assert definition.after_cast_delay == List.duplicate(4_000, 10)
      assert definition.cooldown == []
      assert definition.item_cost == [%{id: 717, amount: 1}]
    end
  end

  describe "on_place/1" do
    @tag game_mode: :renewal
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

  describe "per-cell units" do
    test "each of the 33 cells reaches one cell and shares strikes with every Magnus" do
      assert {:ok, placement} = PrMagnus.on_place(group(1))
      assert length(placement.cells) == 33
      assert %{unit_range: 1, no_overlap: true, path_check: true} = placement
    end
  end

  describe "on_unit_hit/4" do
    @tag game_mode: :renewal
    test "gives the +30 ratio only to supplied undead and demon targets" do
      test_pid = self()
      stub(Combat, :resolve_combatant, fn @caster_id -> {:ok, %{unit_id: @caster_id}} end)

      stub(Combat, :resolve_combatant, fn
        :mob, 2_001 -> {:ok, %{race: :formless, element: {:neutral, 1}}}
        :mob, 2_002 -> {:ok, %{race: :undead, element: {:undead, 1}}}
        :mob, 2_003 -> {:ok, %{race: :demon, element: {:fire, 1}}}
      end)

      stub(Combat, :apply_skill_unit_damage, fn
        %{unit_id: @caster_id}, :mob, target_id, 79, 10, :holy, ratio, hit_divisions: 10 ->
          send(test_pid, {:hit, target_id, ratio})
          :ok
      end)

      for target <- [{:mob, 2_001}, {:mob, 2_002}, {:mob, 2_003}] do
        assert {:ok, %Group{}} = PrMagnus.on_unit_hit(group(10), @center, target, 0)
      end

      assert_received {:hit, 2_001, 100}
      assert_received {:hit, 2_002, 130}
      assert_received {:hit, 2_003, 130}
    end

    @tag game_mode: :pre_renewal
    test "classic fields strike only undead and demons" do
      test_pid = self()
      stub(Combat, :resolve_combatant, fn @caster_id -> {:ok, %{unit_id: @caster_id}} end)

      stub(Combat, :resolve_combatant, fn
        :mob, 2_001 -> {:ok, %{race: :formless, element: {:neutral, 1}}}
        :mob, 2_002 -> {:ok, %{race: :undead, element: {:undead, 1}}}
        :mob, 2_003 -> {:ok, %{race: :demon, element: {:fire, 1}}}
      end)

      stub(Combat, :apply_skill_unit_damage, fn
        %{unit_id: @caster_id}, :mob, target_id, 79, 10, :holy, ratio, hit_divisions: 10 ->
          send(test_pid, {:hit, target_id, ratio})
          :ok
      end)

      for target <- [{:mob, 2_001}, {:mob, 2_002}, {:mob, 2_003}] do
        assert {:ok, %Group{}} = PrMagnus.on_unit_hit(group(10), @center, target, 0)
      end

      refute_received {:hit, 2_001, _}
      assert_received {:hit, 2_002, 130}
      assert_received {:hit, 2_003, 130}
    end

    test "does not damage candidates whose combatant has disappeared" do
      stub(Combat, :resolve_combatant, fn @caster_id -> {:ok, %{unit_id: @caster_id}} end)
      stub(Combat, :resolve_combatant, fn :mob, 2_001 -> {:error, :target_not_found} end)

      reject(&Combat.apply_skill_unit_damage/8)

      assert {:ok, %Group{}} = PrMagnus.on_unit_hit(group(10), @center, {:mob, 2_001}, 0)
    end
  end
end
