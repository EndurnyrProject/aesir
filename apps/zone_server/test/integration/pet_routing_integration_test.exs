defmodule Aesir.ZoneServer.Integration.PetRoutingIntegrationTest do
  use Aesir.ZoneServer.IntegrationCase

  alias Aesir.Net.PetMenuCommand
  alias Aesir.Net.PetRequest
  alias Aesir.Net.PetResult

  test "pet request without a pet replies through the owner session" do
    owner = start_player_session()

    simulate_incoming_message(owner.pid, %PetRequest{
      request_id: 42,
      command: {:menu, %PetMenuCommand{}}
    })

    assert_receive {:packet_sent,
                    %PetResult{request_id: 42, success: false, error: :PET_ERROR_NO_PET}, _},
                   1_000
  end
end
