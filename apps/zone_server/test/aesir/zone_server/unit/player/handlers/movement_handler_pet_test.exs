defmodule Aesir.ZoneServer.Unit.Player.Handlers.MovementHandlerPetTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.Combat.Knockback
  alias Aesir.ZoneServer.PlayerStateFixture
  alias Aesir.ZoneServer.Unit.Pet.PetState
  alias Aesir.ZoneServer.Unit.Pet.Runtime
  alias Aesir.ZoneServer.Unit.Pet.StateCommit
  alias Aesir.ZoneServer.Unit.Player.Handlers.MovementHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @moduletag :capture_log
  @map "pet_owner_map"

  setup :setup_ets_tables

  setup do
    :ets.insert(EtsTable.table_for(:map_cache), {@map, MapData.new(@map, 60, 60)})
    :ok
  end

  test "an unchecked owner movepos slides a pet that cannot path to the new cell" do
    for x <- 19..21, y <- 9..11, {x, y} != {20, 10}, do: block(x, y)
    session = session({20, 10})

    {:noreply, pulled} = MovementHandler.handle_movepos(session, 10, 10, @map, 12, 10)
    {:noreply, knocked} = MovementHandler.handle_displacement(session, 10, 10, @map, 12, 10)

    assert %PetState{x: 12, y: 10} = pulled.pet
    assert %PetState{x: 20, y: 10} = knocked.pet
  end

  test "an Ankle Snare pull of an owner already on the trap cell still slides the pet" do
    for x <- 19..21, y <- 9..11, {x, y} != {20, 10}, do: block(x, y)
    session = session({20, 10})

    assert {:ok, {10, 10}} =
             Knockback.pull_to(:player, 7, 10, 10, blown_immunity: true, unchecked_movepos: true)

    assert_received {:"$gen_cast", {:movement, {:movepos, 10, 10, @map, 10, 10}}}
    {:noreply, pulled} = MovementHandler.handle_movepos(session, 10, 10, @map, 10, 10)

    assert %PlayerState{x: 10, y: 10} = pulled.game_state
    assert %PetState{x: 10, y: 10} = pulled.pet
  end

  test "an owner walk start with the pet beyond the view range arms the recall" do
    {:noreply, walking} = MovementHandler.handle_request_move(session({40, 10}), 11, 10)

    assert walking.game_state.movement_state == :moving
    assert is_reference(walking.pet_runtime.teleport_timer_ref)
  end

  defp block(x, y), do: :ok = Cell.put(@map, x, y, :barrier, x * 1_000 + y, blocks_movement: true)

  defp session(pet_cell) do
    owner = owner()
    UnitRegistry.register_unit(:player, owner.character_id, PlayerState, owner, self())
    SpatialIndex.add_unit(:player, owner.character_id, owner.x, owner.y, @map)
    base = %SessionState{game_state: owner, connection_pid: self(), pet_runtime: %Runtime{}}
    {:ok, session} = StateCommit.spawn(base, pet(pet_cell))
    session
  end

  defp pet({x, y}) do
    %PetState{
      pet_id: 9,
      owner_char_id: 7,
      owner_account_id: 1_007,
      class_id: 1_002,
      name: "Poring",
      level: 5,
      egg_id: 9_001,
      intimate: 250,
      hungry: 80,
      map_name: @map,
      x: x,
      y: y
    }
  end

  defp owner do
    PlayerStateFixture.build(%{
      character_id: 7,
      character_name: "Owner",
      account_id: 1_007,
      map_name: @map,
      x: 10,
      y: 10,
      dir: 0,
      walk_speed: 150,
      view_range: 14,
      stats: %{}
    })
  end
end
