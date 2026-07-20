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

  # Renewal MG_THUNDERSTORM ratio: base 100 - 20 = 80% per pulse.
  @expected_ratio 80

  defp group(level, state \\ %{pulses: 0}) do
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

      assert definition.cast_time ==
               [2700, 2900, 3100, 3300, 3500, 3700, 3900, 4100, 4300, 4500]

      assert definition.fixed_cast_time == List.duplicate(1_500, 10)
      assert definition.after_cast_delay == List.duplicate(2_000, 10)
      assert definition.sp_cost == [29, 34, 39, 44, 49, 54, 59, 64, 69, 74]
    end

    test "mg_thunderstorm is registered as both an active and a ground skill" do
      assert {:ok, MgThunderstorm} = Catalog.active_module_for(:mg_thunderstorm)
      assert {:ok, MgThunderstorm} = Catalog.ground_module_for(:mg_thunderstorm)
    end
  end

  describe "on_place/1" do
    test "returns the 5x5 footprint, 1000ms interval, and zero pulses" do
      assert {:ok, placement} = MgThunderstorm.on_place(group(10))
      assert length(placement.cells) == 25
      assert placement.interval == 1_000
      assert placement.state == %{pulses: 0}
      assert placement.duration >= 10 * 1_000
    end
  end

  describe "on_interval/2" do
    test "hits each in-footprint mob once at 80% wind ratio and counts the pulse" do
      test_pid = self()
      stub_caster()

      stub(Combat, :splash_targets, fn @map_name, @center, 2, @caster_id ->
        [{:mob, 2001}, {:mob, 2002}]
      end)

      stub(Combat, :apply_skill_unit_damage, fn caster,
                                                unit_type,
                                                target_id,
                                                21,
                                                3,
                                                :wind,
                                                @expected_ratio ->
        assert caster.unit_id == @caster_id
        send(test_pid, {:hit, unit_type, target_id})
        :ok
      end)

      assert {:ok, %Group{state: %{pulses: 1}}} = MgThunderstorm.on_interval(group(3), 0)

      assert_received {:hit, :mob, 2001}
      assert_received {:hit, :mob, 2002}
      refute_received {:hit, :player, @caster_id}
    end

    test "skips the whole tick (no damage) when the caster cannot be resolved" do
      stub(Combat, :resolve_combatant, fn @caster_id -> {:error, :target_not_found} end)

      reject(&Combat.splash_targets/4)
      reject(&Combat.apply_skill_unit_damage/7)

      assert {:ok, %Group{state: %{pulses: 0}}} = MgThunderstorm.on_interval(group(3), 0)
    end

    test "expires once `level` pulses have fired" do
      stub_caster()

      stub(Combat, :splash_targets, fn @map_name, @center, 2, @caster_id ->
        [{:mob, 2001}]
      end)

      stub(Combat, :apply_skill_unit_damage, fn _c, _ut, _tid, _sid, _lvl, _el, _ratio -> :ok end)

      seeded = group(3, %{pulses: 2})

      assert {:expire, %Group{state: %{pulses: 3}}} = MgThunderstorm.on_interval(seeded, 0)
    end

    test "lands exactly `level` hits per enemy across its life" do
      stub_caster()

      stub(Combat, :splash_targets, fn @map_name, @center, 2, @caster_id ->
        [{:mob, 2001}]
      end)

      hits = :counters.new(1, [])

      stub(Combat, :apply_skill_unit_damage, fn _c, _ut, 2001, 21, _lvl, :wind, @expected_ratio ->
        :counters.add(hits, 1, 1)
        :ok
      end)

      level = 5

      Enum.reduce_while(1..50, group(level), fn _i, g ->
        case MgThunderstorm.on_interval(g, 0) do
          {:ok, updated} -> {:cont, updated}
          {:expire, _updated} -> {:halt, :expired}
        end
      end)

      assert :counters.get(hits, 1) == level
    end
  end
end
