defmodule Aesir.ZoneServer.Mmo.SkillUnitTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup
  import Mimic

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.SkillUnit
  alias Aesir.ZoneServer.Mmo.SkillUnit.Behaviors
  alias Aesir.ZoneServer.Mmo.SkillUnit.Group
  alias Aesir.ZoneServer.Mmo.SkillUnit.Storage
  alias Aesir.ZoneServer.Packets.ZcNotifyGroundskill
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup :setup_ets_tables
  setup :verify_on_exit!

  @interval 450
  @duration 5_000

  # A real catalog skill so place/4 can resolve its skill_id.
  @skill_name :sm_bash

  defmodule FakeUnit do
    use Aesir.ZoneServer.Mmo.SkillUnit.Behaviour

    @impl true
    def skill_name, do: :sm_bash

    @impl true
    def on_place(%Group{center: {x, y}}) do
      {:ok, %{cells: [{x, y}], state: %{seeded: true}, interval: 450, duration: 5_000}}
    end

    @impl true
    def on_interval(group, _now), do: {:ok, group}
  end

  setup do
    Mimic.copy(Behaviors)
    Mimic.copy(Broadcast)
    stub(Behaviors, :module_for, fn @skill_name -> {:ok, FakeUnit} end)
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
      {:ok, %Group{} = group} = SkillUnit.place(caster(), @skill_name, 7, {100, 120})

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

    test "broadcasts exactly one ZcNotifyGroundskill at the target cell" do
      test_pid = self()

      stub(Broadcast, :to_in_range, fn map_name, x, y, _range, packet ->
        send(test_pid, {:broadcast, map_name, x, y, packet})
        :ok
      end)

      {:ok, group} = SkillUnit.place(caster(), @skill_name, 7, {100, 120})

      assert_received {:broadcast, "prontera", 100, 120, %ZcNotifyGroundskill{} = packet}
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
      {:ok, group} = SkillUnit.place(caster(), @skill_name, 7, {100, 120})

      assert is_integer(definition.id)
      assert group.skill_id == definition.id

      assert_received {:broadcast, %ZcNotifyGroundskill{} = packet}
      assert packet.skill_id == definition.id
      assert is_binary(ZcNotifyGroundskill.build(packet))
    end

    test "returns an error for an unregistered skill" do
      stub(Behaviors, :module_for, fn _ -> :error end)

      assert {:error, :no_skill_unit_behaviour} =
               SkillUnit.place(caster(), :unknown, 1, {10, 10})
    end
  end
end
