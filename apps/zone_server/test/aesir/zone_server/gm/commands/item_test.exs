defmodule Aesir.ZoneServer.Gm.Commands.ItemTest do
  use Aesir.DataCase, async: true

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Gm.Commands.Item
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables

  defp ctx, do: %{game_state: %PlayerState{character_name: "GmChar"}, connection_pid: self()}

  # Mirrors how a live session ends up in the registry: registered, then its
  # PlayerState written in. get_player_name/1 reads character_name off that struct.
  defp register_target(char_id, name) do
    pid = spawn(fn -> Process.sleep(:infinity) end)
    UnitRegistry.register_player(char_id, 1, name, pid)

    UnitRegistry.update_unit_state(:player, char_id, %PlayerState{
      character_id: char_id,
      character_name: name
    })

    pid
  end

  test "name and required_level" do
    assert Item.name() == "item"
    assert Item.required_level() == 60
  end

  describe "arg validation" do
    test "missing args" do
      assert {:error, "Usage: @item <item_id> <amount> [target]"} = Item.execute([], ctx())
    end

    test "non-integer id" do
      assert {:error, "Usage: @item <item_id> <amount> [target]"} =
               Item.execute(["abc", "10"], ctx())
    end

    test "non-positive amount" do
      assert {:error, "Usage: @item <item_id> <amount> [target]"} =
               Item.execute(["501", "0"], ctx())
    end
  end

  test "unknown item id" do
    assert {:error, "Item not found"} = Item.execute(["99999999", "10"], ctx())
  end

  test "no 3rd arg casts to self and reports the self name" do
    {:ok, item_def} = ItemManagement.get_item_by_id(501)

    assert {:ok, msg} = Item.execute(["501", "5"], ctx())
    assert msg == "Gave 5x #{item_def.name} to GmChar"
    assert_receive {:"$gen_cast", {:give_item, ^item_def, 5}}
  end

  test "integer 3rd arg resolves the target via the registry" do
    {:ok, item_def} = ItemManagement.get_item_by_id(501)
    target = register_target(2000, "TargetChar")

    assert {:ok, msg} = Item.execute(["501", "3", "2000"], ctx())
    assert msg == "Gave 3x #{item_def.name} to TargetChar"

    assert {:messages, [{:"$gen_cast", {:give_item, ^item_def, 3}}]} =
             Process.info(target, :messages)
  end

  test "non-integer 3rd arg resolves the target by case-insensitive name" do
    {:ok, item_def} = ItemManagement.get_item_by_id(501)
    target = register_target(3000, "TargetChar")

    assert {:ok, msg} = Item.execute(["501", "2", "targetchar"], ctx())
    assert msg == "Gave 2x #{item_def.name} to TargetChar"

    assert {:messages, [{:"$gen_cast", {:give_item, ^item_def, 2}}]} =
             Process.info(target, :messages)
  end

  test "offline integer target returns an error and casts nothing" do
    assert {:error, "Player not online"} = Item.execute(["501", "1", "4000"], ctx())
    refute_received {:"$gen_cast", {:give_item, _, _}}
  end

  test "unknown name target returns an error and casts nothing" do
    assert {:error, "Player not online"} = Item.execute(["501", "1", "Nobody"], ctx())
    refute_received {:"$gen_cast", {:give_item, _, _}}
  end
end
