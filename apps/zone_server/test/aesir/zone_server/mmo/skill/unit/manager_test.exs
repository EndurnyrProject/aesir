defmodule Aesir.ZoneServer.Mmo.Skill.Unit.ManagerTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup
  import ExUnit.CaptureLog
  import Mimic

  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.Cell, as: MapCell
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Cell
  alias Aesir.ZoneServer.Mmo.Skill.Unit.FieldSupport
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.LifecyclePolicy
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Lifecycle
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables
  setup :verify_on_exit!

  defmodule FakeUnit do
    @behaviour Ground

    alias Aesir.ZoneServer.Mmo.Skill.Unit.Group

    @impl Ground
    def on_place(%Group{center: center}) do
      {:ok, %{cells: [center], state: %{}, interval: 450, duration: 5_000}}
    end

    @impl Ground
    def on_interval(%Group{state: state} = group, _now) do
      if Map.get(state, :expire_now) do
        {:expire, group}
      else
        {:ok, %{group | state: Map.update(state, :ticks, 1, &(&1 + 1))}}
      end
    end

    @impl Ground
    def on_expire(%Group{group_id: group_id, state: state}) do
      if test_pid = state[:test_pid], do: send(test_pid, {:expired, group_id})
      :ok
    end
  end

  defmodule FieldUnit do
    @behaviour Ground

    alias Aesir.ZoneServer.Mmo.Skill.Unit.Group

    @impl Ground
    def on_place(%Group{center: center}) do
      {:ok, %{cells: [center], state: %{}, interval: 450, duration: 5_000}}
    end

    @impl Ground
    def on_interval(group, _now), do: {:ok, group}

    @impl Ground
    def on_expire(_group), do: :ok

    @impl Ground
    def field_support(_group) do
      %{status_type: :sc_quagmire, params: [], target?: fn _target -> true end}
    end
  end

  defmodule SerializedUnit do
    alias Aesir.ZoneServer.Mmo.Skill.Unit.Group

    def on_touch(%Group{state: %{test_pid: test_pid}} = group, mover) do
      send(test_pid, {:touch_started, self()})

      receive do
        :release_touch -> :ok
      end

      {:ok,
       %{
         group
         | caster_id: 22,
           target_type: elem(mover, 0),
           target_id: elem(mover, 1),
           map_name: "geffen",
           cells: [{20, 20}],
           expires_at: 30_000,
           state: Map.put(group.state, :touched, true)
       }}
    end

    def on_interval(%Group{state: state} = group, _now) do
      {:ok, %{group | state: Map.put(state, :ticked_after_touch, state[:touched] == true)}}
    end

    def on_expire(_group), do: :ok
  end

  defmodule FailingUnit do
    def on_interval(_group, _now), do: raise("callback failed")
    def on_expire(_group), do: :ok
  end

  defmodule ForeignIdUnit do
    alias Aesir.ZoneServer.Mmo.Skill.Unit.Group

    def on_interval(%Group{state: state} = group, _now) do
      updated = %{group | group_id: state.foreign_group_id, state: %{foreign: true}}

      case state.result do
        :ok -> {:ok, updated}
        :expire -> {:expire, updated}
      end
    end

    def on_expire(%Group{group_id: group_id, state: state}) do
      send(state.test_pid, {:expired, group_id})
      :ok
    end
  end

  defmodule WaterBallSequenceUnit do
    alias Aesir.ZoneServer.Mmo.Skill.Unit.Group

    def on_interval(%Group{state: %{test_pid: test_pid}} = group, _now) do
      send(test_pid, :water_ball_hit)
      {:ok, group}
    end
  end

  defmodule BlockedWaterBallUnit do
    alias Aesir.ZoneServer.Mmo.Skill.Unit.Group

    def on_interval(%Group{state: state} = group, _now) do
      {:ok, %{group | state: Map.put(state, :water_ball_fired, false)}}
    end
  end

  setup do
    stub(Catalog, :ground_module_for, fn
      :fake_unit -> {:ok, FakeUnit}
      :serialized_unit -> {:ok, SerializedUnit}
      :failing_unit -> {:ok, FailingUnit}
      :foreign_id_unit -> {:ok, ForeignIdUnit}
      :field_unit -> {:ok, FieldUnit}
      :water_ball_sequence -> {:ok, WaterBallSequenceUnit}
      :blocked_water_ball -> {:ok, BlockedWaterBallUnit}
      :other_exclusive_unit -> {:ok, FakeUnit}
      :barrier_unit -> {:ok, FakeUnit}
      :mg_safetywall -> {:ok, FakeUnit}
      :pr_magnus -> {:ok, FakeUnit}
    end)

    :ok
  end

  defp start_manager(now, opts \\ []) do
    manager =
      start_supervised!(
        {Manager,
         Keyword.merge(
           [
             name: nil,
             clock: fn -> now end,
             schedule_tick: fn _pid, _interval -> :ok end,
             unit_available?: fn _unit_type, _unit_id, _map_name -> true end
           ],
           opts
         )}
      )

    allow(Catalog, self(), manager)
    allow(Broadcast, self(), manager)
    manager
  end

  defp group(group_id, attrs) do
    base = %Group{
      group_id: group_id,
      skill_id: 0,
      skill_name: :fake_unit,
      level: 1,
      caster_id: 1,
      caster_type: :player,
      map_name: "prontera",
      center: {100, 100},
      cells: [{100, 100}],
      next_tick_at: 0,
      expires_at: 1_000_000,
      interval: 450,
      state: %{}
    }

    struct(base, attrs)
  end

  describe "targetable cells" do
    test "keeps visible group membership only in storage" do
      manager = start_manager(10_000)

      assert :ok = Manager.register(manager, group(1, visible?: true))

      refute Map.has_key?(Storage.get(1), :cell_ids)
      assert [%Cell{group_id: 1}] = Storage.get_cells_by_group(1)
    end

    test "materializes terrain and target indexes from a ground unit's cell attributes and publishes decayed HP in snapshots" do
      now = 10_000
      manager = start_manager(now)

      :ok =
        Manager.register(
          manager,
          group(1,
            visible?: true,
            next_tick_at: now,
            interval: 1_000,
            state: %{
              cell_decay: 50,
              cell_attrs: %{
                {100, 100} => %{
                  hp: 100,
                  max_hp: 100,
                  flags: [:targetable, :blocks_movement, :blocks_projectiles],
                  state: %{exclusive_terrain: true}
                }
              }
            }
          )
        )

      [cell] = Storage.get_cells_by_group(1)
      assert MapCell.dynamically_blocked?("prontera", 100, 100)
      assert {:ok, {_module, ^cell, ^manager}} = UnitRegistry.get_unit(:skill_unit, cell.cell_id)

      assert :ok = Manager.tick(manager, now)
      assert %Cell{hp: 50, max_hp: 100} = Storage.get_cell(cell.cell_id)
    end

    test "registers targetable group cells and removes every index on destruction" do
      manager = start_manager(10_000)

      :ok =
        Manager.register(
          manager,
          group(1,
            visible?: true,
            cells: [{100, 101}],
            state: %{cell_attrs: %{{100, 101} => %{hp: 20, max_hp: 20, flags: [:targetable]}}}
          )
        )

      [cell] = Storage.get_cells_by_group(1)

      assert {:ok, {_module, ^cell, ^manager}} = UnitRegistry.get_unit(:skill_unit, cell.cell_id)

      assert {:ok, {100, 101, "prontera"}} =
               SpatialIndex.get_unit_position(:skill_unit, cell.cell_id)

      assert [cell.cell_id] ==
               SpatialIndex.get_units_in_range(:skill_unit, "prontera", 100, 101, 0)

      assert {:destroyed, ^cell} =
               Manager.damage_targetable_cell(manager, cell.cell_id, 20, {:player, 1})

      assert {:error, :not_found} = UnitRegistry.get_unit(:skill_unit, cell.cell_id)
      assert {:error, :not_found} = SpatialIndex.get_unit_position(:skill_unit, cell.cell_id)
      assert {:error, :not_found} = Manager.targetable_cell(manager, cell.cell_id)
    end

    test "expires the group immediately when damage destroys its last cell" do
      manager = start_manager(10_000)

      :ok =
        Manager.register(
          manager,
          group(1,
            visible?: true,
            cells: [{100, 101}],
            state: %{cell_attrs: %{{100, 101} => %{hp: 20, max_hp: 20, flags: [:targetable]}}}
          )
        )

      [cell] = Storage.get_cells_by_group(1)

      assert {:destroyed, ^cell} =
               Manager.damage_targetable_cell(manager, cell.cell_id, 20, {:player, 1})

      assert Storage.get(1) == nil
    end

    test "keeps the group alive when damage destroys a non-last cell" do
      manager = start_manager(10_000)

      :ok =
        Manager.register(
          manager,
          group(1,
            visible?: true,
            cells: [{100, 101}, {100, 102}],
            state: %{
              cell_attrs: %{
                {100, 101} => %{hp: 20, max_hp: 20, flags: [:targetable]},
                {100, 102} => %{hp: 20, max_hp: 20, flags: [:targetable]}
              }
            }
          )
        )

      [first | _] = Storage.get_cells_by_group(1)

      assert {:destroyed, ^first} =
               Manager.damage_targetable_cell(manager, first.cell_id, 20, {:player, 1})

      assert %{group_id: 1} = Storage.get(1)
      assert [_survivor] = Storage.get_cells_by_group(1)
    end

    test "does not expose non-targetable cells as combat targets" do
      manager = start_manager(10_000)

      :ok =
        Manager.register(
          manager,
          group(1,
            visible?: true,
            cells: [{100, 101}],
            state: %{cell_attrs: %{{100, 101} => %{hp: 20, max_hp: 20, flags: []}}}
          )
        )

      [cell] = Storage.get_cells_by_group(1)

      assert {:error, :not_found} = UnitRegistry.get_unit(:skill_unit, cell.cell_id)
      assert {:error, :not_found} = SpatialIndex.get_unit_position(:skill_unit, cell.cell_id)
      assert {:error, :not_targetable} = Manager.targetable_cell(manager, cell.cell_id)
    end
  end

  describe "exclusive terrain" do
    test "rejects a synthetic exclusive skill while allowing nonexclusive terrain contributions" do
      manager = start_manager(10_000)

      exclusive =
        group(1,
          visible?: true,
          state: %{
            exclusive_terrain: true,
            cell_attrs: %{
              {100, 100} => %{
                flags: [:blocks_movement],
                state: %{exclusive_terrain: true}
              }
            }
          }
        )

      other_exclusive =
        group(2,
          skill_name: :other_exclusive_unit,
          visible?: true,
          state: %{
            exclusive_terrain: true,
            cell_attrs: %{
              {100, 100} => %{
                flags: [:blocks_projectiles],
                state: %{exclusive_terrain: true}
              }
            }
          }
        )

      nonexclusive =
        group(3,
          skill_name: :barrier_unit,
          visible?: true,
          state: %{cell_attrs: %{{100, 100} => %{flags: [:blocks_projectiles]}}}
        )

      assert :ok = Manager.register(manager, exclusive)
      assert {:error, :exclusive_terrain_overlap} = Manager.register(manager, other_exclusive)
      assert :ok = Manager.register(manager, nonexclusive)
      assert MapCell.dynamically_blocked?("prontera", 100, 100)
      assert MapCell.blocks_projectiles?("prontera", 100, 100)
    end
  end

  describe "Safety Wall serialization" do
    test "admits only one of two concurrent same-cell casts from different casters" do
      manager = start_manager(10_000)

      walls = [
        group(1, skill_id: 12, skill_name: :mg_safetywall, caster_id: 100),
        group(2, skill_id: 12, skill_name: :mg_safetywall, caster_id: 200)
      ]

      results =
        walls
        |> Enum.map(&Task.async(fn -> Manager.register(manager, &1) end))
        |> Task.await_many()

      assert Enum.frequencies(results) == %{:ok => 1, {:error, :safetywall_overlap} => 1}
      assert [%Group{skill_id: 12}] = Storage.all()
    end

    test "rejects an overlapping Magnus Exorcismus field" do
      manager = start_manager(10_000)

      assert :ok = Manager.register(manager, group(1, skill_id: 79, skill_name: :pr_magnus))

      assert {:error, :skill_unit_overlap} =
               Manager.register(manager, group(2, skill_id: 79, skill_name: :pr_magnus))
    end

    test "keeps Magnus visibility and expiry authoritative in the unit manager" do
      test_pid = self()

      stub(Broadcast, :to_player, fn observer_id, packet ->
        send(test_pid, {observer_id, packet})
      end)

      manager = start_manager(10_000)

      magnus =
        group(1,
          skill_id: 79,
          skill_name: :pr_magnus,
          visible?: true,
          created_at: 10_000,
          next_tick_at: 20_000,
          expires_at: 10_001
        )

      assert :ok = Manager.register(manager, magnus)
      assert MapSet.new([1]) == Manager.snapshot_for(manager, 99, "prontera", 100, 100, 0)
      assert_receive {99, %Aesir.Net.SkillUnitSnapshot{groups: [%{group_id: 1}]}}

      assert :ok = Manager.tick(manager, 10_001)
      assert nil == Storage.get(1)
    end

    test "preserves ordinary same-cell group stacking" do
      manager = start_manager(10_000)

      assert :ok = Manager.register(manager, group(1, caster_id: 100))
      assert :ok = Manager.register(manager, group(2, caster_id: 200))
      assert length(Storage.all()) == 2
    end

    test "serializes two occupant hits against the latest shared wall budget" do
      manager = start_manager(10_000)

      wall =
        group(1,
          skill_id: 12,
          skill_name: :mg_safetywall,
          state: %{hits_remaining: 2, shield_hp: 1_000}
        )

      assert :ok = Manager.register(manager, wall)

      results =
        [100, 200]
        |> Enum.map(fn _occupant ->
          Task.async(fn -> Manager.absorb_safetywall_hit(manager, wall.group_id, 100) end)
        end)
        |> Task.await_many()

      assert Enum.frequencies(results) == %{
               {:block, :keep} => 1,
               {:block, :remove} => 1
             }

      assert nil == Storage.get(wall.group_id)
      assert :pass = Manager.absorb_safetywall_hit(manager, wall.group_id, 100)
    end

    test "serializes concurrent hits against the latest shared HP pool" do
      manager = start_manager(10_000)

      wall =
        group(1,
          skill_id: 12,
          skill_name: :mg_safetywall,
          state: %{hits_remaining: 6, shield_hp: 150}
        )

      assert :ok = Manager.register(manager, wall)

      results =
        [100, 200]
        |> Enum.map(fn _occupant ->
          Task.async(fn -> Manager.absorb_safetywall_hit(manager, wall.group_id, 100) end)
        end)
        |> Task.await_many()

      assert Enum.frequencies(results) == %{
               {:block, :keep} => 1,
               {:block, :remove} => 1
             }

      assert nil == Storage.get(wall.group_id)
    end
  end

  describe "Water Ball sequences" do
    test "claims water sources in caller order when source cell IDs are reused" do
      manager = start_manager(10_000)

      second_source =
        group(1,
          visible?: true,
          cells: [{101, 100}],
          next_tick_at: 20_000,
          state: %{cell_attrs: %{{101, 100} => %{flags: [:consumable_water]}}}
        )

      first_source =
        group(2,
          visible?: true,
          cells: [{100, 100}],
          next_tick_at: 20_000,
          state: %{cell_attrs: %{{100, 100} => %{flags: [:consumable_water]}}}
        )

      assert :ok = Manager.register(manager, second_source)
      assert :ok = Manager.register(manager, first_source)

      sequence =
        group(3,
          skill_name: :water_ball_sequence,
          visible?: false,
          cells: [],
          next_tick_at: 10_000,
          state: %{water_ball_sequence: true, test_pid: self()}
        )

      assert {:ok, %Group{}} =
               Manager.register_water_ball_sequence(manager, sequence, [{100, 100}, {101, 100}])

      assert :ok = Manager.tick(manager, 10_000)
      assert [%Cell{x: 101, y: 100}] = Storage.get_cells_by_group(sequence.group_id)
    end

    test "uses each claimed water cell once and expires when the sequence is empty" do
      manager = start_manager(10_000)

      :ok =
        Manager.register(
          manager,
          group(1,
            visible?: true,
            state: %{cell_attrs: %{{100, 100} => %{flags: [:consumable_water]}}}
          )
        )

      sequence =
        group(2,
          skill_name: :water_ball_sequence,
          visible?: false,
          cells: [],
          next_tick_at: 10_000,
          state: %{water_ball_sequence: true, test_pid: self()}
        )

      assert {:ok, %Group{}} =
               Manager.register_water_ball_sequence(manager, sequence, [{100, 100}])

      [%Cell{cell_id: claimed_id}] = Storage.get_cells_by_group(2)
      assert %Cell{cell_id: ^claimed_id, group_id: 2} = Storage.get_cell(claimed_id)

      assert :ok = Manager.tick(manager, 10_000)
      assert_received :water_ball_hit
      assert nil == Storage.get_cell(claimed_id)

      assert :ok = Manager.tick(manager, 10_450)
      assert nil == Storage.get(2)
      refute_received :water_ball_hit
    end

    test "retains the claimed water charge when a blocked shot does not fire" do
      manager = start_manager(10_000)

      :ok =
        Manager.register(
          manager,
          group(1,
            visible?: true,
            state: %{cell_attrs: %{{100, 100} => %{flags: [:consumable_water]}}}
          )
        )

      sequence =
        group(2,
          skill_name: :blocked_water_ball,
          visible?: false,
          cells: [],
          interval: 150,
          next_tick_at: 10_000,
          state: %{water_ball_sequence: true}
        )

      assert {:ok, %Group{}} =
               Manager.register_water_ball_sequence(manager, sequence, [{100, 100}])

      assert [%Cell{cell_id: claimed_id}] = Storage.get_cells_by_group(2)

      assert :ok = Manager.tick(manager, 10_000)

      assert [%Cell{cell_id: ^claimed_id}] = Storage.get_cells_by_group(2)
      assert %Group{next_tick_at: 10_150} = Storage.get(2)
    end

    test "concurrent casts cannot convert another Water Ball token into a source" do
      manager = start_manager(10_000)

      :ok =
        Manager.register(
          manager,
          group(1,
            visible?: true,
            state: %{cell_attrs: %{{100, 100} => %{flags: [:consumable_water]}}}
          )
        )

      results =
        [2, 3]
        |> Task.async_stream(fn group_id ->
          Manager.register_water_ball_sequence(
            manager,
            group(group_id,
              skill_name: :water_ball_sequence,
              visible?: false,
              cells: [],
              state: %{water_ball_sequence: true}
            ),
            [{100, 100}]
          )
        end)
        |> Enum.map(fn {:ok, result} -> result end)

      assert Enum.count(results, &match?({:ok, _}, &1)) == 1
      assert Enum.count(results, &(&1 == {:error, :no_water_source})) == 1
    end
  end

  describe "per-caster instance limits" do
    test "removes the oldest matching group when a fourth group is registered" do
      manager = start_manager(10_000)
      policy = %LifecyclePolicy{max_instances_per_caster: 3}

      for {group_id, expires_at} <- [{1, 1_000}, {2, 2_000}, {3, 3_000}, {4, 4_000}] do
        assert :ok =
                 Manager.register(
                   manager,
                   group(group_id,
                     skill_name: :fake_unit,
                     expires_at: expires_at,
                     lifecycle_policy: policy
                   )
                 )
      end

      assert Storage.get(1) == nil

      assert Enum.map(Storage.get_groups_by_caster(:player, 1), & &1.group_id) |> Enum.sort() == [
               2,
               3,
               4
             ]
    end

    test "keeps the newly cast group and evicts the oldest existing one on overflow" do
      manager = start_manager(10_000)
      policy = %LifecyclePolicy{max_instances_per_caster: 2}

      for {group_id, created_at, expires_at} <- [
            {10, 1_000, 9_000},
            {20, 2_000, 8_000},
            {30, 3_000, 7_000}
          ] do
        assert :ok =
                 Manager.register(
                   manager,
                   group(group_id,
                     skill_name: :fake_unit,
                     created_at: created_at,
                     expires_at: expires_at,
                     lifecycle_policy: policy
                   )
                 )
      end

      assert Storage.get(10) == nil

      assert Enum.map(Storage.get_groups_by_caster(:player, 1), & &1.group_id) |> Enum.sort() == [
               20,
               30
             ]
    end

    test "keeps a short-lived new cast and destroys the oldest long-lived instance" do
      manager = start_manager(10_000)
      policy = %LifecyclePolicy{max_instances_per_caster: 3}

      for {group_id, created_at} <- [{1, 1_000}, {2, 2_000}, {3, 3_000}] do
        assert :ok =
                 Manager.register(
                   manager,
                   group(group_id,
                     skill_name: :fake_unit,
                     created_at: created_at,
                     expires_at: 1_000_000,
                     lifecycle_policy: policy
                   )
                 )
      end

      assert :ok =
               Manager.register(
                 manager,
                 group(4,
                   skill_name: :fake_unit,
                   created_at: 4_000,
                   expires_at: 20_000,
                   lifecycle_policy: policy
                 )
               )

      assert %Group{} = Storage.get(4)
      assert Storage.get(1) == nil

      assert Enum.map(Storage.get_groups_by_caster(:player, 1), & &1.group_id) |> Enum.sort() == [
               2,
               3,
               4
             ]
    end

    test "does not evict groups from another caster or skill" do
      manager = start_manager(10_000)
      policy = %LifecyclePolicy{max_instances_per_caster: 1}

      assert :ok =
               Manager.register(
                 manager,
                 group(1, skill_name: :fake_unit, expires_at: 1_000, lifecycle_policy: policy)
               )

      assert :ok =
               Manager.register(
                 manager,
                 group(2,
                   skill_name: :serialized_unit,
                   expires_at: 1_000,
                   lifecycle_policy: policy
                 )
               )

      assert :ok =
               Manager.register(
                 manager,
                 group(3,
                   skill_name: :fake_unit,
                   caster_id: 2,
                   expires_at: 1_000,
                   lifecycle_policy: policy
                 )
               )

      assert :ok =
               Manager.register(
                 manager,
                 group(4, skill_name: :fake_unit, expires_at: 2_000, lifecycle_policy: policy)
               )

      assert Storage.get(1) == nil
      assert %Group{} = Storage.get(2)
      assert %Group{} = Storage.get(3)
      assert %Group{} = Storage.get(4)
    end

    test "leaves uncapped groups active" do
      manager = start_manager(10_000)

      for group_id <- 1..4 do
        assert :ok =
                 Manager.register(
                   manager,
                   group(group_id, skill_name: :fake_unit, expires_at: group_id * 1_000)
                 )
      end

      assert Enum.map(Storage.get_groups_by_caster(:player, 1), & &1.group_id) |> Enum.sort() == [
               1,
               2,
               3,
               4
             ]
    end
  end

  describe "tick/1" do
    test "runs only due groups, re-arms their deadline, and uses the injected clock" do
      now = 10_000
      manager = start_manager(now)
      :ok = Manager.register(manager, group(1, next_tick_at: now - 10, interval: 450))
      :ok = Manager.register(manager, group(2, next_tick_at: now + 500))

      assert :ok = Manager.tick(manager)

      assert %Group{next_tick_at: 10_450, state: %{ticks: 1}} = Storage.get(1)
      assert %Group{next_tick_at: 10_500, state: %{}} = Storage.get(2)
    end

    test "uses the reindexed deadline after an interval update" do
      now = 10_000
      manager = start_manager(now)
      :ok = Manager.register(manager, group(1, next_tick_at: now, interval: 450))

      assert :ok = Manager.tick(manager, now)
      assert :ok = Manager.tick(manager, now + 449)
      assert Storage.get(1).state[:ticks] == 1

      assert :ok = Manager.tick(manager, now + 450)
      assert Storage.get(1).state[:ticks] == 2
    end

    test "expires a due group at most once" do
      now = 10_000
      manager = start_manager(now)

      :ok =
        Manager.register(
          manager,
          group(1,
            next_tick_at: now - 10,
            expires_at: now - 10,
            state: %{expire_now: true, test_pid: self()}
          )
        )

      assert :ok = Manager.tick(manager)

      assert_received {:expired, 1}
      refute_received {:expired, 1}
      assert nil == Storage.get(1)
    end

    test "tears down a group when on_interval returns expire before its deadline" do
      now = 10_000
      manager = start_manager(now)

      :ok =
        Manager.register(
          manager,
          group(1,
            next_tick_at: now,
            expires_at: now + 5_000,
            state: %{expire_now: true, test_pid: self()}
          )
        )

      assert :ok = Manager.tick(manager)

      assert_received {:expired, 1}
      assert nil == Storage.get(1)
    end

    test "runs expiry cleanup for a group that is not due for an interval" do
      now = 10_000
      manager = start_manager(now)

      :ok =
        Manager.register(
          manager,
          group(1,
            next_tick_at: now + 5_000,
            expires_at: now,
            state: %{test_pid: self()}
          )
        )

      assert :ok = Manager.tick(manager)

      assert_received {:expired, 1}
      assert nil == Storage.get(1)
    end

    test "cleans only a callback's group and logs its skill and group identity" do
      now = 10_000
      manager = start_manager(now)

      :ok =
        Manager.register(
          manager,
          group(1, skill_name: :failing_unit, next_tick_at: now)
        )

      :ok = Manager.register(manager, group(2, next_tick_at: now))

      log = capture_log(fn -> assert :ok = Manager.tick(manager) end)

      assert log =~ "failing_unit"
      assert log =~ "group_id=1"
      assert nil == Storage.get(1)
      assert %Group{state: %{ticks: 1}} = Storage.get(2)
    end

    test "rejects an updated group with a foreign id without overwriting that group" do
      now = 10_000
      manager = start_manager(now)
      other = group(2, next_tick_at: now + 5_000, state: %{untouched: true})

      :ok =
        Manager.register(
          manager,
          group(1,
            skill_name: :foreign_id_unit,
            next_tick_at: now,
            state: %{
              result: :ok,
              foreign_group_id: other.group_id,
              test_pid: self()
            }
          )
        )

      :ok = Manager.register(manager, other)

      log = capture_log(fn -> assert :ok = Manager.tick(manager) end)

      assert log =~ "foreign_id_unit"
      assert log =~ "group_id=1"
      assert_received {:expired, 1}
      assert nil == Storage.get(1)
      assert ^other = Storage.get(2)
      assert [] == Storage.get_due_groups(now)
      assert [%Group{group_id: 2}] = Storage.get_due_groups(now + 5_000)
    end

    test "rejects an expired group with a foreign id without deleting that group" do
      now = 10_000
      manager = start_manager(now)
      other = group(2, next_tick_at: now + 5_000, state: %{untouched: true})

      :ok =
        Manager.register(
          manager,
          group(1,
            skill_name: :foreign_id_unit,
            next_tick_at: now,
            state: %{
              result: :expire,
              foreign_group_id: other.group_id,
              test_pid: self()
            }
          )
        )

      :ok = Manager.register(manager, other)

      log = capture_log(fn -> assert :ok = Manager.tick(manager) end)

      assert log =~ "foreign_id_unit"
      assert log =~ "group_id=1"
      assert_received {:expired, 1}
      assert nil == Storage.get(1)
      assert ^other = Storage.get(2)
      assert [] == Storage.get_due_groups(now)
      assert [%Group{group_id: 2}] = Storage.get_due_groups(now + 5_000)
    end
  end

  describe "unit lifecycle events" do
    test "caster death expires only indexed groups and duplicate events stay idempotent" do
      now = 10_000
      manager = start_manager(now)

      affected =
        group(1,
          next_tick_at: now + 5_000,
          expires_at: now + 10_000,
          state: %{test_pid: self()},
          lifecycle_policy: %LifecyclePolicy{on_caster_loss: :expire}
        )

      unrelated =
        group(2,
          caster_id: 2,
          next_tick_at: now + 50_000,
          expires_at: now + 100_000,
          state: %{untouched: true}
        )

      :ok = Manager.register(manager, affected)
      :ok = Manager.register(manager, unrelated)

      :ok = Lifecycle.publish_death(:player, 1, "prontera")
      assert :ok = Manager.tick(manager, now)

      assert_received {:expired, 1}
      assert nil == Storage.get(1)
      assert ^unrelated = Storage.get(2)

      :ok = Lifecycle.publish_death(:player, 1, "prontera")
      assert :ok = Manager.tick(manager, now + 10_000)
      refute_received {:expired, 1}
      assert ^unrelated = Storage.get(2)
    end

    test "map loss skips scheduled actions only on the old map" do
      now = 10_000

      manager =
        start_manager(now,
          unit_available?: fn
            :player, 1, "prontera" -> false
            _unit_type, _unit_id, _map_name -> true
          end
        )

      skip =
        group(1,
          next_tick_at: now,
          lifecycle_policy: %LifecyclePolicy{on_caster_loss: :skip_action}
        )

      new_map =
        group(2,
          map_name: "geffen",
          next_tick_at: now + 5_000,
          lifecycle_policy: %LifecyclePolicy{on_caster_loss: :skip_action}
        )

      Enum.each([skip, new_map], &Manager.register(manager, &1))

      :ok = Lifecycle.publish_transition(:player, 1, "prontera", "geffen")
      assert :ok = Manager.tick(manager, now)

      assert %Group{next_tick_at: 10_450} = Storage.get(1)
      assert Storage.get(1).state == %{}
      assert ^new_map = Storage.get(2)
    end

    test "target disappearance expires only groups in the target index" do
      now = 10_000
      manager = start_manager(now)

      affected =
        group(1,
          target_type: :mob,
          target_id: 99,
          next_tick_at: now + 5_000,
          state: %{test_pid: self()},
          lifecycle_policy: %LifecyclePolicy{on_target_loss: :expire}
        )

      unrelated =
        group(2,
          target_type: :mob,
          target_id: 100,
          next_tick_at: now + 5_000,
          state: %{untouched: true},
          lifecycle_policy: %LifecyclePolicy{on_target_loss: :expire}
        )

      :ok = Manager.register(manager, affected)
      :ok = Manager.register(manager, unrelated)

      :ok = Lifecycle.publish_departure(:mob, 99, "prontera", :termination)
      assert :ok = Manager.tick(manager, now)

      assert_received {:expired, 1}
      assert nil == Storage.get(1)
      assert ^unrelated = Storage.get(2)
    end

    test "tick revalidation applies loss policy when a lifecycle event was missed" do
      now = 10_000

      manager =
        start_supervised!(
          {Manager, name: nil, clock: fn -> now end, schedule_tick: fn _pid, _interval -> :ok end}
        )

      allow(Catalog, self(), manager)

      :ok =
        Manager.register(
          manager,
          group(1,
            next_tick_at: now,
            state: %{test_pid: self()},
            lifecycle_policy: %LifecyclePolicy{on_caster_loss: :expire}
          )
        )

      assert :ok = Manager.tick(manager, now)

      assert_received {:expired, 1}
      assert nil == Storage.get(1)
    end
  end

  test "serializes a concurrent touch before a queued tick and keeps every index consistent" do
    now = 10_000
    manager = start_manager(now)

    :ok =
      Manager.register(
        manager,
        group(1,
          skill_name: :serialized_unit,
          next_tick_at: now,
          expires_at: 20_000,
          state: %{test_pid: self()}
        )
      )

    touch = Task.async(fn -> Manager.trigger(manager, 1, {:player, 99}, :on_touch) end)
    assert_receive {:touch_started, ^manager}

    tick = Task.async(fn -> Manager.tick(manager) end)
    send(manager, :release_touch)

    assert :ok = Task.await(touch)
    assert :ok = Task.await(tick)

    assert %Group{
             caster_type: :player,
             caster_id: 22,
             target_type: :player,
             target_id: 99,
             map_name: "geffen",
             cells: [{20, 20}],
             next_tick_at: 10_450,
             expires_at: 30_000,
             state: %{ticked_after_touch: true}
           } = Storage.get(1)

    assert [] == Storage.get_groups_at_cell("prontera", 100, 100)
    assert [] == Storage.get_groups_by_caster(:player, 1)
    assert [] == Storage.get_expired_groups(20_000)
    assert [%Group{group_id: 1}] = Storage.get_groups_at_cell("geffen", 20, 20)
    assert [%Group{group_id: 1}] = Storage.get_groups_by_caster(:player, 22)
    assert [%Group{group_id: 1}] = Storage.get_groups_by_target(:player, 99)
    assert [%Group{group_id: 1}] = Storage.get_due_groups(10_450)
    assert [%Group{group_id: 1}] = Storage.get_expired_groups(30_000)
  end

  test "serializes concurrent delete and late update without resurrecting any index" do
    manager = start_manager(10_000)

    :ok =
      Manager.register(
        manager,
        group(1, target_type: :mob, target_id: 33, next_tick_at: 20_000, expires_at: 30_000)
      )

    delete = Task.async(fn -> Manager.destroy(manager, 1) end)
    update = Task.async(fn -> Manager.update_state(manager, 1, %{late: true}) end)

    assert :ok = Task.await(delete)
    assert :ok = Task.await(update)
    assert nil == Storage.get(1)

    for table <- [
          :skill_unit_coordinate_index,
          :skill_unit_due_index,
          :skill_unit_expiry_index,
          :skill_unit_caster_index,
          :skill_unit_target_index
        ] do
      assert [] == :ets.tab2list(EtsTable.table_for(table))
    end
  end

  test "materializes visible groups and excludes invisible groups from the range index" do
    manager = start_manager(10_000)
    visible = group(1, visible?: true, cells: [{100, 100}], created_at: 10_000)
    later_visible = group(3, visible?: true, cells: [{100, 100}], created_at: 10_000)
    invisible = group(2, visible?: false, cells: [{100, 100}])
    Enum.each([later_visible, visible, invisible], &Manager.register(manager, &1))

    assert [%Group{group_id: 1}, %Group{group_id: 3}] =
             Storage.get_visible_groups_in_range("prontera", 100, 100, 0)
  end

  test "publishes observer-specific snapshots and visibility transitions with current cells" do
    test_pid = self()

    stub(Broadcast, :to_player, fn observer_id, packet ->
      send(test_pid, {observer_id, packet})
    end)

    manager = start_manager(10_000)

    :ok =
      Manager.register(
        manager,
        group(1,
          visible?: true,
          cells: [{100, 100}, {101, 100}],
          created_at: 10_000,
          state: %{cell_attrs: %{{100, 100} => %{hp: 60, max_hp: 100}}}
        )
      )

    :ok = Manager.register(manager, group(2, visible?: false, cells: [{100, 100}]))
    [damaged | _] = Storage.get_cells_by_group(1)

    assert MapSet.new([1]) == Manager.snapshot_for(manager, 99, "prontera", 100, 100, 1)

    assert_receive {99,
                    %Aesir.Net.SkillUnitSnapshot{
                      groups: [%{group_id: 1, cells: cells}]
                    }}

    assert Enum.find(cells, &(&1.cell_id == damaged.cell_id)).hp == 60

    assert MapSet.new() == Manager.sync_view(manager, 99, [], [1])

    assert_receive {99,
                    %Aesir.Net.SkillUnitDespawn{
                      group_id: 1,
                      reason: :SKILL_UNIT_DESPAWN_REASON_LEFT_VIEW
                    }}

    assert MapSet.new([1]) == Manager.sync_view(manager, 99, [1], [])
    assert_receive {99, %Aesir.Net.SkillUnitSpawn{group: %{group_id: 1, cells: cells}}}
    assert Enum.find(cells, &(&1.cell_id == damaged.cell_id)).hp == 60

    assert MapSet.new() == Manager.sync_view(manager, 99, [], [1])

    assert_receive {99,
                    %Aesir.Net.SkillUnitDespawn{
                      group_id: 1,
                      cell_ids: cell_ids,
                      reason: :SKILL_UNIT_DESPAWN_REASON_LEFT_VIEW
                    }}

    assert Enum.sort(cell_ids) == Enum.sort(Enum.map(cells, & &1.cell_id))

    assert MapSet.new() == Manager.sync_view(manager, 99, [999], [])
  end

  test "keeps a registered corpse as an observer while excluding it from field support" do
    test_pid = self()

    stub(Broadcast, :to_player, fn observer_id, packet ->
      send(test_pid, {observer_id, packet})
    end)

    reject(&Interpreter.apply_status/4)

    :ok = SpatialIndex.add_unit(:player, 43, 100, 100, "prontera")

    :ok =
      UnitRegistry.register_unit(
        :player,
        43,
        PlayerState,
        %PlayerState{character_id: 43, action_state: :dead, stats: %{current_state: %{hp: 0}}},
        self()
      )

    manager = start_manager(10_000)
    allow(Interpreter, self(), manager)

    assert :ok =
             Manager.register(
               manager,
               group(1,
                 skill_name: :field_unit,
                 visible?: true,
                 cells: [{100, 100}],
                 created_at: 10_000
               )
             )

    assert [] == FieldSupport.sources_for_group(1)
    assert MapSet.new([1]) == Manager.snapshot_for(manager, 43, "prontera", 100, 100, 0)
    assert_receive {43, %Aesir.Net.SkillUnitSnapshot{groups: [%{group_id: 1}]}}
  end

  test "syncs multiple visibility transitions once, in order, and idempotently" do
    test_pid = self()

    stub(Broadcast, :to_player, fn observer_id, packet ->
      send(test_pid, {observer_id, packet})
    end)

    manager = start_manager(10_000)

    assert :ok = Manager.register(manager, group(1, visible?: true, created_at: 10_000))
    assert :ok = Manager.register(manager, group(2, visible?: true, created_at: 10_000))

    assert MapSet.new([1, 2]) == Manager.sync_view(manager, 99, [2, 1, 2], [])

    assert_receive {99, %Aesir.Net.SkillUnitSpawn{group: %{group_id: 1}}}
    assert_receive {99, %Aesir.Net.SkillUnitSpawn{group: %{group_id: 2}}}
    refute_receive {99, %Aesir.Net.SkillUnitSpawn{}}

    assert MapSet.new([1, 2]) == Manager.sync_view(manager, 99, [1, 2], [])
    refute_receive {99, %Aesir.Net.SkillUnitSpawn{}}

    assert MapSet.new() == Manager.sync_view(manager, 99, [2], [1, 1, 2])

    assert_receive {99,
                    %Aesir.Net.SkillUnitDespawn{
                      group_id: 1,
                      reason: :SKILL_UNIT_DESPAWN_REASON_LEFT_VIEW
                    }}

    assert_receive {99,
                    %Aesir.Net.SkillUnitDespawn{
                      group_id: 2,
                      reason: :SKILL_UNIT_DESPAWN_REASON_LEFT_VIEW
                    }}

    assert :ok = Manager.destroy(manager, 1)
    assert :ok = Manager.destroy(manager, 2)
    refute_receive {99, %Aesir.Net.SkillUnitDespawn{}}
  end

  test "returns current visibility when an entered group expires before sync" do
    manager = start_manager(10_000)
    assert :ok = Manager.register(manager, group(1, visible?: true, created_at: 10_000))
    assert :ok = Manager.destroy(manager, 1)

    assert MapSet.new() == Manager.sync_view(manager, 99, [1], [])
  end

  test "despawns a destroyed multi-cell group for a movement-edge observer outside its center range" do
    test_pid = self()

    stub(Broadcast, :to_player, fn observer_id, packet ->
      send(test_pid, {observer_id, packet})
    end)

    manager = start_manager(10_000)

    assert :ok =
             Manager.register(
               manager,
               group(1,
                 visible?: true,
                 center: {100, 100},
                 cells: [{100, 100}, {115, 100}],
                 created_at: 10_000
               )
             )

    assert MapSet.new([1]) == Manager.sync_view(manager, 99, [1], [])
    assert_receive {99, %Aesir.Net.SkillUnitSpawn{group: %{group_id: 1}}}

    assert :ok = Manager.destroy(manager, 1)

    assert_receive {99,
                    %Aesir.Net.SkillUnitDespawn{
                      group_id: 1,
                      reason: :SKILL_UNIT_DESPAWN_REASON_CANCELED
                    }}
  end

  test "despawns an early-torn-down group for a view-range player that never registered as observer" do
    test_pid = self()

    stub(Broadcast, :to_player, fn observer_id, packet ->
      send(test_pid, {observer_id, packet})
    end)

    manager = start_manager(10_000)

    :ok = SpatialIndex.add_unit(:player, 42, 100, 100, "prontera")

    assert :ok =
             Manager.register(
               manager,
               group(1, visible?: true, center: {100, 100}, created_at: 10_000)
             )

    assert MapSet.new() == Storage.get_observer_groups(42)

    assert :ok = Manager.destroy(manager, 1)

    assert_receive {42,
                    %Aesir.Net.SkillUnitDespawn{
                      group_id: 1,
                      reason: :SKILL_UNIT_DESPAWN_REASON_CANCELED
                    }}
  end

  test "tears down post-registration cells and despawns every captured ID" do
    test_pid = self()

    stub(Broadcast, :to_player, fn observer_id, packet ->
      send(test_pid, {observer_id, packet})
    end)

    manager = start_manager(10_000)
    assert :ok = Manager.register(manager, group(1, visible?: true, created_at: 10_000))
    [initial] = Storage.get_cells_by_group(1)

    post_registration = %Cell{
      cell_id: initial.cell_id + 1,
      group_id: 1,
      map_name: "prontera",
      x: 101,
      y: 100,
      flags: Cell.visible()
    }

    assert :ok = Storage.insert_cell(post_registration)
    assert MapSet.new([1]) == Manager.sync_view(manager, 99, [1], [])
    assert_receive {99, %Aesir.Net.SkillUnitSpawn{}}

    assert :ok = Manager.destroy(manager, 1)

    assert_receive {99,
                    %Aesir.Net.SkillUnitDespawn{
                      group_id: 1,
                      cell_ids: cell_ids,
                      reason: :SKILL_UNIT_DESPAWN_REASON_CANCELED
                    }}

    assert Enum.sort(cell_ids) == Enum.sort([initial.cell_id, post_registration.cell_id])
    assert nil == Storage.get_cell(initial.cell_id)
    assert nil == Storage.get_cell(post_registration.cell_id)
  end

  test "despawns a group destroyed immediately after its map-load snapshot" do
    test_pid = self()

    stub(Broadcast, :to_player, fn observer_id, packet ->
      send(test_pid, {observer_id, packet})
    end)

    manager = start_manager(10_000)
    assert :ok = Manager.register(manager, group(1, visible?: true, created_at: 10_000))

    assert MapSet.new([1]) == Manager.snapshot_for(manager, 99, "prontera", 100, 100, 0)
    assert_receive {99, %Aesir.Net.SkillUnitSnapshot{groups: [%{group_id: 1}]}}

    assert :ok = Manager.destroy(manager, 1)

    assert_receive {99,
                    %Aesir.Net.SkillUnitDespawn{
                      group_id: 1,
                      reason: :SKILL_UNIT_DESPAWN_REASON_CANCELED
                    }}
  end

  test "leaves explicitly invisible group-only fields unmaterialized" do
    manager = start_manager(10_000)
    invisible = group(1, visible?: false, cells: [{100, 100}], created_at: 10_000)

    assert :ok = Manager.register(manager, invisible)
    assert [] == Storage.get_cells_by_group(1)
    refute Map.has_key?(Storage.get(1), :cell_ids)
  end

  test "re-registering a visible group replaces every owned cell and index" do
    manager = start_manager(10_000)

    original =
      group(1,
        visible?: true,
        cells: [{100, 100}, {101, 100}],
        created_at: 10_000
      )

    replacement =
      group(1,
        visible?: true,
        cells: [{102, 100}],
        created_at: 10_000
      )

    assert :ok = Manager.register(manager, original)
    assert :ok = Manager.register(manager, replacement)

    assert [%Cell{x: 102, y: 100}] = Storage.get_cells_by_group(1)
  end

  test "re-registering releases field support owned by the replaced group" do
    manager = start_manager(10_000)
    original = group(1, visible?: false, cells: [{100, 100}])
    replacement = group(1, visible?: false, cells: [{101, 100}])

    assert :ok = Manager.register(manager, original)

    key = {:player, 99, :sc_quagmire, 1}
    :ets.insert(EtsTable.table_for(:field_supports), {key, %{params: [], aggregate: nil}})
    :ets.insert(EtsTable.table_for(:field_support_unit_index), {{:player, 99}, key})
    :ets.insert(EtsTable.table_for(:field_support_group_index), {1, key})

    assert FieldSupport.sources_for_group(1) != []
    assert :ok = Manager.register(manager, replacement)
    assert [] == FieldSupport.sources_for_group(1)
  end

  test "commits, removes, and reconciles terrain contributions owned by groups" do
    manager = start_unmanaged_manager(10_000)
    :ok = MapCell.put("prontera", 102, 100, :other_owner, 1, blocks_movement: true)

    :ok =
      Manager.register(
        manager,
        group(1,
          visible?: true,
          cells: [{100, 100}],
          state: %{cell_attrs: %{{100, 100} => %{flags: [:blocks_movement, :blocks_projectiles]}}}
        )
      )

    refute MapCell.traversable?("prontera", 100, 100)
    assert MapCell.blocks_projectiles?("prontera", 100, 100)

    assert :ok = Manager.destroy(manager, 1)
    assert MapCell.traversable?("prontera", 100, 100)
    refute MapCell.blocks_projectiles?("prontera", 100, 100)

    :ok =
      Manager.register(
        manager,
        group(2,
          visible?: true,
          cells: [{101, 100}],
          state: %{cell_attrs: %{{101, 100} => %{flags: [:consumable_water]}}}
        )
      )

    :ok = MapCell.put("prontera", 103, 100, :skill_unit, 999, blocks_movement: true)
    assert :ok = GenServer.stop(manager)

    [water] = Storage.get_cells_by_group(2)
    water_id = water.cell_id

    assert %MapCell.WaterSource{origin: :skill_unit, cell_id: ^water_id} =
             MapCell.water_source("prontera", 101, 100)

    restarted_manager = start_unmanaged_manager(10_000)

    assert %MapCell.WaterSource{origin: :skill_unit, cell_id: ^water_id} =
             MapCell.water_source("prontera", 101, 100)

    refute MapCell.traversable?("prontera", 102, 100)
    assert MapCell.traversable?("prontera", 103, 100)

    assert :ok = Manager.destroy(restarted_manager, 2)
    assert MapCell.water_source("prontera", 101, 100) == nil
    refute MapCell.traversable?("prontera", 102, 100)
  end

  test "logs and survives an unknown cast" do
    manager = start_manager(10_000)

    log =
      capture_log(fn ->
        GenServer.cast(manager, :unexpected)
        assert :ok = Manager.tick(manager)
      end)

    assert Process.alive?(manager)
    assert log =~ "Ignoring unknown skill-unit manager cast: :unexpected"
  end

  describe "remove_cells/3" do
    test "despawns only the removed coordinates and keeps the surviving cells live" do
      test_pid = self()

      stub(Broadcast, :to_in_range, fn _map_name, _x, _y, _range, packet ->
        send(test_pid, {:in_range, packet})
      end)

      manager = start_manager(10_000)

      :ok =
        Manager.register(
          manager,
          group(1, visible?: true, cells: [{100, 100}, {101, 100}], next_tick_at: 10_000)
        )

      removed = Enum.find(Storage.get_cells_by_group(1), &(&1.x == 101))

      assert :ok = Manager.remove_cells(manager, 1, [{101, 100}])

      assert_receive {:in_range,
                      %Aesir.Net.SkillUnitDespawn{
                        group_id: 1,
                        cell_ids: cell_ids,
                        reason: :SKILL_UNIT_DESPAWN_REASON_DESTROYED
                      }}

      assert cell_ids == [removed.cell_id]

      assert %Group{cells: [{100, 100}]} = Storage.get(1)
      assert [%Cell{x: 100}] = Storage.get_cells_by_group(1)
      assert [] == Storage.get_groups_at_cell("prontera", 101, 100)
      assert [%Group{group_id: 1}] = Storage.get_groups_at_cell("prontera", 100, 100)

      assert :ok = Manager.remove_cells(manager, 1, [{101, 100}])
      refute_received {:in_range, %Aesir.Net.SkillUnitDespawn{}}
      assert %Group{cells: [{100, 100}]} = Storage.get(1)

      assert :ok = Manager.tick(manager, 10_000)
      assert %Group{state: %{ticks: 1}} = Storage.get(1)
    end

    test "expires the group through the cleanup path when its last cell goes" do
      test_pid = self()

      stub(Broadcast, :to_player, fn observer_id, packet ->
        send(test_pid, {observer_id, packet})
      end)

      manager = start_manager(10_000)

      :ok =
        Manager.register(
          manager,
          group(1, visible?: true, cells: [{100, 100}], state: %{test_pid: test_pid})
        )

      :ok = Storage.add_observer_group(99, 1)
      [cell] = Storage.get_cells_by_group(1)

      assert :ok = Manager.remove_cells(manager, 1, [{100, 100}])

      assert_received {:expired, 1}

      assert_received {99,
                       %Aesir.Net.SkillUnitDespawn{
                         group_id: 1,
                         cell_ids: [cell_id],
                         reason: :SKILL_UNIT_DESPAWN_REASON_DESTROYED
                       }}

      assert cell_id == cell.cell_id
      assert nil == Storage.get(1)
      assert [] == Storage.get_cells_by_group(1)
      assert [] == Storage.get_groups_at_cell("prontera", 100, 100)
    end

    test "releases field support for occupants of removed cells only" do
      stub(Interpreter, :apply_status, fn _unit_type, _unit_id, _status_type, _params -> :ok end)
      stub(Interpreter, :remove_status, fn _unit_type, _unit_id, _status_type -> :ok end)

      manager = start_manager(10_000)
      allow(Interpreter, self(), manager)

      :ok = SpatialIndex.add_unit(:player, 42, 100, 100, "prontera")
      :ok = SpatialIndex.add_unit(:player, 43, 101, 100, "prontera")

      :ok =
        UnitRegistry.register_unit(
          :player,
          42,
          PlayerState,
          %PlayerState{
            character_id: 42,
            action_state: :idle,
            stats: %{current_state: %{hp: 100}}
          },
          self()
        )

      :ok =
        UnitRegistry.register_unit(
          :player,
          43,
          PlayerState,
          %PlayerState{character_id: 43, action_state: :dead, stats: %{current_state: %{hp: 0}}},
          self()
        )

      :ok =
        Manager.register(
          manager,
          group(1, skill_name: :field_unit, cells: [{100, 100}, {101, 100}])
        )

      assert [{:player, 42, :sc_quagmire, []}] = FieldSupport.sources_for_group(1)

      assert :ok = Manager.remove_cells(manager, 1, [{101, 100}])

      assert [{:player, 42, :sc_quagmire, []}] = FieldSupport.sources_for_group(1)
    end

    test "ignores coordinates the group does not own and leaves the group untouched" do
      test_pid = self()

      stub(Broadcast, :to_in_range, fn _map_name, _x, _y, _range, packet ->
        send(test_pid, {:in_range, packet})
      end)

      manager = start_manager(10_000)
      :ok = Manager.register(manager, group(1, visible?: true, cells: [{100, 100}]))
      cells = Storage.get_cells_by_group(1)

      assert :ok = Manager.remove_cells(manager, 1, [{101, 100}])
      assert :ok = Manager.remove_cells(manager, 1, [])
      assert :ok = Manager.remove_cells(manager, 404, [{100, 100}])

      refute_received {:in_range, %Aesir.Net.SkillUnitDespawn{}}
      assert %Group{cells: [{100, 100}]} = Storage.get(1)
      assert cells == Storage.get_cells_by_group(1)
      assert [%Group{group_id: 1}] = Storage.get_groups_at_cell("prontera", 100, 100)
    end
  end

  describe "land protector" do
    test "placement destroys overlapping foreign cells per cell, not per group" do
      manager = start_manager(10_000)

      :ok = Manager.register(manager, group(1, visible?: true, cells: [{100, 100}, {101, 100}]))

      :ok =
        Manager.register(
          manager,
          group(2,
            visible?: true,
            cells: [{101, 100}, {102, 100}],
            state: %{land_protector: true}
          )
        )

      assert %Group{cells: [{100, 100}]} = Storage.get(1)
      assert [%Cell{x: 100}] = Storage.get_cells_by_group(1)
      assert Enum.sort(Storage.get(2).cells) == [{101, 100}, {102, 100}]
      assert [%Group{group_id: 2}] = Storage.get_groups_at_cell("prontera", 101, 100)
    end

    test "land protector on land protector destroys both overlapping cells" do
      manager = start_manager(10_000)

      :ok =
        Manager.register(
          manager,
          group(1,
            visible?: true,
            cells: [{100, 100}, {101, 100}],
            state: %{land_protector: true}
          )
        )

      :ok =
        Manager.register(
          manager,
          group(2,
            visible?: true,
            cells: [{101, 100}, {102, 100}],
            state: %{land_protector: true}
          )
        )

      assert %Group{cells: [{100, 100}]} = Storage.get(1)
      assert %Group{cells: [{102, 100}]} = Storage.get(2)
      assert [] == Storage.get_groups_at_cell("prontera", 101, 100)
    end

    test "a fully overlapping land protector destroys the old one and fails placement" do
      manager = start_manager(10_000)

      :ok =
        Manager.register(
          manager,
          group(1, visible?: true, cells: [{100, 100}], state: %{land_protector: true})
        )

      assert {:error, :land_protector} =
               Manager.register(
                 manager,
                 group(2, visible?: true, cells: [{100, 100}], state: %{land_protector: true})
               )

      assert nil == Storage.get(1)
      assert nil == Storage.get(2)
      assert [] == Storage.get_groups_at_cell("prontera", 100, 100)
    end

    test "drops a later placement's candidate cells that fall on a land protector" do
      manager = start_manager(10_000)

      :ok =
        Manager.register(
          manager,
          group(1, visible?: true, cells: [{100, 100}], state: %{land_protector: true})
        )

      :ok = Manager.register(manager, group(2, visible?: true, cells: [{100, 100}, {101, 100}]))

      assert %Group{cells: [{101, 100}]} = Storage.get(2)
      assert [%Cell{x: 101}] = Storage.get_cells_by_group(2)
      assert [%Group{group_id: 1}] = Storage.get_groups_at_cell("prontera", 100, 100)
    end

    test "fails a later placement whose footprint falls entirely on a land protector" do
      manager = start_manager(10_000)

      :ok =
        Manager.register(
          manager,
          group(1,
            visible?: true,
            cells: [{100, 100}, {101, 100}],
            state: %{land_protector: true}
          )
        )

      assert {:error, :land_protector} =
               Manager.register(
                 manager,
                 group(2, visible?: true, cells: [{100, 100}, {101, 100}])
               )

      assert nil == Storage.get(2)
      assert Enum.sort(Storage.get(1).cells) == [{100, 100}, {101, 100}]
    end

    test "leaves ignore-flagged groups alone in both directions" do
      manager = start_manager(10_000)

      :ok =
        Manager.register(
          manager,
          group(1, visible?: true, cells: [{100, 100}], state: %{ignore_land_protector: true})
        )

      :ok =
        Manager.register(
          manager,
          group(2, visible?: true, cells: [{100, 100}], state: %{land_protector: true})
        )

      :ok =
        Manager.register(
          manager,
          group(3, visible?: true, cells: [{100, 100}], state: %{ignore_land_protector: true})
        )

      assert %Group{cells: [{100, 100}]} = Storage.get(1)
      assert %Group{cells: [{100, 100}]} = Storage.get(2)
      assert %Group{cells: [{100, 100}]} = Storage.get(3)
    end

    test "no live unit cell ever sits on a land protector cell" do
      manager = start_manager(10_000)

      :ok =
        Manager.register(
          manager,
          group(1, visible?: true, cells: for(x <- 100..102, do: {x, 100}))
        )

      :ok =
        Manager.register(
          manager,
          group(2,
            visible?: true,
            cells: for(x <- 101..103, do: {x, 100}),
            state: %{land_protector: true}
          )
        )

      _ = Manager.register(manager, group(3, visible?: true, cells: [{102, 100}, {104, 100}]))
      _ = Manager.register(manager, group(4, visible?: true, cells: [{103, 100}]))

      :ok =
        Manager.register(
          manager,
          group(5,
            visible?: true,
            cells: for(x <- 103..105, do: {x, 100}),
            state: %{land_protector: true}
          )
        )

      groups = Storage.all()

      protected =
        for %Group{} = lp <- groups,
            Group.land_protector?(lp),
            cell <- lp.cells,
            into: MapSet.new() do
          {lp.map_name, cell}
        end

      occupied =
        for %Group{} = other <- groups,
            not Group.land_protector?(other),
            cell <- other.cells,
            into: MapSet.new() do
          {other.map_name, cell}
        end

      assert MapSet.disjoint?(protected, occupied)
      refute Enum.empty?(protected)
      refute Enum.empty?(occupied)
    end
  end

  defp start_unmanaged_manager(now) do
    {:ok, manager} =
      Manager.start_link(
        name: nil,
        clock: fn -> now end,
        schedule_tick: fn _pid, _interval -> :ok end,
        unit_available?: fn _unit_type, _unit_id, _map_name -> true end
      )

    allow(Catalog, self(), manager)
    on_exit(fn -> if Process.alive?(manager), do: GenServer.stop(manager) end)
    manager
  end
end
