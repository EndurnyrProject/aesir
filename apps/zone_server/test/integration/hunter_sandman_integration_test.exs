defmodule Aesir.ZoneServer.Integration.HunterSandmanIntegrationTest do
  use Aesir.ZoneServer.IntegrationCase

  # The sessions here are backed by in-memory characters with no DB row, so the
  # real movement persistence path logs a :character_not_found error per step.
  @moduletag :capture_log

  alias Aesir.Net.MoveRequest
  alias Aesir.ZoneServer.Mmo.MobSkill.Executor
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.Skill.Unit.TrapState
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @map "prontera"

  test "Sandman armed, natural, reclaim, and Spring lifecycle eligibility is real" do
    player = start_player_session(id: 98_121, name: "SandmanOwner", position: {170, 170})
    now = System.monotonic_time(:millisecond)

    spring = sandman_group(119_121, player.character.id, {171, 170}, now + 60_000)
    reclaim = sandman_group(119_122, player.character.id, {172, 170}, now + 60_000)
    natural = sandman_group(119_123, player.character.id, {173, 170}, now + 100)

    assert :ok = Manager.register(spring)
    assert :ok = Manager.register(reclaim)
    assert :ok = Manager.register(natural)

    assert {:ok, %{group_id: 119_121}} = Manager.spring_trap(@map, 171, 170)
    assert %Group{state: %{trap: %TrapState{phase: :sprung}}} = Storage.get(119_121)

    assert {:ok, %{group_id: 119_122, item_id: 1065}} =
             Manager.reclaim_trap({:player, player.character.id}, @map, 172, 170)

    assert nil == Storage.get(119_122)
    assert :ok = Manager.tick(Manager, now + 100)
    assert nil == Storage.get(119_123)
  end

  test "a boss immunity rejection still spends a legitimately activated trap" do
    player = start_player_session(id: 98_120, name: "SandmanCaster", position: {160, 160})
    boss = spawn_test_mob(@map, {161, 160}, unit_id: 99_120, modes: [:boss])
    on_exit(fn -> StatusStorage.clear_unit_statuses(:mob, boss.unit_id) end)

    now = System.monotonic_time(:millisecond)

    group = %Group{
      group_id: 119_120,
      skill_id: 119,
      skill_name: :ht_sandman,
      level: 5,
      caster_id: player.character.id,
      caster_type: :player,
      map_name: @map,
      center: {161, 160},
      cells: [{161, 160}],
      next_tick_at: now + 60_000,
      expires_at: now + 60_000,
      interval: 1_000,
      visibility: :party_only,
      state: %{trap: %TrapState{reclaim_item_id: 1065, claymore_spendable?: true}}
    }

    assert :ok = Manager.register(group)
    assert :ok = Manager.trigger(group.group_id, {:mob, boss.unit_id}, :on_touch)
    refute StatusStorage.has_status?(:mob, boss.unit_id, :sc_sleep)

    assert %Group{visibility: :party_only, state: %{trap: %TrapState{phase: :used}}} =
             Storage.get(group.group_id)
  end

  test "mob Executor placement is activated by real player movement and stores Sleep" do
    player = start_player_session(id: 98_119, name: "SandmanTarget", position: {150, 150})
    inside = start_player_session(id: 98_118, name: "InsideArea", position: {152, 152})
    outside = start_player_session(id: 98_117, name: "OutsideArea", position: {153, 150})
    mob = spawn_test_mob(@map, {145, 150}, unit_id: 99_119)

    on_exit(fn ->
      for id <- [player.character.id, inside.character.id, outside.character.id],
          do: StatusStorage.clear_unit_statuses(:player, id)
    end)

    row = %{
      skill: "HT_SANDMAN",
      skill_id: 119,
      level: 5,
      target: :target,
      emotion: nil
    }

    caster = %{get_mob_state(mob.pid) | target_id: player.character.id}

    assert {:ok, _} = UnitRegistry.get_unit_info(:player, inside.character.id)
    assert {:ok, _} = UnitRegistry.get_unit_info(:player, outside.character.id)
    assert :ok = Executor.execute(caster, row)

    assert %Group{
             caster_type: :mob,
             caster_id: 99_119,
             center: {150, 150},
             state: %{trap: %TrapState{phase: :armed}}
           } = trap = Enum.find(Storage.all(), &(&1.skill_name == :ht_sandman))

    move_to(player, {151, 150})
    move_to(player, {150, 150})

    assert %Group{
             visibility: :party_only,
             state: %{trap: %TrapState{phase: :used}}
           } = Storage.get(trap.group_id)

    refute StatusStorage.has_status?(:player, outside.character.id, :sc_sleep)
    assert eventually_sleeping?(inside.character.id, player, caster, row)
  end

  defp sandman_group(group_id, caster_id, {x, y}, expires_at) do
    %Group{
      group_id: group_id,
      skill_id: 119,
      skill_name: :ht_sandman,
      level: 5,
      caster_id: caster_id,
      caster_type: :player,
      map_name: @map,
      center: {x, y},
      cells: [{x, y}],
      next_tick_at: expires_at,
      expires_at: expires_at,
      interval: 1_000,
      visibility: :party_only,
      state: %{trap: %TrapState{reclaim_item_id: 1065, claymore_spendable?: true}}
    }
  end

  defp eventually_sleeping?(target_id, player, caster, row) do
    Enum.reduce_while(1..8, false, fn _, _acc ->
      if StatusStorage.has_status?(:player, target_id, :sc_sleep) do
        {:halt, true}
      else
        StatusInterpreter.remove_status(:player, player.character.id, :sc_sleep)
        assert :ok = Manager.tick(Manager, System.monotonic_time(:millisecond) + 2_000)
        assert :ok = Executor.execute(caster, row)
        move_to(player, {151, 150})
        move_to(player, {150, 150})
        {:cont, StatusStorage.has_status?(:player, target_id, :sc_sleep)}
      end
    end)
  end

  defp move_to(player, {x, y} = position) do
    simulate_incoming_message(player.pid, %MoveRequest{dest_x: x, dest_y: y})
    assert :ok = wait_for_position(:player, player.character.id, position)
    Process.sleep(200)
  end
end
