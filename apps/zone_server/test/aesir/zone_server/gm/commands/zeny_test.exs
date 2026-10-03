defmodule Aesir.ZoneServer.Gm.Commands.ZenyTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Gm.Commands.Zeny
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables

  defp ctx, do: %{game_state: %PlayerState{character_name: "GmChar"}, connection_pid: self()}

  test "grants zeny to the GM when only an amount is given" do
    assert {:ok, "Gave 500 Zeny to GmChar"} = Zeny.execute(["500"], ctx())
    assert_receive {:"$gen_cast", {:npc, {:credit_zeny, 500}}}
  end

  test "grants zeny to a named online character" do
    target = spawn(fn -> Process.sleep(:infinity) end)

    UnitRegistry.register_player(
      %PlayerState{character_id: 2000, account_id: 1, character_name: "Target Char"},
      target
    )

    assert {:ok, "Gave 500 Zeny to Target Char"} =
             Zeny.execute(["500", "target", "char"], ctx())

    assert {:messages, [{:"$gen_cast", {:npc, {:credit_zeny, 500}}}]} =
             Process.info(target, :messages)
  end

  test "rejects missing, invalid and non-positive amounts" do
    for args <- [[], ["abc"], ["0"], ["-5"], ["12oops"]] do
      assert {:error, "Usage: @zeny <amount> [character name]"} = Zeny.execute(args, ctx())
    end

    refute_received {:"$gen_cast", _}
  end

  test "does not grant zeny to an offline character" do
    assert {:error, "Player not online"} = Zeny.execute(["500", "Nobody"], ctx())
    refute_received {:"$gen_cast", _}
  end
end
