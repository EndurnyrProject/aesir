defmodule Aesir.ZoneServer.Unit.Mob.ComaTest do
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Net.UnitHp
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState

  setup {Aesir.MimicMode, :global}
  setup :verify_on_exit!
  setup :setup_ets_tables

  test "the mob owner applies coma through ordinary damage publication and aggro" do
    pid = start_mob(hp: 500, sp: 50)
    test_pid = self()

    expect(Broadcast, :to_in_range, fn _map, _x, _y, _range, %UnitHp{} = packet ->
      send(test_pid, {:hp_broadcast, packet})
      :ok
    end)

    assert :ok = MobSession.apply_coma(pid, {:player, 42})
    state = MobSession.get_state(pid)

    assert state.hp == 1
    assert state.sp == 1
    refute state.is_dead
    assert MobState.damage_log(state) == [{42, 499}]

    assert MobState.typed_damage_log(state) == [
             %{
               source_type: :player,
               damage: 499,
               reward_owner_id: 42,
               contributor: {:player, 42},
               first_hit_order: 0
             }
           ]

    assert_received {:hp_broadcast, %UnitHp{id: 1, hp: 1, max_hp: 1_000}}
  end

  test "repeated coma is idempotent" do
    pid = start_mob(hp: 1, sp: 1)
    reject(&Broadcast.to_in_range/5)

    assert :ok = MobSession.apply_coma(pid, {:player, 42})
    assert :ok = MobSession.apply_coma(pid, {:player, 42})
    state = MobSession.get_state(pid)

    assert state.hp == 1
    assert state.sp == 1
    assert state.aggro_list == %{}
    assert state.typed_aggro_list == %{}
    assert is_nil(state.last_damage_time)
  end

  test "coma does not alter an HP-zero mob whose death flag is inconsistent" do
    pid = start_mob(hp: 0, sp: 50, is_dead: false)
    before = MobSession.get_state(pid)
    reject(&Broadcast.to_in_range/5)

    assert :ok = MobSession.apply_coma(pid, {:player, 42})
    assert ^before = MobSession.get_state(pid)
  end

  test "coma never revives a dead mob" do
    pid = start_mob(hp: 0, sp: 50, is_dead: true)
    reject(&Broadcast.to_in_range/5)

    assert :ok = MobSession.apply_coma(pid, {:player, 42})
    state = MobSession.get_state(pid)

    assert state.hp == 0
    assert state.sp == 50
    assert state.is_dead
  end

  defp start_mob(opts) do
    state = build_mob_state(opts)
    {:ok, pid} = MobSession.start_link(%{state: state, awake: false})
    on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
    pid
  end

  defp build_mob_state(opts) do
    mob_data = %MobDefinition{
      id: 1001,
      aegis_name: "test_mob",
      name: "Test Mob",
      level: 25,
      hp: 1_000,
      sp: 90,
      stats: %{str: 40, agi: 30, vit: 50, int: 20, dex: 35, luk: 15},
      atk: 50,
      matk: 60,
      def: 25,
      mdef: 10,
      attack_range: 1,
      walk_speed: 200,
      attack_delay: 1_200,
      attack_motion: 500,
      client_attack_motion: 400,
      damage_motion: 300,
      element: {:neutral, 1},
      race: :formless,
      size: :medium
    }

    spawn = %MobSpawn{
      mob: 1001,
      amount: 1,
      respawn_time: 5_000,
      spawn_area: %SpawnArea{x: 100, y: 100}
    }

    state = MobState.new(1, mob_data, spawn, "prontera", 100, 100)

    %{
      state
      | hp: Keyword.fetch!(opts, :hp),
        sp: Keyword.fetch!(opts, :sp),
        is_dead: Keyword.get(opts, :is_dead, false)
    }
  end
end
