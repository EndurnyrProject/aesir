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

  test "map relocation preserves spheres while cancelling their reservation" do
    state = session_state().game_state
    {spheres, entry} = SpiritSpheres.summon(state.spirit_spheres, 100, 5)
    assert {:ok, spheres, [_]} = SpiritSpheres.reserve(spheres, :transfer, 1)

    relocated =
      %{
        state
        | spirit_spheres: spheres,
          pending_spirit_sphere_action: %{operation_id: :transfer, entry_ids: [entry.id]}
      }
      |> PlayerState.relocate("morocc", 100, 100)

    assert SpiritSpheres.count(relocated.spirit_spheres) == 1
    assert [%{id: entry_id, reserved_by: nil}] = SpiritSpheres.entries(relocated.spirit_spheres)
    assert entry_id == entry.id
    assert relocated.pending_spirit_sphere_action == nil
  end

  test "a second operation cannot overlap or stale-release the active reservation" do
    state = session_state()
    {spheres, _} = SpiritSpheres.summon(state.game_state.spirit_spheres, 100, 5)
    {spheres, _} = SpiritSpheres.summon(spheres, 200, 5)
    state = put_in(state.game_state.spirit_spheres, spheres)

    assert {:ok, reserved_state, [reserved]} = SpiritSphereHandler.reserve(state, :a, 1)
    assert {:error, :pending_operation} = SpiritSphereHandler.reserve(reserved_state, :b, 1)
    assert SpiritSphereHandler.release(reserved_state, :b) == reserved_state

    assert [%{id: reserved_id, reserved_by: :a}, %{reserved_by: nil}] =
             SpiritSpheres.entries(reserved_state.game_state.spirit_spheres)

    assert reserved_id == reserved.id

    assert reserved_state.game_state.pending_spirit_sphere_action == %{
             operation_id: :a,
             entry_ids: [reserved.id]
           }

    released_state = SpiritSphereHandler.release(reserved_state, :a)

    assert Enum.all?(
             SpiritSpheres.entries(released_state.game_state.spirit_spheres),
             &is_nil(&1.reserved_by)
           )

    assert released_state.game_state.pending_spirit_sphere_action == nil
  end

  test "the same operation can retry only its exact reservation" do
    state = session_state()
    {spheres, _} = SpiritSpheres.summon(state.game_state.spirit_spheres, 100, 5)
    {spheres, _} = SpiritSpheres.summon(spheres, 200, 5)
    state = put_in(state.game_state.spirit_spheres, spheres)

    assert {:ok, reserved_state, [reserved]} = SpiritSphereHandler.reserve(state, :a, 1)
    assert {:ok, ^reserved_state, [retried]} = SpiritSphereHandler.reserve(reserved_state, :a, 1)
    assert retried.id == reserved.id
    assert {:error, :operation_mismatch} = SpiritSphereHandler.reserve(reserved_state, :a, 2)
  end

  test "pending reservation records the complete reserved entry set" do
    state = session_state()
    {spheres, first} = SpiritSpheres.summon(state.game_state.spirit_spheres, 100, 5)
    {spheres, second} = SpiritSpheres.summon(spheres, 200, 5)
    state = put_in(state.game_state.spirit_spheres, spheres)

    assert {:ok, reserved_state, [_first, _second]} =
             SpiritSphereHandler.reserve(state, :a, 2)

    assert reserved_state.game_state.pending_spirit_sphere_action == %{
             operation_id: :a,
             entry_ids: [first.id, second.id]
           }
  end

  test "cap replacement keeps a reserved oldest sphere and reschedules once" do
    Mimic.copy(Broadcast)

    expect(Broadcast, :to_visible_players, fn game_state,
                                              %SpiritSphereUpdate{count: 2, revision: 10},
                                              exclude_id: 1 ->
      assert [%{id: 1, reserved_by: :a}, %{id: 3, reserved_by: nil}] =
               SpiritSpheres.entries(game_state.spirit_spheres)

      :ok
    end)

    state = session_state()
    now = System.monotonic_time(:millisecond)
    {spheres, _} = SpiritSpheres.summon(state.game_state.spirit_spheres, now + 60_000, 2)
    {spheres, _} = SpiritSpheres.summon(spheres, now + 120_000, 2)
    assert {:ok, spheres, [_]} = SpiritSpheres.reserve(spheres, :a, 1)
    old_timer = Process.send_after(self(), :old_sphere_expiry, 60_000)

    state = %{
      state
      | game_state: %{
          state.game_state
          | spirit_spheres: spheres,
            spirit_sphere_timer: old_timer,
            spirit_sphere_timer_generation: 4,
            spirit_sphere_revision: 9,
            pending_spirit_sphere_action: %{operation_id: :a, entry_ids: [1]}
        }
    }

    assert {:noreply, %{game_state: game_state}} = SpiritSphereHandler.summon(state, 180_000, 2)
    assert game_state.spirit_sphere_timer_generation == 5
    assert game_state.spirit_sphere_revision == 10
    assert Process.cancel_timer(old_timer) == false
    assert is_integer(Process.read_timer(game_state.spirit_sphere_timer))
    Process.cancel_timer(game_state.spirit_sphere_timer)
  end

  test "summoning with every capped sphere reserved changes no timer or revision" do
    Mimic.copy(Broadcast)
    reject(&Broadcast.to_visible_players/3)

    state = session_state()
    now = System.monotonic_time(:millisecond)
    {spheres, _} = SpiritSpheres.summon(state.game_state.spirit_spheres, now + 60_000, 2)
    {spheres, _} = SpiritSpheres.summon(spheres, now + 60_000, 2)
    assert {:ok, spheres, _} = SpiritSpheres.reserve(spheres, :a, 2)
    timer_ref = Process.send_after(self(), :sphere_expiry, 60_000)

    state = %{
      state
      | game_state: %{
          state.game_state
          | spirit_spheres: spheres,
            spirit_sphere_timer: timer_ref,
            spirit_sphere_timer_generation: 4,
            spirit_sphere_revision: 9,
            pending_spirit_sphere_action: %{operation_id: :a, entry_ids: [1, 2]}
        }
    }

    assert {:noreply, ^state} = SpiritSphereHandler.summon(state, 60_000, 2)
    assert is_integer(Process.read_timer(timer_ref))
    refute_receive {:send, :world, {:spirit_sphere_update, _}}
    Process.cancel_timer(timer_ref)
  end

  test "only the matching operation can consume its exact reservation" do
    Mimic.copy(Broadcast)
    expect(Broadcast, :to_visible_players, 2, fn _game_state, _update, exclude_id: 1 -> :ok end)

    state = session_state()
    now = System.monotonic_time(:millisecond)
    {spheres, reserved} = SpiritSpheres.summon(state.game_state.spirit_spheres, now + 60_000, 5)
    {spheres, unreserved} = SpiritSpheres.summon(spheres, now + 60_000, 5)
    state = put_in(state.game_state.spirit_spheres, spheres)

    assert {:ok, reserved_state, [_]} = SpiritSphereHandler.reserve(state, :a, 1)
    assert {:ok, consumed_state} = SpiritSphereHandler.consume(reserved_state, 1)

    assert consumed_state.game_state.pending_spirit_sphere_action == %{
             operation_id: :a,
             entry_ids: [reserved.id]
           }

    assert [remaining] = SpiritSpheres.entries(consumed_state.game_state.spirit_spheres)
    assert remaining.id == reserved.id
    refute remaining.id == unreserved.id

    assert {:error, :stale_operation} = SpiritSphereHandler.consume_reserved(consumed_state, :b)

    assert consumed_state.game_state.pending_spirit_sphere_action == %{
             operation_id: :a,
             entry_ids: [reserved.id]
           }

    assert [%{reserved_by: :a}] = SpiritSpheres.entries(consumed_state.game_state.spirit_spheres)

    assert {:ok, settled_state} = SpiritSphereHandler.consume_reserved(consumed_state, :a)
    assert SpiritSpheres.count(settled_state.game_state.spirit_spheres) == 0
    assert settled_state.game_state.pending_spirit_sphere_action == nil
    assert settled_state.game_state.spirit_sphere_revision == 2

    assert_receive {:send, :world,
                    {:spirit_sphere_update, %SpiritSphereUpdate{count: 1, revision: 1}}}

    assert_receive {:send, :world,
                    {:spirit_sphere_update, %SpiritSphereUpdate{count: 0, revision: 2}}}
  end

  test "clearing during a reservation cancels it and makes stale release harmless" do
    Mimic.copy(Broadcast)

    expect(Broadcast, :to_visible_players, fn _game_state,
                                              %SpiritSphereUpdate{count: 0},
                                              exclude_id: 1 ->
      :ok
    end)

    state = session_state()
    {spheres, _} = SpiritSpheres.summon(state.game_state.spirit_spheres, 100, 5)
    state = put_in(state.game_state.spirit_spheres, spheres)
    assert {:ok, reserved_state, [_]} = SpiritSphereHandler.reserve(state, :a, 1)

    cleared_state = SpiritSphereHandler.clear(reserved_state)
    assert cleared_state.game_state.pending_spirit_sphere_action == nil
    assert SpiritSphereHandler.release(cleared_state, :a) == cleared_state

    {spheres, _} = SpiritSpheres.summon(cleared_state.game_state.spirit_spheres, 200, 5)
    cleared_state = put_in(cleared_state.game_state.spirit_spheres, spheres)
    assert {:ok, reservable_state, [_]} = SpiritSphereHandler.reserve(cleared_state, :b, 1)
    assert reservable_state.game_state.pending_spirit_sphere_action != nil
  end

  test "expiry of one reserved member invalidates the exact set and releases the survivor" do
    Mimic.copy(Broadcast)

    expect(Broadcast, :to_visible_players, fn _game_state,
                                              %SpiritSphereUpdate{count: 1, revision: 1},
                                              exclude_id: 1 ->
      :ok
    end)

    state = session_state()
    now = System.monotonic_time(:millisecond)
    {spheres, expired} = SpiritSpheres.summon(state.game_state.spirit_spheres, now - 1, 5)
    {spheres, survivor} = SpiritSpheres.summon(spheres, now + 60_000, 5)
    state = put_in(state.game_state.spirit_spheres, spheres)

    assert {:ok, reserved_state, [_expired, _survivor]} =
             SpiritSphereHandler.reserve(state, :a, 2)

    reserved_state = put_in(reserved_state.game_state.spirit_sphere_timer_generation, 4)

    assert {:noreply, expired_state} = SpiritSphereHandler.expire(reserved_state, 4)

    assert [%{id: survivor_id, reserved_by: nil}] =
             SpiritSpheres.entries(expired_state.game_state.spirit_spheres)

    assert survivor_id == survivor.id
    refute survivor_id == expired.id
    assert expired_state.game_state.pending_spirit_sphere_action == nil
    assert expired_state.game_state.spirit_sphere_revision == 1
    assert {:error, :stale_operation} = SpiritSphereHandler.consume_reserved(expired_state, :a)
    assert SpiritSphereHandler.release(expired_state, :a) == expired_state
    Process.cancel_timer(expired_state.game_state.spirit_sphere_timer)
  end

  test "simultaneous reserved expiries invalidate once and stale settlement is harmless" do
    Mimic.copy(Broadcast)

    expect(Broadcast, :to_visible_players, fn _game_state,
                                              %SpiritSphereUpdate{count: 0, revision: 8},
                                              exclude_id: 1 ->
      :ok
    end)

    state = session_state()
    now = System.monotonic_time(:millisecond)
    {spheres, _} = SpiritSpheres.summon(state.game_state.spirit_spheres, now - 1, 5)
    {spheres, _} = SpiritSpheres.summon(spheres, now - 1, 5)
    state = put_in(state.game_state.spirit_spheres, spheres)
    assert {:ok, reserved_state, [_first, _second]} = SpiritSphereHandler.reserve(state, :a, 2)

    reserved_state = %{
      reserved_state
      | game_state: %{
          reserved_state.game_state
          | spirit_sphere_timer_generation: 4,
            spirit_sphere_revision: 7
        }
    }

    assert {:noreply, expired_state} = SpiritSphereHandler.expire(reserved_state, 4)
    assert SpiritSpheres.count(expired_state.game_state.spirit_spheres) == 0
    assert expired_state.game_state.pending_spirit_sphere_action == nil
    assert expired_state.game_state.spirit_sphere_revision == 8
    assert {:error, :stale_operation} = SpiritSphereHandler.consume_reserved(expired_state, :a)
    assert SpiritSphereHandler.release(expired_state, :a) == expired_state
  end

  test "settlement rejects and cleans an incomplete reservation snapshot" do
    state = session_state()
    now = System.monotonic_time(:millisecond)
    {spheres, first} = SpiritSpheres.summon(state.game_state.spirit_spheres, now - 1, 5)
    {spheres, survivor} = SpiritSpheres.summon(spheres, now + 60_000, 5)
    state = put_in(state.game_state.spirit_spheres, spheres)
    assert {:ok, reserved_state, [_first, _survivor]} = SpiritSphereHandler.reserve(state, :a, 2)

    {damaged_spheres, [expired]} =
      SpiritSpheres.expire_due(reserved_state.game_state.spirit_spheres, now)

    assert expired.id == first.id
    damaged_state = put_in(reserved_state.game_state.spirit_spheres, damaged_spheres)

    assert {:error, :reservation_changed, cleaned_state} =
             SpiritSphereHandler.consume_reserved(damaged_state, :a)

    assert cleaned_state.game_state.pending_spirit_sphere_action == nil

    assert [%{id: survivor_id, reserved_by: nil}] =
             SpiritSpheres.entries(cleaned_state.game_state.spirit_spheres)

    assert survivor_id == survivor.id
    assert SpiritSphereHandler.release(cleaned_state, :a) == cleaned_state
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
