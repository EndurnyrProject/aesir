defmodule Aesir.ZoneServer.Unit.Pet.CommandHandlerTest do
  use ExUnit.Case, async: true

  alias Aesir.Net.PetRequest
  alias Aesir.Net.PetResult
  alias Aesir.ZoneServer.Unit.Pet.Clock
  alias Aesir.ZoneServer.Unit.Pet.Handlers.CommandHandler
  alias Aesir.ZoneServer.Unit.Pet.PetState
  alias Aesir.ZoneServer.Unit.Pet.Runtime
  alias Aesir.ZoneServer.Unit.Player.SessionState

  test "unsupported request with a pet replies invalid request" do
    pet = %PetState{
      pet_id: 1,
      owner_char_id: 1,
      owner_account_id: 1,
      class_id: 1002,
      name: "Poring",
      level: 1,
      egg_id: 1,
      intimate: 1,
      hungry: 1
    }

    session = %SessionState{game_state: nil, connection_pid: self(), pet: pet}

    assert {:noreply, ^session} = CommandHandler.request(%PetRequest{request_id: 7}, session)

    assert_receive {:send, _,
                    {:pet_result,
                     %PetResult{request_id: 7, success: false, error: :PET_ERROR_INVALID_REQUEST}}}
  end

  test "pet clock delivers the captured generation" do
    ref = Clock.arm(0, :hunger_tick, 3)
    assert_receive {:timeout, ^ref, {:pet, {:hunger_tick, 3}}}
    assert :ok = Clock.cancel(ref)
  end

  test "stale pet timer is ignored" do
    session = %SessionState{
      game_state: nil,
      connection_pid: self(),
      pet_runtime: %Runtime{generation: 2}
    }

    assert {:noreply, ^session} = CommandHandler.info({:hunger_tick, 1}, make_ref(), session)
  end
end
