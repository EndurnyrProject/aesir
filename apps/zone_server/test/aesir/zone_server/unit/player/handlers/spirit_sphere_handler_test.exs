defmodule Aesir.ZoneServer.Unit.Player.Handlers.SpiritSphereHandlerTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup
  alias Aesir.Commons.Models.Character
  alias Aesir.Net.SpiritSphereUpdate
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Player.Handlers.SpiritSphereHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SpiritSpheres

  setup :verify_on_exit!
  setup :setup_ets_tables

  test "summoning schedules the nearest expiry and sends an absolute update" do
    Mimic.copy(Broadcast)

    expect(Broadcast, :to_visible_players, fn game_state,
                                              %SpiritSphereUpdate{
                                                unit_id: 1,
                                                count: 1,
                                                revision: 1
                                              },
                                              exclude_id: 1 ->
      assert game_state.character_id == 1
      :ok
    end)

    assert {:noreply, %{game_state: game_state}} =
             SpiritSphereHandler.summon(session_state(), 60_000, 5)

    assert game_state.spirit_sphere_revision == 1
    assert game_state.spirit_sphere_timer_generation == 1
    assert is_reference(game_state.spirit_sphere_timer)

    assert_receive {:send, :world,
                    {:spirit_sphere_update,
                     %SpiritSphereUpdate{unit_id: 1, count: 1, revision: 1}}}

    Process.cancel_timer(game_state.spirit_sphere_timer)
  end

  test "receiving a sphere rejects a full target without replacing an existing sphere" do
    Mimic.copy(Broadcast)
    reject(&Broadcast.to_visible_players/3)

    state = session_state()
    now = System.monotonic_time(:millisecond)
    {spheres, first} = SpiritSpheres.summon(state.game_state.spirit_spheres, now + 60_000, 1)
    state = put_in(state.game_state.spirit_spheres, spheres)

    assert SpiritSphereHandler.receive_sphere(state, 60_000, 1) == {:error, :full}
    assert SpiritSpheres.entries(state.game_state.spirit_spheres) == [first]
  end

  test "one matching timer expiry removes every due sphere in one revision" do
    Mimic.copy(Broadcast)
    now = System.monotonic_time(:millisecond)
    {spheres, _} = SpiritSpheres.new() |> SpiritSpheres.summon(now - 1, 5)
    {spheres, _} = SpiritSpheres.summon(spheres, now - 1, 5)

    expect(Broadcast, :to_visible_players, fn _game_state,
                                              %SpiritSphereUpdate{count: 0, revision: 10},
                                              exclude_id: 1 ->
      :ok
    end)

    state = %{
      session_state()
      | game_state: %{
          session_state().game_state
          | spirit_spheres: spheres,
            spirit_sphere_timer_generation: 3,
            spirit_sphere_revision: 9
        }
    }

    assert {:noreply, %{game_state: game_state}} = SpiritSphereHandler.expire(state, 3)
    assert SpiritSpheres.count(game_state.spirit_spheres) == 0
    assert game_state.spirit_sphere_revision == 10

    assert_receive {:send, :world,
                    {:spirit_sphere_update, %SpiritSphereUpdate{count: 0, revision: 10}}}
  end

  test "a stale timer generation is a no-op" do
    timer_ref = Process.send_after(self(), :unexpected, 60_000)

    state = %{
      session_state()
      | game_state: %{
          session_state().game_state
          | spirit_sphere_timer: timer_ref,
            spirit_sphere_timer_generation: 3
        }
    }

    assert {:noreply, ^state} = SpiritSphereHandler.expire(state, 2)
    Process.cancel_timer(timer_ref)
  end

  test "map relocation preserves spheres" do
    state = session_state().game_state
    {spheres, entry} = SpiritSpheres.summon(state.spirit_spheres, 100, 5)

    relocated =
      %{state | spirit_spheres: spheres}
      |> PlayerState.relocate("morocc", 100, 100)

    assert SpiritSpheres.entries(relocated.spirit_spheres) == [entry]
  end

  defp session_state do
    character = %Character{
      id: 1,
      account_id: 2,
      name: "Monk",
      last_map: "prontera",
      last_x: 50,
      last_y: 50,
      sex: "M",
      str: 1,
      agi: 1,
      vit: 1,
      int: 1,
      dex: 1,
      luk: 1,
      base_level: 1,
      job_level: 1,
      class: 0
    }

    %{connection_pid: self(), game_state: PlayerState.new(character)}
  end
end
