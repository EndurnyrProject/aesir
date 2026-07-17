defmodule Aesir.ZoneServer.Mmo.Skills.SaLandprotectorTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup
  import Mimic

  alias Aesir.ZoneServer.Map.Cell, as: MapCell
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.Skills.AlPneuma
  alias Aesir.ZoneServer.Mmo.Skills.MgFirewall
  alias Aesir.ZoneServer.Mmo.Skills.MgSafetywall
  alias Aesir.ZoneServer.Mmo.Skills.MgThunderstorm
  alias Aesir.ZoneServer.Mmo.Skills.SaLandprotector
  alias Aesir.ZoneServer.Mmo.Skills.WzFirepillar
  alias Aesir.ZoneServer.Mmo.Skills.WzIcewall
  alias Aesir.ZoneServer.Mmo.Skills.WzQuagmire
  alias Aesir.ZoneServer.Mmo.Skills.WzStormgust
  alias Aesir.ZoneServer.Mmo.Skills.WzVermilion
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables
  setup :verify_on_exit!

  @center {100, 100}
  @now 10_000

  # rAthena db/re/skill_db.yml:8069-8125.
  describe "definition/0" do
    test "matches the Renewal Land Protector tables" do
      definition = SaLandprotector.definition()

      assert definition.id == 288
      assert definition.max_level == 5
      assert definition.target_type == :ground
      assert definition.damage_type == :no_damage
      assert definition.range == 2
      assert definition.sp_cost == [66, 62, 58, 54, 50]
      assert definition.cast_time == List.duplicate(4_000, 5)
      assert definition.fixed_cast_time == List.duplicate(1_000, 5)
      assert definition.unit_duration == [165_000, 210_000, 255_000, 300_000, 345_000]
      assert definition.item_cost == [%{id: 717, amount: 1}, %{id: 715, amount: 1}]
    end
  end

  describe "on_place/1" do
    test "uses the 7x7 to 11x11 layout radii per level" do
      for {level, radius} <- [{1, 3}, {2, 3}, {3, 4}, {4, 4}, {5, 5}] do
        assert {:ok, placement} = SaLandprotector.on_place(base_group(SaLandprotector, 1, level))

        expected = for dx <- -radius..radius, dy <- -radius..radius, do: {100 + dx, 100 + dy}
        assert Enum.sort(placement.cells) == Enum.sort(expected)

        assert placement.duration ==
                 Enum.at([165_000, 210_000, 255_000, 300_000, 345_000], level - 1)
      end
    end

    test "marks the group as a land protector without field support" do
      assert {:ok, placement} = SaLandprotector.on_place(base_group(SaLandprotector, 1, 1))

      assert placement.state == %{land_protector: true}
      assert placement.path_check == true
      refute function_exported?(SaLandprotector, :field_support, 1)
    end
  end

  describe "schedule/2" do
    test "makes the group tickless" do
      assert {:ok, %Group{next_tick_at: nil}} =
               SaLandprotector.schedule(base_group(SaLandprotector, 1, 1), fn upper ->
                 upper - 1
               end)
    end
  end

  describe "wizard ground suite suppression" do
    @fully_covered [
      {MgFirewall, "Fire Wall"},
      {MgSafetywall, "Safety Wall"},
      {AlPneuma, "Pneuma"},
      {WzQuagmire, "Quagmire"},
      {WzStormgust, "Storm Gust"},
      {WzIcewall, "Ice Wall"},
      {WzFirepillar, "Fire Pillar"},
      {MgThunderstorm, "Thunder Storm"}
    ]

    for {module, label} <- @fully_covered do
      @module module
      test "suppresses #{label} placed inside its footprint" do
        stub_placement_dependencies()
        manager = start_manager()

        assert :ok = place(manager, SaLandprotector, 1, 5)
        assert {:error, :land_protector} = place(manager, @module, 2, 1)

        assert nil == Storage.get(2)
        assert %Group{group_id: 1} = Storage.get(1)
      end
    end

    test "drops only Lord of Vermilion's cells inside the footprint" do
      manager = start_manager()

      assert :ok = place(manager, SaLandprotector, 1, 5)
      assert :ok = place(manager, WzVermilion, 2, 1)

      %Group{cells: survivors} = Storage.get(2)

      assert survivors != []
      assert Enum.all?(survivors, fn {x, y} -> max(abs(x - 100), abs(y - 100)) > 5 end)
      assert length(survivors) == 13 * 13 - 11 * 11
    end

    test "placing land protector destroys an ice wall immediately, clearing its terrain" do
      stub_placement_dependencies()
      manager = start_manager()

      assert :ok = place(manager, WzIcewall, 1, 1)
      assert [_ | _] = Storage.get_cells_by_group(1)
      refute MapCell.traversable?("prontera", 100, 100)

      assert :ok = place(manager, SaLandprotector, 2, 1)

      assert nil == Storage.get(1)
      assert [] == Storage.get_cells_by_group(1)
      assert MapCell.traversable?("prontera", 100, 100)
      assert %Group{group_id: 2} = Storage.get(2)
    end
  end

  defp stub_placement_dependencies do
    stub(Combat, :resolve_combatant, fn 100 -> {:ok, %{position: {100, 98}}} end)

    stub(UnitRegistry, :get_unit_info, fn :player, 100 ->
      {:ok, %{stats: %{int: 50, base_level: 70, max_sp: 400}}}
    end)
  end

  defp start_manager do
    manager =
      start_supervised!(
        {Manager,
         [
           name: nil,
           clock: fn -> @now end,
           schedule_tick: fn _pid, _interval -> :ok end,
           unit_available?: fn _unit_type, _unit_id, _map_name -> true end
         ]}
      )

    allow(Aesir.ZoneServer.Mmo.Skill.Catalog, self(), manager)
    allow(Aesir.ZoneServer.Unit.Broadcast, self(), manager)
    manager
  end

  defp place(manager, module, group_id, level) do
    group = base_group(module, group_id, level)
    {:ok, placement} = module.on_place(group)

    Manager.register(manager, %{
      group
      | cells: placement.cells,
        created_at: @now,
        visible?: true,
        state: placement_state(placement),
        interval: placement.interval,
        lifecycle_policy: Map.get(placement, :lifecycle_policy, group.lifecycle_policy),
        next_tick_at: @now + Map.get(placement, :initial_delay, placement.interval),
        expires_at: @now + placement.duration
    })
  end

  defp base_group(module, group_id, level) do
    %Group{
      group_id: group_id,
      skill_id: module.definition().id,
      skill_name: module.skill_name(),
      level: level,
      caster_id: 100,
      caster_type: :player,
      map_name: "prontera",
      center: @center,
      next_tick_at: 0,
      expires_at: 1_000_000,
      interval: 1_000
    }
  end

  defp placement_state(%{cell_attrs: cell_attrs, state: state}),
    do: Map.put(state, :cell_attrs, cell_attrs)

  defp placement_state(%{state: state}), do: state
end
