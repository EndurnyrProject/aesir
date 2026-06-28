defmodule Aesir.ZoneServer.Mmo.Skill.Ground.TriggerTest.TouchPersist do
  @moduledoc false
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group

  def on_touch(%Group{group_id: gid} = group, mover) do
    send(self(), {:touched, gid, mover})
    {:ok, %{group | state: Map.put(group.state, :touched, mover)}}
  end

  def on_expire(_group), do: :ok
end

defmodule Aesir.ZoneServer.Mmo.Skill.Ground.TriggerTest.TouchExpire do
  @moduledoc false
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group

  def on_touch(%Group{group_id: gid}, mover) do
    send(self(), {:touched, gid, mover})
    :expire
  end

  def on_expire(%Group{group_id: gid}) do
    send(self(), {:expired, gid})
    :ok
  end
end

defmodule Aesir.ZoneServer.Mmo.Skill.Ground.TriggerTest do
  use ExUnit.Case, async: true

  import Mimic
  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Ground.Trigger
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage

  alias __MODULE__.TouchExpire
  alias __MODULE__.TouchPersist

  setup :setup_ets_tables
  setup :verify_on_exit!

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
      state: %{}
    }

    struct(base, attrs)
  end

  describe "on_enter_cell/4" do
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
end
