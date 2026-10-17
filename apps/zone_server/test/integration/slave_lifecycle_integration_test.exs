defmodule Aesir.ZoneServer.Integration.SlaveLifecycleIntegrationTest do
  use Aesir.ZoneServer.IntegrationCase

  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.Slaves
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @map "slave_lifecycle"
  @moduletag :capture_log

  setup do
    :ets.insert(EtsTable.table_for(:map_cache), {@map, MapData.new(@map, 100, 100)})
    {:ok, coordinator} = start_per_test_map(@map)
    %{coordinator: coordinator}
  end

  test "real summoned slaves follow, share targets, warp and die with their master", %{
    coordinator: coordinator
  } do
    target =
      start_player_session(map_name: @map, position: {20, 21}, hp: 100_000, max_hp: 100_000)

    assert_eventually(fn -> :sys.get_state(coordinator).mobs_awake end)

    master =
      start_mob_session(map_name: @map, position: {20, 20}, modes: [:can_move, :can_attack])

    row = %{
      skill: "NPC_SUMMONSLAVE",
      skill_id: 196,
      state: :idle,
      level: 2,
      rate: 10_000,
      cast_time: 0,
      delay: 0,
      cancelable: false,
      target: :self,
      condition: %{
        type: :always,
        value: 0,
        val1: 1002,
        val2: nil,
        val3: nil,
        val4: nil,
        val5: nil
      },
      emotion: nil
    }

    :sys.replace_state(master.pid, fn state ->
      %{state | casting: %{row: row, complete_at: 0, timer_ref: nil}}
    end)

    send(master.pid, {:casting, :complete})
    assert_eventually(fn -> length(Slaves.linked(get_mob_state(master.pid))) == 2 end)
    slaves = Slaves.linked(get_mob_state(master.pid))
    assert get_mob_state(master.pid).can_summon
    [{slave, slave_pid} | _] = slaves
    assert slave.base_walk_speed == get_mob_state(master.pid).base_walk_speed
    assert Enum.sort(slave.mob_data.modes) == Enum.sort([:can_move, :can_attack, :no_random_walk])

    MobSession.warp(slave_pid, @map, 30, 20)
    assert_eventually(fn -> get_mob_state(slave_pid).movement_state == :moving end)

    assert_eventually(fn ->
      current = get_mob_state(slave_pid)
      Geometry.chebyshev_distance(current.x, current.y, 20, 20) <= 2
    end)

    MobSession.set_target(master.pid, {:player, target.character.id})

    assert_eventually(fn ->
      get_mob_state(slave_pid).target_ref == {:player, target.character.id}
    end)

    MobSession.warp(master.pid, @map, 60, 60)

    assert_eventually(fn ->
      Enum.all?(slaves, fn {_state, pid} ->
        current = get_mob_state(pid)
        Geometry.chebyshev_distance(current.x, current.y, 60, 60) <= 2
      end)
    end)

    MobSession.apply_damage(master.pid, get_mob_state(master.pid).hp, nil)

    assert_eventually(fn ->
      Enum.all?(slaves, fn {state, _pid} ->
        case UnitRegistry.get_unit(:mob, state.instance_id) do
          {:ok, {_, current, _}} -> current.is_dead
          {:error, :not_found} -> true
        end
      end)
    end)
  end
end
