defmodule Aesir.ZoneServer.Unit.Player.Handlers.PacketHandlerPickupTest do
  use ExUnit.Case, async: true

  alias Aesir.Net.PickupItemRequest
  alias Aesir.ZoneServer.Unit.Player.Handlers.PacketHandler

  test "PickupItemRequest casts {:pickup_item_request, ground_id} to the session" do
    message = %PickupItemRequest{ground_id: 7777}

    assert {:noreply, state} = PacketHandler.handle_message(message, %{})
    assert state == %{}
    assert_received {:"$gen_cast", {:pickup_item_request, 7777}}
  end
end
