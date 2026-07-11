defmodule Aesir.ZoneServer.Gm.Commands.ResetSkillTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Gm.Commands.ResetSkill
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Phoenix.PubSub

  @char_id 4343

  defp ctx(overrides \\ []) do
    game_state = struct(%PlayerState{character_id: @char_id, character_name: "Gm"}, overrides)
    %{game_state: game_state, connection_pid: self()}
  end

  test "name and required_level" do
    assert ResetSkill.name() == "resetskill"
    assert ResetSkill.required_level() == 60
  end

  test "broadcasts {:reset_skills} on the caller's own topic" do
    PubSub.subscribe(Aesir.PubSub, "player:#{@char_id}")

    assert {:ok, "Skills reset"} = ResetSkill.execute([], ctx())
    assert_receive {:reset_skills}
  end

  test "ignores extra args" do
    PubSub.subscribe(Aesir.PubSub, "player:#{@char_id}")

    assert {:ok, "Skills reset"} = ResetSkill.execute(["anything"], ctx())
    assert_receive {:reset_skills}
  end

  test "is rejected with a message while a cart is mounted, broadcasting nothing" do
    PubSub.subscribe(Aesir.PubSub, "player:#{@char_id}")

    assert {:error, "Remove your cart before resetting skills"} =
             ResetSkill.execute([], ctx(cart_type: 1))

    refute_receive {:reset_skills}
  end
end
