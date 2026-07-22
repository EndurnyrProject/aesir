defmodule Aesir.ZoneServer.Gm.Commands.JobLevelTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Gm.Commands.JobLevel
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  defp ctx, do: %{game_state: %PlayerState{character_name: "Gm"}, connection_pid: self()}

  test "name and required_level" do
    assert JobLevel.name() == "joblevelup"
    assert JobLevel.required_level() == 60
  end

  describe "arg validation" do
    test "missing args" do
      assert {:error, "Usage: @joblevelup <amount>"} = JobLevel.execute([], ctx())
    end

    test "non-integer amount" do
      assert {:error, "Usage: @joblevelup <amount>"} = JobLevel.execute(["abc"], ctx())
    end

    test "non-positive amount" do
      assert {:error, "Usage: @joblevelup <amount>"} = JobLevel.execute(["-3"], ctx())
    end
  end

  test "valid amount casts {:progression, {:add_job_level, amount}}" do
    assert {:ok, "Gained 3 job level(s)"} = JobLevel.execute(["3"], ctx())
    assert_received {:"$gen_cast", {:progression, {:add_job_level, 3}}}
  end
end
