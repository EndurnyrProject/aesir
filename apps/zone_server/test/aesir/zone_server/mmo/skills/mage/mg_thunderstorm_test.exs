defmodule Aesir.ZoneServer.Mmo.Skills.Mage.MgThunderstormTest do
  use ExUnit.Case, async: false
  import Mimic

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skills.Mage.MgThunderstorm

  setup :verify_on_exit!

  @caster_id 1000
  @map_name "prontera"
  @center {150, 150}

  @renewal_ratio 100
  @pre_renewal_ratio 80

  defp group(level, state \\ %{}) do
    %Group{
      group_id: 1,
      skill_id: 21,
      skill_name: :mg_thunderstorm,
      level: level,
      caster_id: @caster_id,
      caster_type: :player,
      map_name: @map_name,
      center: @center,
      cells: [],
      interval: 1_000,
      state: state
    }
  end

  defp stub_caster do
    stub(Combat, :resolve_combatant, fn @caster_id -> {:ok, %{unit_id: @caster_id}} end)
  end

  describe "skill data" do
    test "mg_thunderstorm loads from the catalog as a ground skill" do
      assert {:ok, definition} = Catalog.by_id(21)
      assert definition.name == :mg_thunderstorm
      assert definition.target_type == :ground
      assert definition.element == :wind
      assert definition.range == 9
      assert definition.max_level == 10

      assert definition.fixed_cast_time == List.duplicate(1_500, 10)
      assert definition.after_cast_delay == List.duplicate(2_000, 10)
      assert definition.sp_cost == [29, 34, 39, 44, 49, 54, 59, 64, 69, 74]
    end

    test "the cast time is slower and steeper per level in classic" do
      assert MgThunderstorm.definition(:renewal).cast_time ==
               [2700, 2900, 3100, 3300, 3500, 3700, 3900, 4100, 4300, 4500]

      assert MgThunderstorm.definition(:pre_renewal).cast_time ==
               [1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000, 9000, 10_000]
    end

    test "mg_thunderstorm is registered as both an active and a ground skill" do
      assert {:ok, MgThunderstorm} = Catalog.active_module_for(:mg_thunderstorm)
      assert {:ok, MgThunderstorm} = Catalog.ground_module_for(:mg_thunderstorm)
    end
  end

  describe "skill_ratio/1" do
    test "renewal pulses at the full magic ratio" do
      assert MgThunderstorm.skill_ratio(:renewal) == @renewal_ratio
    end

    test "classic pulses at a reduced magic ratio" do
      assert MgThunderstorm.skill_ratio(:pre_renewal) == @pre_renewal_ratio
    end
  end

  describe "on_place/1" do
    test "returns the 5x5 footprint and fires its burst without waiting an interval" do
      assert {:ok, placement} = MgThunderstorm.on_place(group(10))
      assert length(placement.cells) == 25
      assert placement.initial_delay == 0
      assert placement.interval == 1_000
      assert placement.duration <= placement.interval
    end
  end

  describe "on_interval/2 - the burst" do
    @tag game_mode: :renewal
    test "delivers the level's whole hit count to each target at once, then expires" do
      test_pid = self()
      stub_caster()

      stub(Combat, :splash_targets, fn @map_name, @center, 2, @caster_id ->
        [{:mob, 2001}, {:mob, 2002}]
      end)

      stub(Combat, :apply_skill_unit_damage, fn caster,
                                                unit_type,
                                                target_id,
                                                21,
                                                7,
                                                :wind,
                                                @renewal_ratio,
                                                opts ->
        assert caster.unit_id == @caster_id
        send(test_pid, {:hit, unit_type, target_id, opts[:hit_count]})
        :ok
      end)

      assert {:expire, %Group{}} = MgThunderstorm.on_interval(group(7), 0)

      assert_received {:hit, :mob, 2001, 7}
      assert_received {:hit, :mob, 2002, 7}
      refute_received {:hit, :player, @caster_id, _}
    end

    @tag game_mode: :pre_renewal
    test "bursts at the reduced classic ratio" do
      test_pid = self()
      stub_caster()

      stub(Combat, :splash_targets, fn @map_name, @center, 2, @caster_id ->
        [{:mob, 2001}]
      end)

      stub(Combat, :apply_skill_unit_damage, fn _caster,
                                                _unit_type,
                                                target_id,
                                                21,
                                                7,
                                                :wind,
                                                @pre_renewal_ratio,
                                                opts ->
        send(test_pid, {:hit, target_id, opts[:hit_count]})
        :ok
      end)

      assert {:expire, %Group{}} = MgThunderstorm.on_interval(group(7), 0)
      assert_received {:hit, 2001, 7}
    end

    test "a target outside the footprint when the burst fires takes nothing" do
      stub_caster()

      stub(Combat, :splash_targets, fn @map_name, @center, 2, @caster_id -> [] end)
      reject(&Combat.apply_skill_unit_damage/8)

      assert {:expire, %Group{}} = MgThunderstorm.on_interval(group(7), 0)
    end

    test "level 1 bursts for a single hit" do
      test_pid = self()
      stub_caster()

      stub(Combat, :splash_targets, fn @map_name, @center, 2, @caster_id -> [{:mob, 2001}] end)

      stub(Combat, :apply_skill_unit_damage, fn _c, _ut, _tid, 21, 1, :wind, _ratio, opts ->
        send(test_pid, {:hits, opts[:hit_count]})
        :ok
      end)

      assert {:expire, %Group{}} = MgThunderstorm.on_interval(group(1), 0)
      assert_received {:hits, 1}
    end

    test "expires without damage when the caster cannot be resolved" do
      stub(Combat, :resolve_combatant, fn @caster_id -> {:error, :target_not_found} end)

      reject(&Combat.splash_targets/4)
      reject(&Combat.apply_skill_unit_damage/8)

      assert {:expire, %Group{}} = MgThunderstorm.on_interval(group(3), 0)
    end
  end
end
