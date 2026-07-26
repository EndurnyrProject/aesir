defmodule Aesir.ZoneServer.Integration.BlastmineIntegrationTest do
  @moduledoc """
  End-to-end Blast Mine coverage against real player/mob sessions: contact
  detonation and natural-expiry detonation both leave exactly one 1.5-second
  used phase, driven through a deterministic fixed-clock skill-unit manager.
  """

  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Net.MoveRequest
  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Mmo.MobSkill.Executor
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.Skill.Unit.TrapState

  @map "prontera"
  @trap {50, 50}
  @caster_id 1000
  @mob_id 2001

  setup :set_mimic_private
  setup :verify_on_exit!

  setup do
    manager =
      start_supervised!(
        {Manager,
         name: nil, clock: fn -> 10_000 end, schedule_tick: fn _pid, _interval -> :ok end}
      )

    Process.put({Manager, :server}, manager)
    %{manager: manager}
  end

  test "MobSkill.Executor contact detonation damages a real PlayerSession for one used phase", %{
    manager: manager
  } do
    player =
      start_player_session(
        id: @caster_id,
        name: "Blast Contact",
        map_name: @map,
        position: {49, 50},
        hp: 5_000,
        max_hp: 5_000
      )

    mob = start_mob_session(unit_id: @mob_id, map_name: @map, position: @trap, level: 50)
    initial_hp = current_hp(player.pid)

    assert :ok = Executor.execute(MobSession.get_state(mob.pid), blastmine_row())
    assert [%Group{group_id: group_id}] = Storage.get_groups_at_cell(@map, 50, 50)

    simulate_incoming_message(player.pid, %MoveRequest{dest_x: 50, dest_y: 50})

    assert eventually(fn -> current_hp(player.pid) < initial_hp end)

    assert %Group{
             expires_at: 11_500,
             state: %{trap: %TrapState{phase: :used}}
           } = Storage.get(group_id)

    assert :ok = Manager.tick(manager, 11_499)
    assert %Group{} = Storage.get(group_id)
    assert :ok = Manager.tick(manager, 11_500)
    assert nil == Storage.get(group_id)
  end

  test "MobSkill.Executor natural expiry detonates once before one exact used phase", %{
    manager: manager
  } do
    reject(&Coordinator.drop_items/4)

    player =
      start_player_session(
        id: @caster_id,
        name: "Blast Timeout",
        map_name: @map,
        position: {49, 50},
        hp: 5_000,
        max_hp: 5_000
      )

    mob = start_mob_session(unit_id: @mob_id, map_name: @map, position: @trap, level: 50)
    initial_hp = current_hp(player.pid)

    assert :ok = Executor.execute(MobSession.get_state(mob.pid), blastmine_row())
    assert [%Group{} = armed] = Storage.get_groups_at_cell(@map, 50, 50)

    assert :ok = Manager.tick(manager, armed.expires_at)
    assert eventually(fn -> current_hp(player.pid) < initial_hp end)
    hp_after_detonation = current_hp(player.pid)

    assert :ok = Manager.tick(manager, armed.expires_at)
    Process.sleep(25)
    assert current_hp(player.pid) == hp_after_detonation

    assert %Group{
             expires_at: used_until,
             state: %{trap: %TrapState{phase: :used}}
           } = Storage.get(armed.group_id)

    assert used_until == armed.expires_at + 1_500
    assert :ok = Manager.tick(manager, used_until - 1)
    assert %Group{} = Storage.get(armed.group_id)
    assert :ok = Manager.tick(manager, used_until)
    assert nil == Storage.get(armed.group_id)
  end

  defp blastmine_row do
    %{skill: "HT_BLASTMINE", skill_id: 122, target: :around1, level: 3}
  end

  defp current_hp(player_pid) do
    get_player_state(player_pid).stats.current_state.hp
  end

  defp eventually(check, attempts \\ 40)
  defp eventually(_check, 0), do: false

  defp eventually(check, attempts) do
    if check.() do
      true
    else
      Process.sleep(25)
      eventually(check, attempts - 1)
    end
  end
end
