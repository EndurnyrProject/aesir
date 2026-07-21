defmodule Aesir.ZoneServer.Mmo.Skill.ForcedMovementTest do
  use ExUnit.Case, async: true

  import Mimic

  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Mmo.Combat.PendingWeaponHit
  alias Aesir.ZoneServer.Mmo.Skill.ForcedMovement
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup :verify_on_exit!

  setup do
    Mimic.copy(Cell)
    :ok
  end

  test "validates a same-map walkable destination within the requested range" do
    stub(Cell, :traversable?, fn "prontera", 14, 17 -> true end)

    caster = %PlayerState{map_name: "prontera", x: 10, y: 13}

    assert {:ok, directive} = ForcedMovement.validate(caster, 14, 17, 18)
    assert %ForcedMovement{map_name: "prontera", x: 14, y: 17} = directive
  end

  test "rejects a destination outside range before it can be committed" do
    caster = %PlayerState{map_name: "prontera", x: 10, y: 13}

    assert {:error, :out_of_range} = ForcedMovement.validate(caster, 29, 13, 18)
  end

  test "rejects an unwalkable destination" do
    stub(Cell, :traversable?, fn "prontera", 14, 17 -> false end)

    assert {:error, :invalid_destination} =
             ForcedMovement.validate(%PlayerState{map_name: "prontera", x: 10, y: 13}, 14, 17, 18)
  end

  test "death and relocation clear a staged directive" do
    directive = %ForcedMovement{map_name: "prontera", x: 14, y: 17}
    state = %PlayerState{action_state: :idle, pending_forced_movement: directive}

    {:ok, dead} = PlayerState.transition_to(state, :dead, %{})
    assert dead.pending_forced_movement == nil

    relocated = PlayerState.relocate(state, "geffen", 20, 20)
    assert relocated.pending_forced_movement == nil
  end

  test "idle clears forced movement without cancelling a pending Root offer" do
    pending =
      PendingWeaponHit.new(
        make_ref(),
        {:player, 101},
        {:mob, 202},
        %{unit: {:player, 303}, pid: self()},
        5_000,
        3_000,
        4_200
      )

    state = %PlayerState{
      action_state: :attacking,
      pending_weapon_hit: pending,
      pending_forced_movement: %ForcedMovement{map_name: "prontera", x: 14, y: 17}
    }

    {:ok, idle} = PlayerState.transition_to(state, :idle, %{})
    assert idle.pending_weapon_hit == pending
    assert idle.pending_forced_movement == nil
  end
end
