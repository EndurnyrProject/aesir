defmodule Aesir.ZoneServer.Unit.Player.Handlers.PacketHandlerStatsTest do
  @moduledoc """
  Verifies the QUIC + protobuf inbound dispatch for the stats/vitals/respawn
  slice routes to the same handlers (with the same arguments) as the legacy
  numeric `handle_packet/3` clauses.
  """

  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.Net.Respawn
  alias Aesir.Net.StatUp
  alias Aesir.ZoneServer.Unit.Player.Handlers.HealthHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.PacketHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.StatAllocationHandler

  setup :verify_on_exit!

  setup do
    Mimic.copy(StatAllocationHandler)
    Mimic.copy(HealthHandler)
    :ok
  end

  describe "handle_message/2 for StatUp" do
    test "routes to StatAllocationHandler.handle_status_up/3 with stat_id and amount" do
      state = %{game_state: :stub}

      expect(StatAllocationHandler, :handle_status_up, fn 13, 2, ^state ->
        {:noreply, state}
      end)

      assert {:noreply, ^state} =
               PacketHandler.handle_message(%StatUp{stat_id: 13, amount: 2}, state)
    end
  end

  describe "handle_message/2 for Respawn" do
    test "routes to HealthHandler.handle_restart/2 with the respawn type" do
      state = %{game_state: :stub}

      expect(HealthHandler, :handle_restart, fn 0, ^state ->
        {:noreply, state}
      end)

      assert {:noreply, ^state} =
               PacketHandler.handle_message(%Respawn{type: 0}, state)
    end
  end
end
