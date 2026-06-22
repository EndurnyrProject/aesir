defmodule Aesir.ZoneServer.Gm.Commands.WarpTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Gm.Commands.Warp
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  defp ctx, do: %{game_state: %PlayerState{character_name: "Gm"}, connection_pid: self()}

  test "name and required_level" do
    assert Warp.name() == "warp"
    assert Warp.required_level() == 60
  end

  describe "arg validation" do
    test "missing args" do
      assert {:error, "Usage: @warp <map> <x> <y>"} = Warp.execute([], ctx())
    end

    test "missing coordinate" do
      assert {:error, "Usage: @warp <map> <x> <y>"} = Warp.execute(["geffen", "100"], ctx())
    end

    test "non-integer coordinate" do
      assert {:error, "Usage: @warp <map> <x> <y>"} =
               Warp.execute(["geffen", "abc", "120"], ctx())
    end

    test "negative coordinate" do
      assert {:error, "Usage: @warp <map> <x> <y>"} =
               Warp.execute(["geffen", "100", "-5"], ctx())
    end
  end

  test "valid args cast {:warp, map, x, y} to the caller's session and reply" do
    assert {:ok, "Warping to geffen (100, 120)"} = Warp.execute(["geffen", "100", "120"], ctx())
    assert_received {:"$gen_cast", {:warp, "geffen", 100, 120}}
  end
end
