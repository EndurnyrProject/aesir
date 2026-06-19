defmodule Aesir.ZoneServer.Mmo.Skills.WzStormgustTest do
  use ExUnit.Case, async: false
  import Mimic

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skills.WzStormgust
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  setup :verify_on_exit!

  @caster_id 1000
  @map_name "prontera"
  @center {150, 150}

  # Renewal WZ_STORMGUST ratio: 70 + 50 * level (skills/mage/stormgust.cpp:21).
  @level 10
  @expected_ratio 70 + 50 * @level

  defp group(state \\ %{hit_counts: %{}}) do
    %Group{
      group_id: 1,
      skill_id: 89,
      skill_name: :wz_stormgust,
      level: @level,
      caster_id: @caster_id,
      caster_type: :player,
      map_name: @map_name,
      center: @center,
      cells: [],
      interval: 450,
      state: state
    }
  end

  defp stub_caster do
    stub(Combat, :resolve_combatant, fn @caster_id -> {:ok, %{unit_id: @caster_id}} end)
  end

  describe "skill data" do
    test "wz_stormgust loads from the catalog as a ground skill" do
      assert {:ok, definition} = Catalog.by_name(:wz_stormgust)
      assert definition.id == 89
      assert definition.target_type == :ground
      assert definition.range == 9
      assert definition.max_level == 10
    end

    test "wz_stormgust is registered as both an active and a ground skill" do
      assert {:ok, WzStormgust} = Catalog.active_module_for(:wz_stormgust)
      assert {:ok, WzStormgust} = Catalog.ground_module_for(:wz_stormgust)
    end
  end

  describe "on_place/1" do
    test "returns the 5x5 footprint, 450ms interval, and empty hit counts" do
      assert {:ok, placement} = WzStormgust.on_place(group())
      assert length(placement.cells) == 25
      assert placement.interval == 450
      assert placement.duration == 4_500
      assert placement.state == %{hit_counts: %{}}
    end
  end

  describe "on_interval/2" do
    test "hits each in-footprint mob once via the magic calculator and knocks it back" do
      test_pid = self()
      stub_caster()

      stub(Combat, :splash_targets, fn @map_name, @center, 2, @caster_id ->
        [{:mob, 2001}, {:mob, 2002}]
      end)

      stub(Combat, :apply_skill_unit_damage, fn caster,
                                                unit_type,
                                                target_id,
                                                89,
                                                @level,
                                                :water,
                                                @expected_ratio ->
        assert caster.unit_id == @caster_id
        send(test_pid, {:hit, unit_type, target_id})
        :ok
      end)

      stub(Combat, :knockback, fn :mob, target_id, 150, 150, 2 ->
        send(test_pid, {:knockback, target_id})
        {:ok, {0, 0}}
      end)

      assert {:ok, %Group{}} = WzStormgust.on_interval(group(), 0)

      assert_received {:hit, :mob, 2001}
      assert_received {:hit, :mob, 2002}
      assert_received {:knockback, 2001}
      assert_received {:knockback, 2002}
      refute_received {:hit, :player, @caster_id}
    end

    test "skips the whole tick (no damage) when the caster cannot be resolved" do
      stub(Combat, :resolve_combatant, fn @caster_id -> {:error, :target_not_found} end)

      reject(&Combat.splash_targets/4)
      reject(&Combat.apply_skill_unit_damage/7)
      reject(&Combat.knockback/5)
      reject(&StatusInterpreter.apply_status/4)

      assert {:ok, %Group{state: %{hit_counts: %{}}}} = WzStormgust.on_interval(group(), 0)
    end

    test "does not hit a dead mob (hp <= 0) inside the footprint" do
      stub_caster()
      stub(Combat, :splash_targets, fn @map_name, @center, 2, @caster_id -> [] end)

      reject(&Combat.apply_skill_unit_damage/7)
      reject(&Combat.knockback/5)
      reject(&StatusInterpreter.apply_status/4)

      assert {:ok, %Group{state: %{hit_counts: %{}}}} = WzStormgust.on_interval(group(), 0)
    end

    test "does not freeze before the 3rd accumulated hit" do
      stub_caster()

      stub(Combat, :splash_targets, fn @map_name, @center, 2, @caster_id ->
        [{:mob, 2001}]
      end)

      stub(Combat, :apply_skill_unit_damage, fn _c, _ut, _tid, _sid, _lvl, _el, _ratio -> :ok end)
      stub(Combat, :knockback, fn _ut, _tid, _x, _y, _d -> {:ok, {0, 0}} end)
      reject(&StatusInterpreter.apply_status/4)

      assert {:ok, %Group{state: %{hit_counts: %{2001 => 1}}}} =
               WzStormgust.on_interval(group(), 0)
    end

    test "freezes on the 3rd accumulated hit and does not reset the counter" do
      stub_caster()

      stub(Combat, :splash_targets, fn @map_name, @center, 2, @caster_id ->
        [{:mob, 2001}]
      end)

      stub(Combat, :apply_skill_unit_damage, fn _c, _ut, _tid, _sid, _lvl, _el, _ratio -> :ok end)
      stub(Combat, :knockback, fn _ut, _tid, _x, _y, _d -> {:ok, {0, 0}} end)

      expect(StatusInterpreter, :apply_status, fn :mob, 2001, :sc_freeze, _params -> :ok end)

      seeded = group(%{hit_counts: %{2001 => 2}})

      assert {:ok, %Group{state: %{hit_counts: %{2001 => 3}}}} =
               WzStormgust.on_interval(seeded, 0)
    end

    test "does not re-freeze after the counter passes 3" do
      stub_caster()

      stub(Combat, :splash_targets, fn @map_name, @center, 2, @caster_id ->
        [{:mob, 2001}]
      end)

      stub(Combat, :apply_skill_unit_damage, fn _c, _ut, _tid, _sid, _lvl, _el, _ratio -> :ok end)
      stub(Combat, :knockback, fn _ut, _tid, _x, _y, _d -> {:ok, {0, 0}} end)
      reject(&StatusInterpreter.apply_status/4)

      seeded = group(%{hit_counts: %{2001 => 3}})

      assert {:ok, %Group{state: %{hit_counts: %{2001 => 4}}}} =
               WzStormgust.on_interval(seeded, 0)
    end
  end
end
