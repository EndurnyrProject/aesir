defmodule Aesir.ZoneServer.Mmo.Skill.UnitTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup
  import Mimic

  alias Aesir.Net.GroundSkill
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Unit
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Unit.Broadcast
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

  setup do
    manager =
      start_supervised!({Manager, name: nil, schedule_tick: fn _pid, _interval -> :ok end})

    Process.put({Manager, :server}, manager)
    allow(Catalog, self(), manager)
    Mimic.copy(Broadcast)
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
      assert group.state == %{seeded: true}

      assert group.next_tick_at >= before + @interval
      assert group.expires_at >= before + @duration
      assert group.next_tick_at + (@duration - @interval) == group.expires_at

      assert %Group{} = Storage.get(group.group_id)
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

      refute_received {:broadcast, _, _, _, _}
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
end
