defmodule Aesir.ZoneServer.Integration.HunterLandmineEndToEndTest do
  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  import Mimic

  alias Aesir.Commons.Models.Character
  alias Aesir.Net.MoveRequest
  alias Aesir.ZoneServer.Mmo.MobSkill.Executor
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.Skill.Unit.TrapState
  alias Aesir.ZoneServer.Mmo.StatusEffect.Resistance
  alias Aesir.ZoneServer.Mmo.StatusStorage

  @map "prontera"
  @player_id 9_116
  @mob_id 9_216
  @trap {152, 150}

  setup do
    Mimic.copy(Resistance)
    stub(Resistance, :roll_success, fn _effective_rate -> true end)
    :ok
  end

  setup :set_mimic_global

  test "mob Executor places Land Mine through a real MobSession and PlayerSession movement fires it" do
    player =
      start_player_session(character: player_character(), map_name: @map, position: @trap)

    mob = start_mob_session(unit_id: @mob_id, map_name: @map, position: {150, 150})
    caster = %{get_mob_state(mob.pid) | target_id: @player_id}

    assert :ok = Executor.execute(caster, land_protector_row())
    assert Enum.any?(Storage.all(), &(&1.skill_name == :sa_landprotector))

    assert :ok = Executor.execute(caster, landmine_row())

    assert %Group{state: %{ignore_land_protector: true}} =
             mine = Enum.find(Storage.all(), &(&1.skill_name == :ht_landmine))

    initial_hp = get_player_state(player.pid).stats.current_state.hp

    simulate_incoming_message(player.pid, %MoveRequest{dest_x: 153, dest_y: 150})
    assert eventually(fn -> position(player.pid) == {153, 150} end)

    simulate_incoming_message(player.pid, %MoveRequest{dest_x: 152, dest_y: 150})

    assert eventually(fn -> get_player_state(player.pid).stats.current_state.hp < initial_hp end)
    assert StatusStorage.has_status?(:player, @player_id, :sc_stun)

    assert %Group{
             visible?: true,
             expires_at: expires_at,
             state: %{trap: %TrapState{phase: :used}}
           } = Storage.get(mine.group_id)

    remaining = expires_at - System.monotonic_time(:millisecond)
    assert remaining in 1_200..1_500

    assert :ok = Manager.tick(Manager, expires_at)
    assert nil == Storage.get(mine.group_id)
  end

  defp position(pid) do
    state = get_player_state(pid)
    {state.x, state.y}
  end

  defp landmine_row do
    %{skill: "HT_LANDMINE", skill_id: 116, target: :target, level: 1}
  end

  defp land_protector_row do
    %{skill: "SA_LANDPROTECTOR", skill_id: 288, target: :target, level: 5}
  end

  defp player_character do
    %Character{
      id: @player_id,
      account_id: @player_id,
      name: "LandMineTarget",
      char_num: 0,
      class: 0,
      base_level: 50,
      job_level: 1,
      str: 10,
      agi: 10,
      vit: 20,
      int: 10,
      dex: 10,
      luk: 10,
      hp: 5_000,
      max_hp: 5_000,
      sp: 100,
      max_sp: 100,
      last_map: @map,
      last_x: elem(@trap, 0),
      last_y: elem(@trap, 1),
      save_map: @map,
      save_x: 150,
      save_y: 150,
      hair: 1,
      hair_color: 1,
      clothes_color: 0,
      online: true
    }
  end

  defp eventually(fun, attempts \\ 100)
  defp eventually(_fun, 0), do: false

  defp eventually(fun, attempts) do
    if fun.() do
      true
    else
      Process.sleep(25)
      eventually(fun, attempts - 1)
    end
  end
end
