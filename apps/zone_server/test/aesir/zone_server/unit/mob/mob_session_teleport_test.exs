defmodule Aesir.ZoneServer.Unit.Mob.MobSessionTeleportTest do
  @moduledoc """
  Verifies the mob warps (`AL_TELEPORT`, Tarot, Snatch): the mob leaves its map
  and is put back. Its cast is cancelled, its attack and walk delays end, it
  keeps its target, returns to `:idle`, loses the statuses a unit leaving its
  map loses, is moved through `Movement.warp_position/4` (which leaves its
  ground units, then vanishes it with the teleport reason) and spawns on the
  new cell. A knockback relocation stays a step. A map with no walkable cell
  is a clean no-op, not a crash.
  """

  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.Handlers.MovementHandler
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Mob.SpawnView
  alias Aesir.ZoneServer.Unit.Movement

  setup do
    Mimic.copy(Cell)
    Mimic.copy(SpawnView)
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
      |> MobState.set_state(:berserk)

    struct(state, Map.new(overrides))
  end

  test "teleports as a removal from the map: statuses, warp, spawn; the target stays" do
    stub(Cell, :random_traversable, fn "prontera" -> {:ok, {150, 160}} end)
    reject(&Movement.set_position/4)
    expect_removal_sequence({150, 160})

    {:noreply, updated} = MobSession.handle_cast({:movement, :teleport}, build_mob_state())

    assert {updated.x, updated.y} == {150, 160}
    assert updated.target_ref == {:player, @target_id}
    assert updated.skill_state == :idle
    assert updated.movement_state == :standing
    assert updated.deferred_epoch == 1

    assert_removal_sequence({150, 160})
  end

  test "a warp cancels the cast and ends the attack and walk delays" do
    stub(Cell, :random_traversable, fn "prontera" -> {:ok, {150, 160}} end)
    stub(Movement, :warp_position, fn :mob, 1, _state, "prontera" -> :ok end)
    stub(StatusInterpreter, :remove_on_map_change, fn :mob, 1 -> :ok end)
    stub(SpawnView, :notify_spawn, fn state -> {:ok, state} end)

    now = System.system_time(:millisecond)

    state =
      build_mob_state(%{
        casting: %{row: %{skill_id: 28, delay: 5_000}, complete_at: now + 2_000, timer_ref: nil},
        last_attack_time: now,
        walk_delay_until: System.monotonic_time(:millisecond) + 10_000,
        attack_target: {:player, @target_id},
        attack_timer_at: now + 500,
        attacked_ref: {:player, 7},
        norm_attacked_ref: {:player, 7}
      })

    {:noreply, updated} = MobSession.handle_cast({:movement, :teleport}, state)

    assert updated.casting == nil
    assert updated.last_attack_time == nil
    assert updated.walk_delay_until == 0
    assert updated.attack_target == nil
    assert updated.attack_timer_at == nil
    assert updated.attacked_ref == nil
    assert updated.norm_attacked_ref == {:player, 7}
    assert MobState.walk_delayed?(updated, System.monotonic_time(:millisecond)) == false
  end

  test "ordinary path movement preserves the deferred epoch" do
    stub(Cell, :step_traversable?, fn "prontera", {100, 100}, {101, 100} -> true end)
    stub(Movement, :set_position, fn :mob, 1, _state, "prontera" -> :ok end)

    state = build_mob_state() |> MobState.set_path([{101, 100}])

    {:noreply, updated} = MovementHandler.handle_movement_tick(state)

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

  test "a Snatch warp vanishes and spawns the mob instead of sliding it" do
    stub(Cell, :traversable?, fn "prontera", 150, 160 -> true end)
    reject(&Movement.set_position/4)
    expect_removal_sequence({150, 160})

    reject(&Broadcast.to_in_range/5)

    {:noreply, updated} =
      MobSession.handle_cast({:movement, {:warp, "prontera", 150, 160}}, build_mob_state())

    assert {updated.x, updated.y} == {150, 160}
    assert_removal_sequence({150, 160})
  end

  test "a warp onto the cell it stands on still removes and re-adds the mob" do
    stub(Cell, :traversable?, fn "prontera", 100, 100 -> true end)
    expect_removal_sequence({100, 100})

    {:noreply, _updated} =
      MobSession.handle_cast({:movement, {:warp, "prontera", 100, 100}}, build_mob_state())

    assert_removal_sequence({100, 100})
  end

  test "warp/4 casts a target-cell movement command" do
    assert :ok = MobSession.warp(self(), "prontera", 150, 160)
    assert_received {:"$gen_cast", {:movement, {:warp, "prontera", 150, 160}}}
  end

  test "is a clean no-op when no walkable cell is available" do
    stub(Cell, :random_traversable, fn "prontera" -> {:error, :no_walkable_cell} end)
    reject(&Movement.warp_position/4)

    state = build_mob_state()

    assert {:noreply, ^state} = MobSession.handle_cast({:movement, :teleport}, state)
    assert state.deferred_epoch == 0
  end

  test "is a clean no-op when the map is not cached" do
    stub(Cell, :random_traversable, fn "prontera" -> {:error, :not_found} end)
    reject(&Movement.warp_position/4)

    state = build_mob_state()

    assert {:noreply, ^state} = MobSession.handle_cast({:movement, :teleport}, state)
  end

  defp expect_removal_sequence({x, y}) do
    test_pid = self()

    expect(StatusInterpreter, :remove_on_map_change, fn :mob, 1 ->
      send(test_pid, :statuses_ended)
      :ok
    end)

    expect(Movement, :warp_position, fn :mob, 1, updated_state, "prontera" ->
      send(test_pid, {:reposition, updated_state.x, updated_state.y})
      :ok
    end)

    expect(SpawnView, :notify_spawn, fn %MobState{x: ^x, y: ^y} = state ->
      send(test_pid, :spawn)
      {:ok, state}
    end)
  end

  defp assert_removal_sequence({x, y}) do
    {:messages, messages} = Process.info(self(), :messages)

    assert messages == [
             :statuses_ended,
             {:reposition, x, y},
             :spawn
           ]
  end
end
