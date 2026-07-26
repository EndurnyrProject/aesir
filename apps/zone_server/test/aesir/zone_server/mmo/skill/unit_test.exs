defmodule Aesir.ZoneServer.Mmo.Skill.UnitTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup
  import Mimic

  alias Aesir.Net.GroundSkill
  alias Aesir.Net.SkillUnitGroupState
  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Unit
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.Skill.Unit.View
  alias Aesir.ZoneServer.Pathfinding
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup :setup_ets_tables
  setup :verify_on_exit!

  @interval 450
  @duration 5_000

  # A real catalog skill so place/4 can resolve its skill_id.
  @skill_name :sm_bash

  defmodule FakeUnit do
    @behaviour Ground

    alias Aesir.ZoneServer.Mmo.Skill.Unit.Group

    @impl Ground
    def on_place(%Group{center: {x, y}}) do
      {:ok, %{cells: [{x, y}], state: %{seeded: true}, interval: 450, duration: 5_000}}
    end

    @impl Ground
    def on_interval(group, _now), do: {:ok, group}

    @impl Ground
    def on_expire(_group), do: :ok
  end

  defmodule HiddenFakeUnit do
    @behaviour Ground

    alias Aesir.ZoneServer.Mmo.Skill.Unit.Group

    @impl Ground
    def on_place(%Group{center: {x, y}}) do
      {:ok,
       %{
         cells: [{x, y}],
         state: %{seeded: true},
         interval: 450,
         duration: 5_000,
         visible?: false
       }}
    end

    @impl Ground
    def on_interval(group, _now), do: {:ok, group}
  end

  defmodule ImmediateFakeUnit do
    @behaviour Ground

    alias Aesir.ZoneServer.Mmo.Skill.Unit.Group

    @impl Ground
    def on_place(%Group{center: {x, y}}) do
      {:ok,
       %{
         cells: [{x, y}],
         state: %{seeded: true},
         interval: 450,
         duration: 5_000,
         initial_delay: 0
       }}
    end

    @impl Ground
    def on_interval(group, _now), do: {:ok, group}
  end

  defmodule BorderFakeUnit do
    @behaviour Ground

    @impl Ground
    def on_place(_group) do
      {:ok,
       %{
         cells: [{-1, -1}, {-1, 0}, {0, -1}, {0, 0}, {0, 1}, {1, 0}, {1, 1}],
         state: %{},
         interval: 450,
         duration: 5_000
       }}
    end

    @impl Ground
    def on_interval(group, _now), do: {:ok, group}
  end

  defmodule PathCheckedUnit do
    @behaviour Ground

    @impl Ground
    def on_place(_group) do
      {:ok,
       %{
         cells: [{49, 60}, {50, 60}, {51, 60}],
         state: %{},
         path_check: true,
         interval: 450,
         duration: 5_000
       }}
    end

    @impl Ground
    def on_interval(group, _now), do: {:ok, group}
  end

  setup do
    manager =
      start_supervised!({Manager, name: nil, schedule_tick: fn _pid, _interval -> :ok end})

    Process.put({Manager, :server}, manager)
    allow(Catalog, self(), manager)
    Mimic.copy(Broadcast)
    allow(Broadcast, self(), manager)
    stub(Catalog, :ground_module_for, fn @skill_name -> {:ok, FakeUnit} end)
    :ok
  end

  defp caster do
    %PlayerState{
      character_id: 2_000,
      map_name: "prontera",
      x: 50,
      y: 60
    }
  end

  defp mob_caster do
    %MobState{
      instance_id: 3_000,
      mob_id: 1002,
      mob_data: %MobDefinition{
        id: 1002,
        aegis_name: "TEST_MOB",
        name: "TestMob",
        level: 1,
        hp: 100,
        sp: 50,
        base_exp: 10,
        job_exp: 5,
        atk: 10,
        matk: 0,
        def: 5,
        mdef: 0,
        stats: %{str: 10, agi: 10, vit: 10, int: 0, dex: 10, luk: 5},
        attack_range: 1,
        skill_range: 10,
        chase_range: 12,
        element: {:water, 1},
        race: :formless,
        size: :medium,
        walk_speed: 200,
        attack_delay: 1000,
        attack_motion: 500,
        client_attack_motion: 500,
        damage_motion: 400,
        ai_type: 0,
        modes: [],
        drops: []
      },
      spawn_ref: %MobSpawn{
        mob: 1002,
        amount: 1,
        respawn_time: 5_000,
        spawn_area: %MobSpawn.SpawnArea{x: 50, y: 60, xs: 0, ys: 0}
      },
      x: 50,
      y: 60,
      map_name: "prontera",
      hp: 100,
      max_hp: 100,
      sp: 50,
      max_sp: 50,
      spawned_at: System.monotonic_time(:millisecond)
    }
  end

  describe "place/4" do
    test "inserts a group with lazy timestamps and seeded placement state" do
      stub(Broadcast, :to_in_range, fn _, _, _, _, _ -> :ok end)

      before = System.monotonic_time(:millisecond)
      {:ok, %Group{} = group} = Unit.place(caster(), @skill_name, 7, {100, 120})

      assert group.skill_name == @skill_name
      assert group.level == 7
      assert group.caster_id == 2_000
      assert group.caster_type == :player
      assert group.map_name == "prontera"
      assert group.center == {100, 120}
      assert group.cells == [{100, 120}]
      assert group.interval == @interval
      assert group.state == %{cast_origin: :direct, seeded: true}

      assert group.next_tick_at >= before + @interval
      assert group.expires_at >= before + @duration
      assert group.next_tick_at + (@duration - @interval) == group.expires_at

      assert %Group{} = Storage.get(group.group_id)
    end

    test "merges caller state and cast origin before registration" do
      stub(Broadcast, :to_in_range, fn _, _, _, _, _ -> :ok end)

      assert {:ok, group} =
               Unit.place(caster(), @skill_name, 7, {100, 120},
                 origin: :normal,
                 state: %{caller_value: 1}
               )

      assert %{cast_origin: :normal, caller_value: 1, seeded: true} = group.state
      assert Storage.get(group.group_id).state == group.state
    end

    test "place/4 records direct origin while mob placement accepts mob origin" do
      stub(Broadcast, :to_in_range, fn _, _, _, _, _ -> :ok end)

      assert {:ok, %{state: %{cast_origin: :direct}}} =
               Unit.place(caster(), @skill_name, 7, {100, 120})

      assert {:ok, %{state: %{cast_origin: :mob}}} =
               Unit.place(mob_caster(), @skill_name, 5, {101, 120}, origin: :mob)
    end

    test "maps placement deadlines to non-negative server ticks" do
      stub(Broadcast, :to_in_range, fn _, _, _, _, _ -> :ok end)

      {:ok, group} = Unit.place(caster(), @skill_name, 7, {100, 120})
      packet = View.group(group, [])

      assert packet.created_tick in 0..0xFFFF_FFFF
      assert packet.expires_tick in 0..0xFFFF_FFFF
      assert {:ok, _iodata, _size} = SkillUnitGroupState.encode(packet)
    end

    test "publishes and snapshots stable cells for a player ground cast" do
      test_pid = self()
      stub(Broadcast, :to_in_range, fn _, _, _, _, packet -> send(test_pid, packet) end)

      {:ok, group} = Unit.place(caster(), @skill_name, 7, {100, 120})

      assert_receive %Aesir.Net.SkillUnitSpawn{group: %{group_id: group_id, cells: [spawn_cell]}}
      assert group_id == group.group_id
      assert %Group{visible?: true} = Storage.get(group.group_id)
      [%{cell_id: cell_id}] = Storage.get_cells_by_group(group.group_id)
      assert spawn_cell.cell_id == cell_id

      assert %Aesir.Net.SkillUnitSnapshot{
               groups: [%{group_id: ^group_id, cells: [snapshot_cell]}]
             } =
               Unit.snapshot("prontera")

      assert snapshot_cell.cell_id == cell_id
    end

    test "a placement omitting visible? registers and publishes as visible" do
      test_pid = self()
      stub(Broadcast, :to_in_range, fn _, _, _, _, packet -> send(test_pid, packet) end)

      {:ok, group} = Unit.place(caster(), @skill_name, 7, {100, 120})

      assert group.visible?
      assert %Group{visible?: true} = Storage.get(group.group_id)
      assert_receive %Aesir.Net.SkillUnitSpawn{group: %{group_id: group_id}}
      assert group_id == group.group_id
    end

    test "an explicitly hidden placement stays invisible, unmaterialized, and coordinate-indexed" do
      stub(Catalog, :ground_module_for, fn @skill_name -> {:ok, HiddenFakeUnit} end)
      test_pid = self()
      stub(Broadcast, :to_in_range, fn _, _, _, _, packet -> send(test_pid, packet) end)

      {:ok, group} = Unit.place(caster(), @skill_name, 7, {100, 120})

      assert group.visible? == false
      assert %Group{visible?: false} = Storage.get(group.group_id)
      assert [] == Storage.get_cells_by_group(group.group_id)

      assert [%Group{group_id: group_id}] = Storage.get_groups_at_cell("prontera", 100, 120)
      assert group_id == group.group_id

      assert %{groups: []} = Unit.snapshot("prontera")
      assert_receive %GroundSkill{}
      refute_received %Aesir.Net.SkillUnitSpawn{}
    end

    test "makes a ground field with an immediate first tick due on the next manager cadence" do
      stub(Catalog, :ground_module_for, fn @skill_name -> {:ok, ImmediateFakeUnit} end)
      stub(Broadcast, :to_in_range, fn _, _, _, _, _ -> :ok end)

      before = System.monotonic_time(:millisecond)
      {:ok, group} = Unit.place(caster(), @skill_name, 7, {100, 120})

      assert group.next_tick_at >= before
      assert group.next_tick_at < before + @interval
    end

    test "skips impassable and unreachable PathCheck cells" do
      stub(Catalog, :ground_module_for, fn @skill_name -> {:ok, PathCheckedUnit} end)
      stub(Broadcast, :to_in_range, fn _, _, _, _, _ -> :ok end)

      stub(MapCache, :get, fn "prontera" ->
        {:ok, %MapData{name: "prontera", xs: 100, ys: 100}}
      end)

      stub(Pathfinding, :find_path, fn
        _map, {50, 60}, {50, 60} -> {:ok, []}
        _map, {50, 60}, _cell -> {:error, :no_path}
      end)

      assert {:ok, %Group{cells: [{50, 60}]}} = Unit.place(caster(), @skill_name, 1, {50, 60})
    end

    test "filters a border layout to in-bounds cells before registering it" do
      stub(Catalog, :ground_module_for, fn @skill_name -> {:ok, BorderFakeUnit} end)
      stub(Broadcast, :to_in_range, fn _, _, _, _, _ -> :ok end)
      :ets.insert(EtsTable.table_for(:map_cache), {"border", MapData.new("border", 2, 2)})

      caster = %{caster() | map_name: "border"}
      assert {:ok, group} = Unit.place(caster, @skill_name, 7, {0, 0})

      assert group.cells == [{0, 0}, {0, 1}, {1, 0}, {1, 1}]

      assert Storage.get_cells_by_group(group.group_id) |> Enum.map(&{&1.x, &1.y}) |> Enum.sort() ==
               group.cells
    end

    test "rejects a border layout when its map is unavailable" do
      stub(Catalog, :ground_module_for, fn @skill_name -> {:ok, BorderFakeUnit} end)
      stub(Broadcast, :to_in_range, fn _, _, _, _, _ -> flunk("must not broadcast") end)

      caster = %{caster() | map_name: "missing_border"}
      assert {:error, :no_walkable_cells} = Unit.place(caster, @skill_name, 7, {0, 0})
      assert [] == Storage.all()
    end

    test "commits the group before broadcasting exactly one GroundSkill" do
      test_pid = self()

      stub(Broadcast, :to_in_range, fn map_name, x, y, _range, packet ->
        assert %Group{group_id: packet_group_id} =
                 Storage.all() |> List.first()

        assert packet_group_id > 0
        send(test_pid, {:broadcast, map_name, x, y, packet})
        :ok
      end)

      {:ok, group} = Unit.place(caster(), @skill_name, 7, {100, 120})

      assert_received {:broadcast, "prontera", 100, 120, %GroundSkill{} = packet}
      assert packet.skill_id == group.skill_id
      assert packet.src_id == 2_000
      assert packet.level == 7
      assert packet.x == 100
      assert packet.y == 120

      assert_received {:broadcast, "prontera", 100, 120, %Aesir.Net.SkillUnitSpawn{}}
      refute_received {:broadcast, "prontera", 100, 120, %GroundSkill{}}
    end

    test "resolves the skill_id from the catalog and renders a valid ground-cast packet" do
      test_pid = self()

      stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, packet ->
        send(test_pid, {:broadcast, packet})
        :ok
      end)

      {:ok, definition} = Catalog.by_name(@skill_name)
      {:ok, group} = Unit.place(caster(), @skill_name, 7, {100, 120})

      assert is_integer(definition.id)
      assert group.skill_id == definition.id

      assert_received {:broadcast, %GroundSkill{} = packet}
      assert packet.skill_id == definition.id
    end

    test "derives group identity fields from a mob caster" do
      stub(Broadcast, :to_in_range, fn _, _, _, _, _ -> :ok end)

      {:ok, %Group{} = group} = Unit.place(mob_caster(), @skill_name, 5, {100, 120})

      assert group.caster_id == 3_000
      assert group.caster_type == :mob
      assert group.map_name == "prontera"
      assert group.center == {100, 120}
    end

    test "returns an error for an unregistered skill" do
      stub(Catalog, :ground_module_for, fn _ -> :error end)

      assert {:error, :no_skill_unit_behaviour} =
               Unit.place(caster(), :unknown, 1, {10, 10})
    end
  end

  describe "destroy/1" do
    test "runs on_expire and deletes the group" do
      stub(Broadcast, :to_in_range, fn _, _, _, _, _ -> :ok end)

      {:ok, group} = Unit.place(caster(), @skill_name, 7, {100, 120})
      assert %Group{} = Storage.get(group.group_id)

      assert :ok = Unit.destroy(group.group_id)
      assert nil == Storage.get(group.group_id)
    end

    test "is a no-op for an unknown group_id" do
      assert :ok = Unit.destroy(999_999)
    end
  end

  describe "read facade" do
    test "reads visible snapshots and ranges from storage without the manager" do
      Process.delete({Manager, :server})

      visible = %Group{
        group_id: 1,
        skill_id: 1,
        skill_name: :sm_bash,
        level: 1,
        caster_id: 2_000,
        caster_type: :player,
        map_name: "prontera",
        center: {100, 100},
        cells: [{100, 100}],
        visible?: true
      }

      invisible = %{visible | group_id: 2, visible?: false}
      :ok = Storage.insert(visible)
      :ok = Storage.insert(invisible)

      assert %{groups: [%{group_id: 1}]} = Unit.snapshot("prontera")
      assert [%Group{group_id: 1}] = Unit.in_range("prontera", 100, 100, 0)
    end
  end
end
