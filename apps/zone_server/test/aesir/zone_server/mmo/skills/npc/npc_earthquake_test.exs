defmodule Aesir.ZoneServer.Mmo.Skills.Npc.NpcEarthquakeTest do
  use ExUnit.Case, async: false
  import Aesir.TestEtsSetup
  import Mimic

  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Layout
  alias Aesir.ZoneServer.Mmo.Skills.Npc.NpcEarthquake

  setup :setup_ets_tables
  setup :verify_on_exit!

  @caster_id 5002
  @map_name "prontera"
  @center {200, 200}
  @level 7

  defp stub_walkable_map do
    map = MapData.new(@map_name, 250, 250)
    :ets.insert(EtsTable.table_for(:map_cache), {@map_name, map})
  end

  defp group(level \\ @level) do
    %Group{
      group_id: 1,
      skill_id: 653,
      skill_name: :npc_earthquake,
      level: level,
      caster_id: @caster_id,
      caster_type: :mob,
      map_name: @map_name,
      center: @center,
      cells: [],
      interval: 450,
      state: %{}
    }
  end

  defp stub_caster do
    stub(Combat, :resolve_combatant, fn :mob, @caster_id ->
      {:ok, %{unit_id: @caster_id, unit_type: :mob}}
    end)
  end

  describe "skill data" do
    test "npc_earthquake loads from the catalog as a ground skill" do
      assert {:ok, definition} = Catalog.by_name(:npc_earthquake)
      assert definition.id == 653
      assert definition.target_type == :ground
      assert definition.damage_kind == :magic
      assert definition.element == :neutral
      assert definition.max_level == 10
      assert definition.hit_interval == 450
      assert definition.unit_duration == List.duplicate(4_500, 10)
    end

    test "npc_earthquake is registered as both an active and a ground skill" do
      assert {:ok, NpcEarthquake} = Catalog.active_module_for(:npc_earthquake)
      assert {:ok, NpcEarthquake} = Catalog.ground_module_for(:npc_earthquake)
    end
  end

  describe "on_place/1" do
    test "returns the 5x5 footprint, 450ms interval, and 4500ms duration" do
      stub_walkable_map()

      assert {:ok, placement} = NpcEarthquake.on_place(group())
      assert length(placement.cells) == 25
      assert @center in placement.cells
      assert placement.interval == 450
      assert placement.duration == 4_500
      assert placement.state == %{}
    end

    test "clamps the footprint to walkable cells" do
      stub_walkable_map()

      for {x, y} <- Layout.square(@center, 2), {x, y} != @center do
        :ok = Cell.put(@map_name, x, y, :test_blocker, x * 1_000 + y + 1, blocks_movement: true)
      end

      assert {:ok, placement} = NpcEarthquake.on_place(group())
      assert placement.cells == [@center]
    end
  end

  describe "on_interval/2" do
    test "damages a player standing on the footprint" do
      test_pid = self()
      stub_caster()

      stub(Combat, :splash_targets, fn @map_name, @center, 2, caster ->
        assert caster.unit_type == :mob
        [{:player, 42}]
      end)

      stub(Combat, :apply_skill_unit_damage, fn caster,
                                                :player,
                                                42,
                                                653,
                                                @level,
                                                :neutral,
                                                ratio ->
        assert caster.unit_type == :mob
        send(test_pid, {:hit, :player, 42, ratio})
        :ok
      end)

      assert {:ok, %Group{}} = NpcEarthquake.on_interval(group(), 0)
      assert_received {:hit, :player, 42, ratio}
      assert ratio == 70 + 50 * @level
    end

    test "never damages a mob (mob-vs-mob gate lives in Combat.splash_targets)" do
      stub_caster()

      stub(Combat, :splash_targets, fn @map_name, @center, 2, caster ->
        assert caster.unit_type == :mob
        []
      end)

      reject(&Combat.apply_skill_unit_damage/7)

      assert {:ok, %Group{}} = NpcEarthquake.on_interval(group(), 0)
    end

    test "skips the whole tick when the mob caster cannot be resolved" do
      stub(Combat, :resolve_combatant, fn :mob, @caster_id -> {:error, :target_not_found} end)

      reject(&Combat.splash_targets/4)
      reject(&Combat.apply_skill_unit_damage/7)

      assert {:ok, %Group{}} = NpcEarthquake.on_interval(group(), 0)
    end
  end
end
