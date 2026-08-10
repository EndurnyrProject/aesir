defmodule Aesir.ZoneServer.Gm.Commands.RentitemTest do
  use Aesir.DataCase, async: true

  import Mimic

  alias Aesir.ZoneServer.Gm.Commands.Rentitem
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_private
  setup :verify_on_exit!

  defp ctx, do: %{game_state: %PlayerState{character_name: "GmChar"}, connection_pid: self()}

  test "name and required_level" do
    assert Rentitem.name() == "rentitem"
    assert Rentitem.required_level() == 60
  end

  test "grants a rental item to self through the script seam" do
    item_def = %{name: "Rental Sword"}
    pid = self()

    expect(ItemManagement, :get_item_by_id, fn 1_201 -> {:ok, item_def} end)

    expect(PlayerSession, :script_apply, fn ^pid, {:give_item_rental, 1_201, 3_600, []} ->
      {:ok, %PlayerState{}}
    end)

    assert {:ok, "Rented 3600s Rental Sword to GmChar"} =
             Rentitem.execute(["1201", "3600"], ctx())
  end

  test "zero seconds return usage" do
    assert {:error, "Usage: @rentitem <item_id> <seconds> [target]"} =
             Rentitem.execute(["1201", "0"], ctx())
  end

  test "negative seconds return usage" do
    assert {:error, "Usage: @rentitem <item_id> <seconds> [target]"} =
             Rentitem.execute(["1201", "-1"], ctx())
  end

  test "non-rentable item returns an error" do
    item_def = %{name: "Red Potion"}
    pid = self()

    expect(ItemManagement, :get_item_by_id, fn 501 -> {:ok, item_def} end)

    expect(PlayerSession, :script_apply, fn ^pid, {:give_item_rental, 501, 60, []} ->
      {:error, :not_rentable}
    end)

    assert {:error, "Item is not rentable"} = Rentitem.execute(["501", "60"], ctx())
  end

  test "offline integer target returns an error" do
    expect(ItemManagement, :get_item_by_id, fn 1_201 -> {:ok, %{name: "Rental Sword"}} end)
    expect(UnitRegistry, :get_player_pid, fn 4_000 -> :error end)

    assert {:error, "Player not online"} = Rentitem.execute(["1201", "60", "4000"], ctx())
  end

  test "unknown name target returns an error" do
    expect(ItemManagement, :get_item_by_id, fn 1_201 -> {:ok, %{name: "Rental Sword"}} end)
    expect(UnitRegistry, :list_players, fn -> [] end)

    assert {:error, "Player not online"} = Rentitem.execute(["1201", "60", "Nobody"], ctx())
  end
end
