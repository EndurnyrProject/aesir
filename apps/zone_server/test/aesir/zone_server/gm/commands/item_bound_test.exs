defmodule Aesir.ZoneServer.Gm.Commands.ItemBoundTest do
  use Aesir.DataCase, async: true

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Gm.Commands.ItemBound
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup :setup_ets_tables

  defp ctx, do: %{game_state: %PlayerState{character_name: "GmChar"}, connection_pid: self()}

  test "name and required_level" do
    assert ItemBound.name() == "itembound"
    assert ItemBound.required_level() == 60
  end

  test "account grants an account-bound item" do
    {:ok, item_def} = ItemManagement.get_item_by_id(501)

    assert {:ok, msg} = ItemBound.execute(["501", "5", "account"], ctx())
    assert msg == "Gave 5x #{item_def.name} to GmChar"

    assert_receive {:"$gen_cast", {:inventory, {:give_item, ^item_def, 5, [bound: 1]}}}
  end

  test "char grants a character-bound item" do
    {:ok, item_def} = ItemManagement.get_item_by_id(501)

    assert {:ok, msg} = ItemBound.execute(["501", "5", "char"], ctx())
    assert msg == "Gave 5x #{item_def.name} to GmChar"

    assert_receive {:"$gen_cast", {:inventory, {:give_item, ^item_def, 5, [bound: 4]}}}
  end

  test "numeric bound types are accepted" do
    {:ok, item_def} = ItemManagement.get_item_by_id(501)

    assert {:ok, msg} = ItemBound.execute(["501", "5", "1"], ctx())
    assert msg == "Gave 5x #{item_def.name} to GmChar"
    assert_receive {:"$gen_cast", {:inventory, {:give_item, ^item_def, 5, [bound: 1]}}}

    assert {:ok, msg} = ItemBound.execute(["501", "5", "4"], ctx())
    assert msg == "Gave 5x #{item_def.name} to GmChar"
    assert_receive {:"$gen_cast", {:inventory, {:give_item, ^item_def, 5, [bound: 4]}}}
  end

  test "invalid bound type returns usage" do
    assert {:error, "Usage: @itembound <item_id> <amount> <bound_type> [target]"} =
             ItemBound.execute(["501", "5", "guild"], ctx())
  end
end
