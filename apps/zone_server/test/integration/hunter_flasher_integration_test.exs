defmodule Aesir.ZoneServer.Integration.HunterFlasherIntegrationTest do
  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Commons.Models.Character
  alias Aesir.Net.MoveRequest
  alias Aesir.ZoneServer.Mmo.MobSkill.Executor
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.Skill.Unit.TrapState
  alias Aesir.ZoneServer.Mmo.StatusStorage

  @map "prontera"
  @mob_id 91_201
  @player_id 91_202
  @trap_cell {152, 150}

  test "mob Flasher placement blinds a player through movement contact and becomes inert" do
    player =
      start_player_session(
        character: player_character(),
        map_name: @map,
        position: {151, 150}
      )

    mob = start_mob_session(unit_id: @mob_id, map_name: @map, position: @trap_cell)

    assert :ok = Executor.execute(get_mob_state(mob.pid), flasher_row())

    assert [
             %Group{
               group_id: group_id,
               visible?: false,
               state: %{trap: %TrapState{phase: :armed}}
             }
           ] =
             Storage.get_groups_at_cell(@map, 152, 150)

    walk(player.pid, @trap_cell)

    assert eventually(fn -> StatusStorage.has_status?(:player, @player_id, :sc_blind) end)

    blind = StatusStorage.get_status(:player, @player_id, :sc_blind)
    assert blind.source_id == @mob_id
    assert blind.source_type == :mob
    assert_in_delta blind.expires_at - blind.started_at, 18_000, 100

    assert %Group{
             visible?: true,
             expires_at: used_expires_at,
             state: %{trap: %TrapState{phase: :used}}
           } = Storage.get(group_id)

    assert_in_delta used_expires_at - System.monotonic_time(:millisecond), 1_500, 200

    walk(player.pid, {151, 150})
    walk(player.pid, @trap_cell)

    assert StatusStorage.get_status(:player, @player_id, :sc_blind).started_at == blind.started_at

    assert :ok = Manager.tick(Manager, used_expires_at - 1)
    assert %Group{} = Storage.get(group_id)
    assert :ok = Manager.tick(Manager, used_expires_at)
    assert nil == Storage.get(group_id)
  end

  defp flasher_row do
    %{skill: "HT_FLASHER", skill_id: 120, target: :self, level: 3}
  end

  defp walk(pid, {x, y}) do
    simulate_incoming_message(pid, %MoveRequest{dest_x: x, dest_y: y})

    assert eventually(fn ->
             send(pid, {:movement, :movement_tick})
             state = get_player_state(pid)
             {state.x, state.y} == {x, y}
           end)
  end

  defp player_character do
    %Character{
      id: @player_id,
      account_id: @player_id,
      name: "FlasherTarget",
      char_num: 0,
      class: 0,
      base_level: 40,
      job_level: 1,
      str: 20,
      agi: 20,
      vit: 0,
      int: 0,
      dex: 20,
      luk: 0,
      hp: 5_000,
      max_hp: 5_000,
      sp: 50,
      max_sp: 50,
      last_map: @map,
      last_x: 151,
      last_y: 150,
      save_map: @map,
      save_x: 151,
      save_y: 150,
      hair: 1,
      hair_color: 1,
      clothes_color: 0,
      online: true
    }
  end

  defp eventually(fun, attempts \\ 40) do
    cond do
      fun.() -> true
      attempts == 0 -> false
      true -> Process.sleep(25) && eventually(fun, attempts - 1)
    end
  end
end
