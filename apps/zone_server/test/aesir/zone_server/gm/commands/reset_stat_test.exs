defmodule Aesir.ZoneServer.Gm.Commands.ResetStatTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Gm.Commands.ResetStat
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Phoenix.PubSub

  @char_id 4444

  defp ctx(overrides \\ []) do
    game_state = struct(%PlayerState{character_id: @char_id, character_name: "Gm"}, overrides)
    %{game_state: game_state, connection_pid: self()}
  end

  test "name and required_level" do
    assert ResetStat.name() == "resetstat"
    assert ResetStat.required_level() == 60
  end

  test "broadcasts {:reset_stats} on the caller's own topic" do
    PubSub.subscribe(Aesir.PubSub, "player:#{@char_id}")

    assert {:ok, "Stats reset"} = ResetStat.execute([], ctx())
    assert_receive {:progression, {:reset_stats}}
  end

  test "ignores extra args" do
    PubSub.subscribe(Aesir.PubSub, "player:#{@char_id}")

    assert {:ok, "Stats reset"} = ResetStat.execute(["anything"], ctx())
    assert_receive {:progression, {:reset_stats}}
  end
end
