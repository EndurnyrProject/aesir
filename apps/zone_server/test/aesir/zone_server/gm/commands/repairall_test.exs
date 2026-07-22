defmodule Aesir.ZoneServer.Gm.Commands.RepairAllTest do
  use Aesir.DataCase, async: true

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Gm.Commands.RepairAll
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables

  defp ctx, do: %{game_state: %PlayerState{character_name: "GmChar"}, connection_pid: self()}

  defp register_target(char_id, name) do
    pid = spawn(fn -> Process.sleep(:infinity) end)

    UnitRegistry.register_player(
      %PlayerState{character_id: char_id, account_id: 1, character_name: name},
      pid
    )

    pid
  end

  test "name and required_level" do
    assert RepairAll.name() == "repairall"
    assert RepairAll.required_level() == 60
  end

  test "no args casts to self and reports the self name" do
    assert {:ok, msg} = RepairAll.execute([], ctx())
    assert msg == "Repaired all broken items for GmChar"
    assert_receive {:"$gen_cast", {:inventory, :repair_all}}
  end

  test "integer arg resolves the target via the registry" do
    target = register_target(2000, "TargetChar")

    assert {:ok, msg} = RepairAll.execute(["2000"], ctx())
    assert msg == "Repaired all broken items for TargetChar"

    assert {:messages, [{:"$gen_cast", {:inventory, :repair_all}}]} =
             Process.info(target, :messages)
  end

  test "name arg resolves the target by case-insensitive name" do
    target = register_target(3000, "TargetChar")

    assert {:ok, msg} = RepairAll.execute(["targetchar"], ctx())
    assert msg == "Repaired all broken items for TargetChar"

    assert {:messages, [{:"$gen_cast", {:inventory, :repair_all}}]} =
             Process.info(target, :messages)
  end

  test "offline integer target returns an error and casts nothing" do
    assert {:error, "Player not online"} = RepairAll.execute(["4000"], ctx())
    refute_received {:"$gen_cast", {:inventory, :repair_all}}
  end

  test "unknown name target returns an error and casts nothing" do
    assert {:error, "Player not online"} = RepairAll.execute(["Nobody"], ctx())
    refute_received {:"$gen_cast", {:inventory, :repair_all}}
  end
end
