defmodule Aesir.ZoneServer.Mmo.Skills.MgFirewallTest do
  use ExUnit.Case, async: false
  import Mimic

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skills.MgFirewall

  setup :verify_on_exit!

  @caster_id 1000
  @map_name "prontera"
  # Caster south of the wall: caster->center faces north, wall lies east-west.
  @caster_pos {150, 148}
  @center {150, 150}

  # Renewal MG_FIREWALL ratio: base 100 - 50 = 50% per hit.
  @expected_ratio 50

  defp group(level, state \\ %{hits_remaining: nil}, origin \\ @caster_pos) do
    %Group{
      group_id: 1,
      skill_id: 18,
      skill_name: :mg_firewall,
      level: level,
      caster_id: @caster_id,
      caster_type: :player,
      map_name: @map_name,
      center: @center,
      origin: origin,
      cells: [],
      interval: 20,
      state: state
    }
  end

  defp stub_caster(element \\ :neutral, race \\ :formless) do
    stub(Combat, :resolve_combatant, fn
      @caster_id -> {:ok, %{unit_id: @caster_id, position: @caster_pos}}
      _target -> {:ok, %{element: element, race: race}}
    end)
  end

  describe "skill data" do
    test "mg_firewall loads from the catalog as a ground skill" do
      assert {:ok, definition} = Catalog.by_id(18)
      assert definition.name == :mg_firewall
      assert definition.target_type == :ground
      assert definition.element == :fire
      assert definition.range == 9
      assert definition.max_level == 10
      assert definition.knockback == 2

      assert definition.cast_time ==
               [1600, 1440, 1280, 1120, 960, 880, 800, 720, 640, 560]

      assert definition.fixed_cast_time == [400, 360, 320, 280, 240, 220, 200, 180, 160, 140]
      assert definition.sp_cost == List.duplicate(40, 10)

      assert definition.unit_duration ==
               [5000, 6000, 7000, 8000, 9000, 10_000, 11_000, 12_000, 13_000, 14_000]
    end

    test "mg_firewall is registered as both an active and a ground skill" do
      assert {:ok, MgFirewall} = Catalog.active_module_for(:mg_firewall)
      assert {:ok, MgFirewall} = Catalog.ground_module_for(:mg_firewall)
    end
  end

  describe "on_place/1" do
    test "lays a 3-cell line perpendicular to caster->target facing and seeds the hit budget" do
      assert {:ok, placement} = MgFirewall.on_place(group(3))
      # Caster->center faces +y (north); wall runs along the x axis through center.
      assert Enum.sort(placement.cells) == [{149, 150}, {150, 150}, {151, 150}]
      assert placement.interval == 20
      assert placement.state == %{hits_remaining: 7}
      assert placement.duration == 7000
    end

    test "defaults to a horizontal line when caster sits on the target cell" do
      assert {:ok, %{cells: cells}} =
               MgFirewall.on_place(group(1, %{hits_remaining: nil}, @center))

      assert length(cells) == 3
    end

    test "defaults to a horizontal line when the group has no origin" do
      assert {:ok, %{cells: cells}} = MgFirewall.on_place(group(1, %{hits_remaining: nil}, nil))
      assert cells == [{149, 150}, {150, 150}, {151, 150}]
    end
  end

  describe "on_interval/2" do
    test "hits each in-footprint enemy at 50% fire, knocks neutral targets back, decrements budget" do
      test_pid = self()
      stub_caster()

      stub(Combat, :splash_targets, fn @map_name, @center, _radius, @caster_id ->
        [{:mob, 2001}, {:mob, 2002}]
      end)

      stub(Combat, :apply_skill_unit_damage, fn caster,
                                                unit_type,
                                                target_id,
                                                18,
                                                3,
                                                :fire,
                                                @expected_ratio ->
        assert caster.unit_id == @caster_id
        send(test_pid, {:hit, unit_type, target_id})
        :ok
      end)

      stub(Combat, :knockback, fn unit_type, target_id, _fx, _fy, 2 ->
        send(test_pid, {:knockback, unit_type, target_id})
        {:ok, {0, 0}}
      end)

      assert {:ok, %Group{state: %{hits_remaining: 5}}} =
               MgFirewall.on_interval(group(3, %{hits_remaining: 7}), 0)

      assert_received {:hit, :mob, 2001}
      assert_received {:hit, :mob, 2002}
      assert_received {:knockback, :mob, 2001}
      assert_received {:knockback, :mob, 2002}
    end

    test "does not knock back a fire-element target" do
      stub_caster(:fire)

      stub(Combat, :splash_targets, fn @map_name, @center, _radius, @caster_id ->
        [{:mob, 2001}]
      end)

      stub(Combat, :apply_skill_unit_damage, fn _c, _ut, _tid, _sid, _lvl, _el, _ratio -> :ok end)
      reject(&Combat.knockback/5)

      assert {:ok, %Group{}} = MgFirewall.on_interval(group(3, %{hits_remaining: 7}), 0)
    end

    test "does not knock back an undead-element target" do
      stub_caster(:undead)

      stub(Combat, :splash_targets, fn @map_name, @center, _radius, @caster_id ->
        [{:mob, 2001}]
      end)

      stub(Combat, :apply_skill_unit_damage, fn _c, _ut, _tid, _sid, _lvl, _el, _ratio -> :ok end)
      reject(&Combat.knockback/5)

      assert {:ok, %Group{}} = MgFirewall.on_interval(group(3, %{hits_remaining: 7}), 0)
    end

    test "does not knock back an undead-race target" do
      stub_caster(:neutral, :undead)

      stub(Combat, :splash_targets, fn @map_name, @center, _radius, @caster_id ->
        [{:mob, 2001}]
      end)

      stub(Combat, :apply_skill_unit_damage, fn _c, _ut, _tid, _sid, _lvl, _el, _ratio -> :ok end)
      reject(&Combat.knockback/5)

      assert {:ok, %Group{}} = MgFirewall.on_interval(group(3, %{hits_remaining: 7}), 0)
    end

    test "skips the whole tick (no damage) when the caster cannot be resolved" do
      stub(Combat, :resolve_combatant, fn @caster_id -> {:error, :target_not_found} end)

      reject(&Combat.splash_targets/4)
      reject(&Combat.apply_skill_unit_damage/7)

      assert {:ok, %Group{state: %{hits_remaining: 7}}} =
               MgFirewall.on_interval(group(3, %{hits_remaining: 7}), 0)
    end

    test "expires once the shared hit budget reaches 0" do
      stub_caster()

      stub(Combat, :splash_targets, fn @map_name, @center, _radius, @caster_id ->
        [{:mob, 2001}]
      end)

      stub(Combat, :apply_skill_unit_damage, fn _c, _ut, _tid, _sid, _lvl, _el, _ratio -> :ok end)
      stub(Combat, :knockback, fn _ut, _tid, _fx, _fy, _d -> {:ok, {0, 0}} end)

      assert {:expire, %Group{state: %{hits_remaining: 0}}} =
               MgFirewall.on_interval(group(3, %{hits_remaining: 1}), 0)
    end

    test "absorbs exactly 4 + level hits then disappears" do
      stub_caster()

      stub(Combat, :splash_targets, fn @map_name, @center, _radius, @caster_id ->
        [{:mob, 2001}]
      end)

      stub(Combat, :apply_skill_unit_damage, fn _c, _ut, _tid, _sid, _lvl, _el, _ratio -> :ok end)
      stub(Combat, :knockback, fn _ut, _tid, _fx, _fy, _d -> {:ok, {0, 0}} end)

      level = 5
      budget = 4 + level
      {:ok, %{state: state}} = MgFirewall.on_place(group(level))

      result =
        Enum.reduce_while(1..(budget + 5), {group(level, state), 0}, fn _i, {g, count} ->
          case MgFirewall.on_interval(g, 0) do
            {:ok, updated} -> {:cont, {updated, count + 1}}
            {:expire, _updated} -> {:halt, count + 1}
          end
        end)

      assert result == budget
    end
  end
end
