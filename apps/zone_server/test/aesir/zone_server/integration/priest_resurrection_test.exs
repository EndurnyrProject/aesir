defmodule Aesir.ZoneServer.Integration.PriestResurrectionTest do
  @moduledoc """
  End-to-end Resurrection coverage through retained corpse state, the real
  target-session revival command, observer delivery, and the spatial index.
  """
  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Net.ParamChange
  alias Aesir.Net.Resurrect
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.AllResurrection
  alias Aesir.ZoneServer.Unit.Player.PlayerSession

  test "a retained corpse is revived in place for itself and nearby observers without reindexing" do
    test_pid = self()

    caster =
      start_player_session(
        id: 18_001,
        name: "ResurrectionCaster",
        position: {150, 150},
        connection_pid: tagged_connection(test_pid, :caster)
      )

    observer =
      start_player_session(
        id: 18_002,
        name: "ResurrectionObserver",
        position: {152, 150},
        connection_pid: tagged_connection(test_pid, :observer)
      )

    target =
      start_player_session(
        id: 18_003,
        name: "ResurrectionTarget",
        position: {151, 150},
        connection_pid: tagged_connection(test_pid, :target)
      )

    assert_eventually(fn ->
      state = get_player_state(target.pid)
      MapSet.member?(state.visible_players, observer.character.id)
    end)

    flush_tagged_packets()
    PlayerSession.apply_damage(target.pid, 1_000_000, caster.character.id)

    assert_eventually(fn -> get_player_state(target.pid).action_state == :dead end)
    assert {:ok, {151, 150, "prontera"}} = SpatialIndex.get_unit_position(:player, 18_003)

    assert Enum.count(
             SpatialIndex.get_players_in_range("prontera", 151, 150, 0),
             &(&1 == 18_003)
           ) == 1

    flush_tagged_packets()
    assert {:ok, definition} = Catalog.by_id(54)
    caster_state = get_player_state(caster.pid)

    assert {:ok, ^caster_state} =
             AllResurrection.cast(caster_state, {:unit, target.character.id}, 3, definition)

    assert_eventually(fn ->
      revived = get_player_state(target.pid)

      revived.action_state == :idle and
        revived.stats.current_state.hp == div(revived.stats.derived_stats.max_hp * 50, 100)
    end)

    assert_receive {:resurrection_packet, :target, %ParamChange{value: hp}} when hp > 0, 1_000
    assert_receive {:resurrection_packet, :target, %Resurrect{gid: 18_003}}, 1_000
    assert_receive {:resurrection_packet, :observer, %Resurrect{gid: 18_003}}, 1_000

    assert {:ok, {151, 150, "prontera"}} = SpatialIndex.get_unit_position(:player, 18_003)

    assert Enum.count(
             SpatialIndex.get_players_in_range("prontera", 151, 150, 0),
             &(&1 == 18_003)
           ) == 1
  end

  defp tagged_connection(test_pid, tag) do
    spawn_link(fn -> tagged_connection_loop(test_pid, tag) end)
  end

  defp tagged_connection_loop(test_pid, tag) do
    receive do
      {:send, _channel, {_wire_tag, packet}} ->
        send(test_pid, {:resurrection_packet, tag, packet})
        tagged_connection_loop(test_pid, tag)

      _message ->
        tagged_connection_loop(test_pid, tag)
    end
  end

  defp flush_tagged_packets do
    receive do
      {:resurrection_packet, _tag, _packet} -> flush_tagged_packets()
    after
      0 -> :ok
    end
  end

  defp assert_eventually(fun, attempts \\ 50)
  defp assert_eventually(fun, 0), do: assert(fun.())

  defp assert_eventually(fun, attempts) do
    if fun.() do
      :ok
    else
      Process.sleep(10)
      assert_eventually(fun, attempts - 1)
    end
  end
end
