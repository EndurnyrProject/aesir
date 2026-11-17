defmodule Aesir.ZoneServer.Unit.Pet.CommandHandlerTest do
  use ExUnit.Case, async: true

  alias Aesir.Net.PetCatchResult
  alias Aesir.Net.PetCatchTargetCommand
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

  test "a catch pick with no pet out still finishes the catch" do
    session = %SessionState{game_state: nil, connection_pid: self()}
    request = %PetRequest{request_id: 8, command: {:catch_target, %PetCatchTargetCommand{}}}

    assert {:noreply, ^session} = CommandHandler.request(request, session)

    assert_receive {:send, _, {:pet_catch_result, %PetCatchResult{success: false}}}
    assert_receive {:send, _, {:pet_result, %PetResult{request_id: 8, success: true}}}
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

  test "a stale think timer has no effect while a current one is consumed" do
    ref = make_ref()

    session = %SessionState{
      game_state: nil,
      connection_pid: self(),
      pet_runtime: %Runtime{generation: 2, ai_timer_ref: ref, movement_timer_ref: ref}
    }

    assert {:noreply, ^session} = CommandHandler.info({:ai_tick, 1}, ref, session)
    assert {:noreply, ^session} = CommandHandler.info({:move_step, 1}, ref, session)
    assert {:noreply, ticked} = CommandHandler.info({:ai_tick, 2}, ref, session)
    assert ticked.pet_runtime.ai_timer_ref == nil
    assert {:noreply, stepped} = CommandHandler.info({:move_step, 2}, ref, session)
    assert stepped.pet_runtime.movement_timer_ref == nil
  end
end
