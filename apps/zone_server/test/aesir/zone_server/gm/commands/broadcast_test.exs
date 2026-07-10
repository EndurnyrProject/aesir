defmodule Aesir.ZoneServer.Gm.Commands.BroadcastTest do
  use ExUnit.Case, async: false

  import Mimic

  alias Aesir.ZoneServer.Announcement
  alias Aesir.ZoneServer.Gm.Commands.Broadcast
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup :verify_on_exit!

  defp ctx do
    %{
      game_state: %PlayerState{character_id: 1000, map_name: "prontera"},
      connection_pid: self()
    }
  end

  test "name and required_level" do
    assert Broadcast.name() == "broadcast"
    assert Broadcast.required_level() == 60
  end

  test "no flags defaults to global scope with default color and TOP style" do
    expect(Announcement, :to_all, fn opts ->
      assert opts.text == "hello world"
      assert opts.color == 0
      assert opts.style == :TOP
      assert opts.source_name == "Server"
      :ok
    end)

    assert {:ok, _msg} = Broadcast.execute(["hello", "world"], ctx())
  end

  test "map scope with blue color targets the caller's map with CENTER style" do
    expect(Announcement, :to_map, fn map_name, opts ->
      assert map_name == "prontera"
      assert opts.text == "hi there"
      assert opts.color == 0x0099FF
      assert opts.style == :CENTER
      :ok
    end)

    assert {:ok, _msg} = Broadcast.execute(["map", "blue", "hi", "there"], ctx())
  end

  test "self scope with yellow color targets only the caller with LOCAL style" do
    expect(Announcement, :to_self, fn char_id, opts ->
      assert char_id == 1000
      assert opts.text == "test"
      assert opts.color == 0
      assert opts.style == :LOCAL
      :ok
    end)

    assert {:ok, _msg} = Broadcast.execute(["self", "yellow", "test"], ctx())
  end

  test "a message word matching a keyword is not eaten mid-sentence" do
    expect(Announcement, :to_all, fn opts ->
      assert opts.text == "the map is down"
      :ok
    end)

    assert {:ok, _msg} = Broadcast.execute(["the", "map", "is", "down"], ctx())
  end

  test "empty message returns usage error" do
    assert {:error, usage} = Broadcast.execute([], ctx())
    assert usage =~ "Usage: @broadcast"
  end

  test "scope with no message returns usage error" do
    assert {:error, usage} = Broadcast.execute(["map"], ctx())
    assert usage =~ "Usage: @broadcast"
  end
end
