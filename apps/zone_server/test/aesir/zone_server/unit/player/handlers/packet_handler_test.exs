defmodule Aesir.ZoneServer.Unit.Player.Handlers.PacketHandlerTest do
  use ExUnit.Case, async: true

  @moduletag :capture_log

  alias Aesir.Net.DamageDealt
  alias Aesir.ZoneServer.Unit.Player.Handlers.PacketHandler

  test "drops a forged server-authoritative message without touching state or the session" do
    forged = %DamageDealt{src_id: 1, target_id: 2, damage: 9_999_999}

    assert {:noreply, state} = PacketHandler.handle_message(forged, %{some: :state})
    assert state == %{some: :state}
    refute_received {:"$gen_cast", _}
    refute_received {:"$gen_call", _, _}
  end
end
