defmodule Aesir.ZoneServer.Mmo.Skill.Unit.StorageTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage

  setup :setup_ets_tables

  defp group(group_id, attrs \\ []) do
    base = %Group{
      group_id: group_id,
      skill_id: 89,
      skill_name: :wz_stormgust,
      level: 10,
      caster_id: 2000,
      caster_type: :player,
      map_name: "prontera",
      center: {100, 100},
      cells: [{100, 100}],
      next_tick_at: 0,
      expires_at: 0,
      interval: 450,
      state: %{}
    }

    struct(base, attrs)
  end

  describe "insert/1 and get/1" do
    test "round-trips a group" do
      g = group(1)

      assert :ok = Storage.insert(g)
      assert ^g = Storage.get(1)
    end

    test "get/1 returns nil for an unknown group_id" do
      assert nil == Storage.get(999)
    end
  end

  describe "delete/1" do
    test "removes a stored group" do
      :ok = Storage.insert(group(1))

      assert :ok = Storage.delete(1)
      assert nil == Storage.get(1)
    end
  end

  describe "all/0" do
    test "returns every stored group" do
      :ok = Storage.insert(group(1))
      :ok = Storage.insert(group(2))

      ids = Storage.all() |> Enum.map(& &1.group_id) |> Enum.sort()

      assert ids == [1, 2]
    end
  end

  describe "update/1" do
    test "replaces an existing group" do
      :ok = Storage.insert(group(1, state: %{hit_counts: %{}}))

      :ok = Storage.update(group(1, state: %{hit_counts: %{5 => 3}}))

      assert %Group{state: %{hit_counts: %{5 => 3}}} = Storage.get(1)
    end
  end

  describe "get_due_groups/1" do
    test "returns only groups whose next_tick_at <= now" do
      now = 1_000

      :ok = Storage.insert(group(1, next_tick_at: now - 10))
      :ok = Storage.insert(group(2, next_tick_at: now))
      :ok = Storage.insert(group(3, next_tick_at: now + 10))

      ids = Storage.get_due_groups(now) |> Enum.map(& &1.group_id) |> Enum.sort()

      assert ids == [1, 2]
    end
  end

  describe "get_expired_groups/1" do
    test "returns only groups whose expires_at <= now" do
      now = 1_000

      :ok = Storage.insert(group(1, expires_at: now - 10))
      :ok = Storage.insert(group(2, expires_at: now))
      :ok = Storage.insert(group(3, expires_at: now + 10))

      ids = Storage.get_expired_groups(now) |> Enum.map(& &1.group_id) |> Enum.sort()

      assert ids == [1, 2]
    end
  end
end
