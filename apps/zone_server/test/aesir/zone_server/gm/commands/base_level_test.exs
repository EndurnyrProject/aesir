defmodule Aesir.ZoneServer.Gm.Commands.BaseLevelTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Gm.Commands.BaseLevel
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  defp ctx, do: %{game_state: %PlayerState{character_name: "Gm"}, connection_pid: self()}

  test "name and required_level" do
    assert BaseLevel.name() == "baselevelup"
    assert BaseLevel.required_level() == 60
  end

  describe "arg validation" do
    test "missing args" do
      assert {:error, "Usage: @baselevelup <amount>"} = BaseLevel.execute([], ctx())
    end

    test "non-integer amount" do
      assert {:error, "Usage: @baselevelup <amount>"} = BaseLevel.execute(["abc"], ctx())
    end

    test "non-positive amount" do
      assert {:error, "Usage: @baselevelup <amount>"} = BaseLevel.execute(["0"], ctx())
    end
  end

  test "valid amount casts {:progression, {:add_base_level, amount}}" do
    assert {:ok, "Gained 5 base level(s)"} = BaseLevel.execute(["5"], ctx())
    assert_received {:"$gen_cast", {:progression, {:add_base_level, 5}}}
  end
end
