defmodule Aesir.ZoneServer.Mmo.Skill.Ground.TriggerTest.TouchPersist do
  @moduledoc false
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group

  def on_touch(%Group{group_id: gid, state: %{test_pid: test_pid}} = group, mover) do
    send(test_pid, {:touched, gid, mover})
    {:ok, %{group | state: Map.put(group.state, :touched, mover)}}
  end

  def on_expire(_group), do: :ok
end

defmodule Aesir.ZoneServer.Mmo.Skill.Ground.TriggerTest.TouchExpire do
  @moduledoc false
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group

  def on_touch(%Group{group_id: gid, state: %{test_pid: test_pid}}, mover) do
    send(test_pid, {:touched, gid, mover})
    :expire
  end

  def on_expire(%Group{group_id: gid, state: %{test_pid: test_pid}}) do
    send(test_pid, {:expired, gid})
    :ok
  end
end

defmodule Aesir.ZoneServer.Mmo.Skill.Ground.TriggerTest.OutPersist do
  @moduledoc false
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group

  def on_out(%Group{group_id: gid, state: %{test_pid: test_pid}} = group, mover) do
    send(test_pid, {:out, gid, mover})
    {:ok, group}
  end

  def on_expire(_group), do: :ok
end

defmodule Aesir.ZoneServer.Mmo.Skill.Ground.TriggerTest.MalformedFieldSupport do
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group

  def field_support(%Group{}) do
    %{status_type: :sc_quagmire, params: [level: 3, val2: 15]}
  end
end

defmodule Aesir.ZoneServer.Mmo.Skill.Ground.TriggerTest do
  use ExUnit.Case, async: false

  import Mimic
  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Ground.Trigger
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter

  alias __MODULE__.MalformedFieldSupport
  alias __MODULE__.OutPersist
  alias __MODULE__.TouchExpire
  alias __MODULE__.TouchPersist

  setup :setup_ets_tables
  setup :verify_on_exit!

  setup do
    manager =
      start_supervised!({Manager, name: nil, schedule_tick: fn _pid, _interval -> :ok end})

    Process.put({Manager, :server}, manager)
    allow(Catalog, self(), manager)
    Mimic.copy(Interpreter)
    allow(Interpreter, self(), manager)
    :ok
  end

  @mover {:player, 1000}

  defp group(group_id, attrs \\ []) do
    base = %Group{
      group_id: group_id,
      skill_id: 999,
      skill_name: :test_trap,
      level: 1,
      caster_id: 2000,
      caster_type: :player,
      map_name: "prontera",
      center: {5, 5},
      cells: [{5, 5}],
      next_tick_at: 0,
      expires_at: 0,
      interval: 1_000,
      state: %{test_pid: self()}
    }

    struct(base, attrs)
  end

  describe "on_enter_cell/4" do
    test "fails loudly when field support omits the target predicate" do
      stub(Catalog, :ground_module_for, fn :test_trap -> {:ok, MalformedFieldSupport} end)
      assert %{status_type: :sc_quagmire} = MalformedFieldSupport.field_support(group(1))
      :ok = Storage.insert(group(1))

      assert catch_exit(Trigger.on_enter_cell(@mover, "prontera", 5, 5))
    end

    test "invokes on_touch for a covering group and persists {:ok, updated}" do
      stub(Catalog, :ground_module_for, fn :test_trap -> {:ok, TouchPersist} end)
      :ok = Storage.insert(group(1))

      assert :ok = Trigger.on_enter_cell(@mover, "prontera", 5, 5)

      assert_received {:touched, 1, {:player, 1000}}
      assert %Group{state: %{touched: {:player, 1000}}} = Storage.get(1)
    end

    test "tears down the group (on_expire + delete) when on_touch returns :expire" do
      stub(Catalog, :ground_module_for, fn :test_trap -> {:ok, TouchExpire} end)
      :ok = Storage.insert(group(1))

      assert :ok = Trigger.on_enter_cell(@mover, "prontera", 5, 5)

      assert_received {:touched, 1, {:player, 1000}}
      assert_received {:expired, 1}
      assert nil == Storage.get(1)
    end

    test "ignores ground units whose module does not export on_touch/2" do
      # wz_stormgust is a real ground skill with no on_touch hook
      :ok = Storage.insert(group(1, skill_name: :wz_stormgust))

      assert :ok = Trigger.on_enter_cell(@mover, "prontera", 5, 5)

      assert %Group{group_id: 1} = Storage.get(1)
      refute_received {:touched, _, _}
    end

    test "is a no-op when no group covers the cell" do
      stub(Catalog, :ground_module_for, fn _ -> {:ok, TouchExpire} end)
      :ok = Storage.insert(group(1, cells: [{5, 5}]))

      assert :ok = Trigger.on_enter_cell(@mover, "prontera", 9, 9)

      refute_received {:touched, _, _}
      assert %Group{group_id: 1} = Storage.get(1)
    end
  end

  describe "on_leave_cell/7" do
    @footprint for x <- 4..6, y <- 4..6, do: {x, y}

    test "invokes on_out when the mover steps off the footprint entirely" do
      stub(Catalog, :ground_module_for, fn :test_field -> {:ok, OutPersist} end)
      :ok = Storage.insert(group(1, skill_name: :test_field, cells: @footprint))

      assert :ok = Trigger.on_leave_cell(@mover, "prontera", 5, 5, "prontera", 9, 9)

      assert_received {:out, 1, {:player, 1000}}
    end

    test "does not fire when the mover moves within the same footprint" do
      stub(Catalog, :ground_module_for, fn :test_field -> {:ok, OutPersist} end)
      :ok = Storage.insert(group(1, skill_name: :test_field, cells: @footprint))

      assert :ok = Trigger.on_leave_cell(@mover, "prontera", 5, 5, "prontera", 6, 6)

      refute_received {:out, _, _}
    end

    test "fires when the mover changes maps while still on the footprint cell" do
      stub(Catalog, :ground_module_for, fn :test_field -> {:ok, OutPersist} end)
      :ok = Storage.insert(group(1, skill_name: :test_field, cells: @footprint))

      assert :ok = Trigger.on_leave_cell(@mover, "prontera", 5, 5, "morocc", 5, 5)

      assert_received {:out, 1, {:player, 1000}}
    end

    test "ignores ground units whose module does not export on_out/2" do
      :ok = Storage.insert(group(1, skill_name: :wz_stormgust, cells: @footprint))

      assert :ok = Trigger.on_leave_cell(@mover, "prontera", 5, 5, "prontera", 9, 9)

      assert %Group{group_id: 1} = Storage.get(1)
      refute_received {:out, _, _}
    end
  end
end
