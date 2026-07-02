defmodule Aesir.ZoneServer.Unit.Player.Handlers.PacketHandlerPickupTest do
  use ExUnit.Case, async: true

  import Mimic

  alias Aesir.Net.PickupItemRequest
  alias Aesir.ZoneServer.Unit.Player.Handlers.PacketHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.PickupHandler

  setup :verify_on_exit!

  test "PickupItemRequest dispatches to PickupHandler with the ground id" do
    message = %PickupItemRequest{ground_id: 7777}

    expect(PickupHandler, :handle_pickup, fn 7777, state -> {:noreply, state} end)

    assert {:noreply, %{}} = PacketHandler.handle_message(message, %{})
  end
end
