defmodule Aesir.ZoneServer.Mmo.Combat.TargetResolverTest do
  use ExUnit.Case, async: true

  import Mimic

  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  describe "resolve/2 for players" do
    test "resolves another player's session with its live stats merged in" do
      snapshot = %PlayerState{character_id: 2001, stats: %{str: 1}}
      fresh_stats = %{str: 99}
      other_pid = spawn(fn -> Process.sleep(:infinity) end)
      on_exit(fn -> Process.exit(other_pid, :kill) end)

      stub(UnitRegistry, :get_player_pid, fn 2001 -> {:ok, other_pid} end)
      stub(PlayerSession, :get_current_stats, fn ^other_pid -> fresh_stats end)
      stub(PlayerSession, :get_state, fn ^other_pid -> %{game_state: snapshot} end)

      assert {:ok, ^other_pid, %PlayerState{stats: ^fresh_stats}, :player} =
               TargetResolver.resolve(:player, 2001)
    end

    test "resolving the caller's own player uses the registry snapshot, never a session call" do
      snapshot = %PlayerState{character_id: 1001, stats: %{str: 42}}
      own_pid = self()

      stub(UnitRegistry, :get_player_pid, fn 1001 -> {:ok, own_pid} end)

      stub(UnitRegistry, :get_unit, fn :player, 1001 ->
        {:ok, {PlayerState, snapshot, own_pid}}
      end)

      reject(&PlayerSession.get_current_stats/1)
      reject(&PlayerSession.get_state/1)

      assert {:ok, ^own_pid, ^snapshot, :player} = TargetResolver.resolve(:player, 1001)
    end

    test "self-resolution reports target_not_found when the snapshot is gone" do
      stub(UnitRegistry, :get_player_pid, fn 1001 -> {:ok, self()} end)
      stub(UnitRegistry, :get_unit, fn :player, 1001 -> {:error, :not_found} end)

      assert {:error, :target_not_found} = TargetResolver.resolve(:player, 1001)
    end
  end
end
