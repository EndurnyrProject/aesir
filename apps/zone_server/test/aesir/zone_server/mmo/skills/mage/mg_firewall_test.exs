defmodule Aesir.ZoneServer.Mmo.Skills.Mage.MgFirewallTest do
  use ExUnit.Case, async: false
  import Mimic

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skills.Mage.MgFirewall
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  @caster_id 1000
  @target {:mob, 2001}
  @map_name "prontera"
  # Caster south of the wall: caster->center faces north, wall lies east-west.
  @caster_pos {150, 148}
  @center {150, 150}
  @cell {149, 150}

  # MG_FIREWALL ratio: base 100 - 50 = 50% per hit, both modes.
  @expected_ratio 50

  # The cardinal wall a caster at @caster_pos lays through @center.
  @wall_cells [{149, 150}, {150, 150}, {151, 150}]

  defp group(level, state \\ %{}, origin \\ @caster_pos) do
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
      cells: @wall_cells,
      interval: 20,
      state: state
    }
  end

  defp burning(budget), do: group(3, %{cell_budget: %{@cell => budget}})

  # The target stands on @cell facing north (Aesir dir 4).
  defp stub_world(element \\ :neutral, race \\ :formless) do
    stub(Combat, :resolve_combatant, fn
      :player, @caster_id -> {:ok, %{unit_type: :player, unit_id: @caster_id}}
      :mob, 2001 -> {:ok, %{element: element, race: race}}
    end)

    stub(SpatialIndex, :get_unit_position, fn :mob, 2001 -> {:ok, {149, 150, @map_name}} end)
    stub(UnitRegistry, :get_unit, fn :mob, 2001 -> {:ok, {nil, %{dir: 4}, self()}} end)
  end

  # Every strike reports the given outcome and records its options.
  defp stub_strikes(report) do
    test_pid = self()

    stub(Combat, :apply_skill_unit_damage, fn caster,
                                              :mob,
                                              2001,
                                              18,
                                              3,
                                              :fire,
                                              @expected_ratio,
                                              opts ->
      assert caster.unit_id == @caster_id
      send(test_pid, {:strike, opts})
      report
    end)
  end

  defp strikes do
    Stream.repeatedly(fn ->
      receive do
        {:strike, opts} -> opts
      after
        0 -> nil
      end
    end)
    |> Enum.take_while(& &1)
  end

  defp report(attrs \\ []),
    do:
      {:ok, Map.merge(%{hit?: true, damage: 10, survives?: true, moved?: false}, Map.new(attrs))}

  describe "skill data" do
    test "classic casts slower at every level and the wall lasts the same" do
      assert MgFirewall.definition(:renewal).cast_time ==
               [1600, 1440, 1280, 1120, 960, 880, 800, 720, 640, 560]

      assert MgFirewall.definition(:pre_renewal).cast_time ==
               [2000, 1850, 1700, 1550, 1400, 1250, 1100, 950, 800, 650]

      assert MgFirewall.definition(:pre_renewal).unit_duration ==
               MgFirewall.definition(:renewal).unit_duration
    end
  end

  describe "on_place/1" do
    setup do
      stub(StatusStorage, :has_status?, fn _type, _id, :sc_violentgale -> false end)
      :ok
    end

    test "lays a 3-cell line perpendicular to caster->target facing and seeds each cell's budget" do
      assert {:ok, placement} = MgFirewall.on_place(group(3))
      # Caster->center faces +y (north); wall runs along the x axis through center.
      assert Enum.sort(placement.cells) == [{149, 150}, {150, 150}, {151, 150}]
      assert placement.interval == 20
      assert placement.unit_range == 0
      assert placement.path_check
      assert placement.state == %{cell_budget: Map.new(@wall_cells, &{&1, 7})}
      assert placement.duration == 7000
    end

    test "lays a north-south line when the caster sits on the target cell (it looks east)" do
      assert {:ok, %{cells: cells}} = MgFirewall.on_place(group(1, %{}, @center))
      assert cells == [{150, 149}, {150, 150}, {150, 151}]
    end

    test "faces by rAthena's sectors: a shallow diagonal offset looks along its axis" do
      # dx 3, dy 1 is within the 1:3 slope of east, so the wall is a straight
      # north-south line, not a staircase.
      assert {:ok, %{cells: cells}} = MgFirewall.on_place(group(3, %{}, {147, 149}))
      assert cells == [{150, 149}, {150, 150}, {150, 151}]
    end

    test "lays a 5-cell staircase when the caster faces the target diagonally" do
      assert {:ok, %{cells: cells}} = MgFirewall.on_place(group(3, %{}, {148, 148}))

      # Caster->center faces {+1, +1}; the wall staircases along the other diagonal.
      assert Enum.sort(cells) ==
               Enum.sort([{149, 151}, {149, 150}, {150, 150}, {150, 149}, {151, 149}])
    end

    test "staircases the other way for the opposite diagonal facing" do
      assert {:ok, %{cells: cells}} = MgFirewall.on_place(group(3, %{}, {148, 152}))

      # Caster->center faces {+1, -1}.
      assert Enum.sort(cells) ==
               Enum.sort([{151, 151}, {151, 150}, {150, 150}, {150, 149}, {149, 149}])
    end

    test "lays a north-south line when the group has no origin" do
      assert {:ok, %{cells: cells}} = MgFirewall.on_place(group(1, %{}, nil))
      assert cells == [{150, 149}, {150, 150}, {150, 151}]
    end

    test "lasts half again as long while the caster stands in Violent Gale" do
      stub(StatusStorage, :has_status?, fn :player, @caster_id, :sc_violentgale -> true end)

      assert {:ok, %{duration: 10_500}} = MgFirewall.on_place(group(3))
    end
  end

  describe "unit_targets/3" do
    test "burns nobody while the caster is gone" do
      stub(Combat, :resolve_combatant, fn :player, @caster_id -> {:error, :not_found} end)

      assert MgFirewall.unit_targets(burning(7), @cell, [@target]) == []
    end
  end

  describe "on_unit_hit/4" do
    test "strikes a target that is not moved up to five times in one pass, each spending budget" do
      stub_world(:fire)
      stub_strikes(report())

      assert {:ok, %Group{state: %{cell_budget: %{@cell => 2}}}} =
               MgFirewall.on_unit_hit(burning(7), @cell, @target, 0)

      opts = strikes()
      assert length(opts) == 5
      assert Enum.map(opts, & &1[:prior_damage]) == [0, 10, 20, 30, 40]
    end

    test "stops striking a target its strike moved" do
      stub_world()
      stub_strikes(report(moved?: true))

      assert {:ok, %Group{state: %{cell_budget: %{@cell => 6}}}} =
               MgFirewall.on_unit_hit(burning(7), @cell, @target, 0)

      assert length(strikes()) == 1
    end

    test "stops striking a target its strike killed" do
      stub_world(:fire)
      stub_strikes(report(survives?: false))

      assert {:ok, %Group{state: %{cell_budget: %{@cell => 6}}}} =
               MgFirewall.on_unit_hit(burning(7), @cell, @target, 0)

      assert length(strikes()) == 1
    end

    test "a refused strike still spends the cell's budget and the next one follows" do
      stub_world(:fire)
      stub_strikes({:error, :invalid_target})

      assert {:ok, %Group{state: %{cell_budget: %{@cell => 2}}}} =
               MgFirewall.on_unit_hit(burning(7), @cell, @target, 0)

      assert length(strikes()) == 5
    end

    test "a cell whose budget runs out is removed at once" do
      stub_world(:fire)
      stub_strikes(report())

      assert {:ok, %Group{state: %{cell_budget: %{@cell => 0}}}, [{:remove_cells, 1, [@cell]}]} =
               MgFirewall.on_unit_hit(burning(2), @cell, @target, 0)

      assert length(strikes()) == 2
    end

    test "knocks a neutral target two cells straight back from where it faces" do
      stub_world()
      stub_strikes(report(moved?: true))

      MgFirewall.on_unit_hit(burning(7), @cell, @target, 0)

      assert [opts] = strikes()
      assert opts[:base_distance] == 2
      # Facing north from {149, 150}: the push origin sits one cell north.
      assert opts[:origin] == {149, 151}
      assert opts[:native_enabled]
      assert opts[:report_hit]
    end

    test "does not knock back a fire-element target" do
      stub_world({:fire, 1})
      stub_strikes(report(survives?: false))

      MgFirewall.on_unit_hit(burning(7), @cell, @target, 0)

      assert [opts] = strikes()
      refute opts[:native_enabled]
    end

    test "does not knock back an undead-element target" do
      stub_world({:undead, 1})
      stub_strikes(report(survives?: false))

      MgFirewall.on_unit_hit(burning(7), @cell, @target, 0)

      assert [opts] = strikes()
      refute opts[:native_enabled]
    end

    test "a strike leaves a fire or undead-element target unstoppable by damage for 2 s" do
      Aesir.TestEtsSetup.setup_ets_tables(%{})

      for element <- [{:fire, 1}, {:undead, 1}] do
        stub_world(element)
        stub_strikes(report(survives?: false))
        MgFirewall.on_unit_hit(burning(7), @cell, @target, 0)
        [opts] = strikes()

        before = System.monotonic_time(:millisecond)
        opts[:additional_effect].(%{unit_id: @caster_id}, @target)
        later = System.monotonic_time(:millisecond)

        assert StatusStorage.endure_tick(:mob, 2001) in (before + 2000)..(later + 2000)
        StatusStorage.clear_unit_statuses(:mob, 2001)
      end
    end

    test "a strike leaves any other target stoppable" do
      Aesir.TestEtsSetup.setup_ets_tables(%{})
      stub_world(:neutral, :undead)
      stub_strikes(report(moved?: true))

      MgFirewall.on_unit_hit(burning(7), @cell, @target, 0)

      assert [opts] = strikes()
      opts[:additional_effect].(%{unit_id: @caster_id}, @target)
      assert StatusStorage.endure_tick(:mob, 2001) == nil
    end

    test "knocks back an undead-race target of another element" do
      stub_world(:neutral, :undead)
      stub_strikes(report(moved?: true))

      MgFirewall.on_unit_hit(burning(7), @cell, @target, 0)

      assert [opts] = strikes()
      assert opts[:native_enabled]
    end

    test "strikes nothing when the caster cannot be resolved" do
      stub(Combat, :resolve_combatant, fn :player, @caster_id -> {:error, :target_not_found} end)
      reject(&Combat.apply_skill_unit_damage/8)

      assert {:ok, %Group{state: %{cell_budget: %{@cell => 7}}}} =
               MgFirewall.on_unit_hit(burning(7), @cell, @target, 0)
    end
  end
end
