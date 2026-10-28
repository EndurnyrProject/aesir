defmodule Aesir.ZoneServer.Npc.TouchTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Npc.Touch
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @gid 0x5000_1234

  setup :setup_ets_tables

  setup do
    on_exit(fn -> :ets.delete(Touch.table(), @gid) end)
    :ok
  end

  test "the first claim wins, the holder may re-claim, and only the holder releases" do
    UnitRegistry.register_unit(:player, 11, PlayerState, %PlayerState{character_id: 11}, self())

    assert Touch.claim(@gid, 11) == :ok
    assert Touch.claim(@gid, 11) == :ok
    assert Touch.claim(@gid, 12) == :taken
    assert Touch.toucher(@gid) == 11

    assert Touch.release(@gid, 12) == :not_owner
    assert Touch.toucher(@gid) == 11
    assert Touch.release(@gid, 11) == :released
    assert Touch.toucher(@gid) == nil
  end

  test "a claim held by a player that is no longer registered is taken over" do
    assert Touch.claim(@gid, 11) == :ok
    assert Touch.claim(@gid, 12) == :ok
    assert Touch.toucher(@gid) == 12
  end
end
