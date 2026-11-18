defmodule Aesir.ZoneServer.Unit.Pet.MovementTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Pet.Handlers.AiHandler
  alias Aesir.ZoneServer.Unit.Pet.Handlers.MovementHandler
  alias Aesir.ZoneServer.Unit.Pet.PetState
  alias Aesir.ZoneServer.Unit.Pet.Runtime
  alias Aesir.ZoneServer.Unit.Pet.StateCommit
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @map "pet_move_map"

  setup :setup_ets_tables

  setup do
    :ets.insert(EtsTable.table_for(:map_cache), {@map, MapData.new(@map, 60, 60)})
    :ok
  end

  describe "AiHandler.think/2" do
    test "chases an owner beyond the chase range at half the owner's speed" do
      session = session({30, 10}) |> AiHandler.think(1_000)

      assert session.pet.walk_speed == 75
      assert session.pet_runtime.chase_owner
      assert is_reference(session.pet_runtime.movement_timer_ref)
    end

    test "a fresh pet moves at a real, negative monotonic time" do
      now = -576_460_751_873

      assert AiHandler.think(session({30, 10}), now).pet_runtime.chase_owner

      idle = session({16, 10}, intimate: 0)
      :rand.seed(:exsss, {1, 2, 3})
      walked = AiHandler.think(idle, now)
      assert MovementHandler.walking?(walked)
      assert walked.pet_runtime.next_walk_at_ms > now
    end

    test "a chase walks to the owner's neighbour on its side, trimmed to range 3" do
      session = session({30, 30}) |> AiHandler.think(1_000)

      assert List.last(session.pet_runtime.movement_path) == {12, 12}
    end

    test "a detector-species pet loses a hidden owner at its chase path end" do
      walking = fn ->
        session = session({21, 10}, class_id: 1_109)
        ref = make_ref()

        runtime = %{
          session.pet_runtime
          | movement_path: [{21, 10}, {20, 10}],
            movement_timer_ref: ref,
            chase_owner: true
        }

        MovementHandler.step(ref, %{session | pet_runtime: runtime})
      end

      assert MovementHandler.walking?(walking.())

      :ok = StatusStorage.apply_status(:player, 7, :sc_hiding)
      stopped = walking.()

      refute MovementHandler.walking?(stopped)
      assert %PetState{x: 20, y: 10} = stopped.pet
    end

    test "stays put within 3 cells of the owner" do
      session = session({12, 10})

      assert AiHandler.think(session, 1_000) == session
    end

    test "walks to the follow cell behind the owner otherwise" do
      session = session({16, 10}) |> AiHandler.think(1_000)

      assert List.last(session.pet_runtime.movement_path) == {10, 8}
      refute session.pet_runtime.chase_owner
    end

    test "random walks at intimacy 0" do
      session = session({16, 10}, intimate: 0) |> AiHandler.think(1_000)

      assert session.pet_runtime.next_walk_at_ms >= 5_000
      refute List.last(session.pet_runtime.movement_path) == {10, 8}
    end

    test "does not decide while a walk has just started" do
      session = session({30, 10})
      runtime = %{session.pet_runtime | movement_timer_ref: make_ref(), path_pos: 2}
      session = %{session | pet_runtime: runtime}

      assert AiHandler.think(session, 1_000) == session
    end

    test "restores the normal speed once back in range and done walking" do
      session = session({12, 10}, walk_speed: 75) |> AiHandler.think(1_000)

      assert session.pet.walk_speed == 150
    end
  end

  describe "MovementHandler.calc_pos/2" do
    test "two cells behind the owner's facing, then one, then a random direction" do
      %SessionState{pet: pet, game_state: owner} = session({16, 10})

      assert MovementHandler.calc_pos(pet, owner) == {10, 8}

      block(10, 8)
      assert MovementHandler.calc_pos(pet, owner) == {10, 9}

      block(10, 9)
      {x, y} = MovementHandler.calc_pos(pet, owner)
      assert {x, y} not in [{10, 8}, {10, 9}]
      assert max(abs(x - 10), abs(y - 10)) in 1..2
    end
  end

  describe "MovementHandler.random_walk/2" do
    test "next walk is now + 4000 + path cost + rnd(0..999)" do
      session = session({30, 30}, intimate: 0) |> MovementHandler.random_walk(1_000)

      cost =
        session.pet_runtime.movement_path
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.map(fn [{x1, y1}, {x2, y2}] -> if x1 != x2 and y1 != y2, do: 210, else: 150 end)
        |> Enum.sum()

      assert (session.pet_runtime.next_walk_at_ms - 1_000 - 4_000 - cost) in 0..999
      assert session.pet_runtime.move_fail_count == 0
    end

    test "does nothing before the next walk time" do
      session = session({30, 30}, intimate: 0)
      session = %{session | pet_runtime: %{session.pet_runtime | next_walk_at_ms: 2_000}}

      assert MovementHandler.random_walk(session, 1_000) == session
    end
  end

  describe "MovementHandler.slide_to_owner/2" do
    test "an unchecked instant move slides a pet that cannot path to the owner" do
      for {dx, dy} <- [{-1, -1}, {0, -1}, {1, -1}, {-1, 0}, {1, 0}, {-1, 1}, {0, 1}, {1, 1}],
          do: block(20 + dx, 10 + dy)

      session = session({20, 10})

      assert MovementHandler.slide_to_owner(session, true) == session
      assert %PetState{x: 10, y: 10} = MovementHandler.slide_to_owner(session, false).pet
    end

    test "a pet beyond the view range slides even on a checked move" do
      assert %PetState{x: 10, y: 10} = MovementHandler.slide_to_owner(session({40, 10}), true).pet
    end
  end

  describe "recall timer" do
    test "an owner walk start with the pet far away arms a recall that warps it back" do
      session = session({40, 10}) |> MovementHandler.check_recall()
      ref = session.pet_runtime.teleport_timer_ref
      assert is_reference(ref)

      recalled = MovementHandler.recall_timeout(ref, session)
      assert %PetState{x: 10, y: 10} = recalled.pet
      assert recalled.pet_runtime.teleport_timer_ref == nil
    end

    test "the recall leaves a pet that came back in range" do
      far = session({40, 10}) |> MovementHandler.check_recall()
      ref = far.pet_runtime.teleport_timer_ref
      near = StateCommit.commit(far, %{far.pet | x: 15})

      recalled = MovementHandler.recall_timeout(ref, near)
      assert %PetState{x: 15, y: 10} = recalled.pet
      assert recalled.pet_runtime.teleport_timer_ref == nil
    end

    test "an owner walk start with the pet in range cancels an armed recall" do
      session = session({40, 10}) |> MovementHandler.check_recall()
      near = StateCommit.commit(session, %{session.pet | x: 15})

      assert MovementHandler.check_recall(near).pet_runtime.teleport_timer_ref == nil
    end
  end

  defp block(x, y), do: :ok = Cell.put(@map, x, y, :barrier, x * 1_000 + y, blocks_movement: true)

  defp session({x, y}, overrides \\ []) do
    pet =
      struct!(
        %PetState{
          pet_id: 9,
          owner_char_id: 7,
          owner_account_id: 1_007,
          class_id: 1_002,
          mob_db_id: 1_002,
          name: "Poring",
          level: 5,
          egg_id: 9_001,
          intimate: 250,
          hungry: 80,
          map_name: @map,
          x: x,
          y: y
        },
        overrides
      )

    :ok = UnitRegistry.register_player(owner(), self())
    base = %SessionState{game_state: owner(), connection_pid: self(), pet_runtime: %Runtime{}}
    {:ok, session} = StateCommit.spawn(base, pet)
    session
  end

  defp owner do
    %PlayerState{
      character_id: 7,
      character_name: "Owner",
      account_id: 1_007,
      map_name: @map,
      x: 10,
      y: 10,
      dir: 0,
      walk_speed: 150,
      movement_state: :standing,
      view_range: 14,
      stats:
        Stats.from_character(%Character{
          class: 0,
          base_level: 1,
          job_level: 1,
          str: 1,
          agi: 1,
          vit: 1,
          int: 1,
          dex: 1,
          luk: 1
        })
    }
  end
end
