defmodule Aesir.ZoneServer.Unit.Mob.MobSessionTeleportTest do
  @moduledoc """
  Verifies the mob teleport reposition (`AL_TELEPORT`): the `{:movement, :teleport}`
  cast instantly relocates the mob to a random walkable cell, drops its target
  and returns it to `:idle`, routing the move through the same `Movement`
  choke point the knockback path uses. A map with no walkable cell is a clean
  no-op, not a crash.
  """

  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Movement

  setup do
    Mimic.copy(Cell)
    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)
    :ok
  end

  setup :verify_on_exit!

  @target_id 42

  defp build_mob_state(overrides \\ %{}) do
    mob_data = %MobDefinition{
      id: 1001,
      aegis_name: "test_mob",
      name: "Test Mob",
      level: 25,
      hp: 1000,
      sp: 0,
      stats: %{str: 40, agi: 30, vit: 50, int: 20, dex: 35, luk: 15},
      atk: 50,
      matk: 60,
      def: 25,
      mdef: 10,
      attack_range: 1,
      skill_range: 10,
      chase_range: 12,
      walk_speed: 200,
      attack_delay: 1200,
      attack_motion: 500,
      client_attack_motion: 400,
      damage_motion: 300,
      element: {:neutral, 1},
      race: :formless,
      size: :medium
    }

    spawn_ref = %MobSpawn{
      mob: 1001,
      amount: 1,
      respawn_time: 5000,
      spawn_area: %SpawnArea{x: 100, y: 100}
    }

    state =
      MobState.new(1, mob_data, spawn_ref, "prontera", 100, 100)
      |> MobState.set_target(@target_id)
      |> MobState.set_ai_state(:combat)

    struct(state, Map.new(overrides))
  end

  test "repositions to a walkable cell, drops the target and resets to idle" do
    test_pid = self()

    stub(Cell, :random_traversable, fn "prontera" -> {:ok, {150, 160}} end)

    expect(Movement, :set_position, fn :mob, 1, updated_state, "prontera" ->
      send(test_pid, {:reposition, updated_state.x, updated_state.y})
      :ok
    end)

    {:noreply, updated} = MobSession.handle_cast({:movement, :teleport}, build_mob_state())

    assert updated.x == 150
    assert updated.y == 160
    assert updated.target_ref == nil
    assert updated.ai_state == :idle
    assert updated.movement_state == :standing
    assert updated.deferred_epoch == 1

    assert_received {:reposition, 150, 160}
  end

  test "ordinary path movement preserves the deferred epoch" do
    stub(Cell, :step_traversable?, fn "prontera", {100, 100}, {101, 100} -> true end)
    stub(Movement, :set_position, fn :mob, 1, _state, "prontera" -> :ok end)

    state = build_mob_state() |> MobState.set_path([{101, 100}])

    {:noreply, updated} = MobSession.handle_info({:movement, :tick}, state)

    assert {updated.x, updated.y} == {101, 100}
    assert updated.deferred_epoch == 0
  end

  test "knockback relocation preserves the deferred epoch" do
    stub(Cell, :traversable?, fn "prontera", 110, 100 -> true end)
    stub(Movement, :set_position, fn :mob, 1, _state, "prontera" -> :ok end)

    state = build_mob_state()

    {:noreply, updated} =
      MobSession.handle_cast({:movement, {:relocate, 100, 100, "prontera", 110, 100}}, state)

    assert {updated.x, updated.y} == {110, 100}
    assert updated.deferred_epoch == 0
  end

  test "warps to a target cell and broadcasts the landing" do
    test_pid = self()

    stub(Cell, :traversable?, fn "prontera", 150, 160 -> true end)

    expect(Movement, :set_position, fn :mob, 1, updated_state, "prontera" ->
      send(test_pid, {:reposition, updated_state.x, updated_state.y})
      :ok
    end)

    expect(Broadcast, :to_in_range, fn "prontera", 150, 160, _range, packet ->
      send(test_pid, {:warp_packet, packet})
      :ok
    end)

    {:noreply, updated} =
      MobSession.handle_cast({:movement, {:warp, "prontera", 150, 160}}, build_mob_state())

    assert {updated.x, updated.y} == {150, 160}
    assert_received {:reposition, 150, 160}
    assert_received {:warp_packet, %Aesir.Net.Knockback{dst_x: 150, dst_y: 160}}
  end

  test "warp/4 casts a target-cell movement command" do
    assert :ok = MobSession.warp(self(), "prontera", 150, 160)
    assert_received {:"$gen_cast", {:movement, {:warp, "prontera", 150, 160}}}
  end

  test "is a clean no-op when no walkable cell is available" do
    stub(Cell, :random_traversable, fn "prontera" -> {:error, :no_walkable_cell} end)
    reject(&Movement.set_position/4)

    state = build_mob_state()

    assert {:noreply, ^state} = MobSession.handle_cast({:movement, :teleport}, state)
    assert state.deferred_epoch == 0
  end

  test "is a clean no-op when the map is not cached" do
    stub(Cell, :random_traversable, fn "prontera" -> {:error, :not_found} end)
    reject(&Movement.set_position/4)

    state = build_mob_state()

    assert {:noreply, ^state} = MobSession.handle_cast({:movement, :teleport}, state)
  end
end
