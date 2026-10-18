defmodule Aesir.ZoneServer.Integration.MobLootingIntegrationTest do
  use Aesir.ZoneServer.IntegrationCase

  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.ItemDrop.GroundItemStore
  alias Aesir.ZoneServer.Unit.Mob.MobSession

  @map "mob_looting"
  @moduletag :capture_log

  test "a looter walks to a protected stack and drops it on death with fresh pickup rights" do
    :ets.insert(EtsTable.table_for(:map_cache), {@map, MapData.new(@map, 100, 100)})
    {:ok, coordinator} = start_per_test_map(@map)
    player = start_player_session(map_name: @map, position: {20, 21})
    assert_eventually(fn -> :sys.get_state(coordinator).mobs_awake end)
    now = System.monotonic_time(:millisecond)
    stamp = {{player.character.id, nil, nil}, {now + 60_000, now + 60_000, now + 60_000}}
    Coordinator.drop_items(@map, [{501, 3, 23, 20, true}], 23, 20, ownership: stamp)
    assert_eventually(fn -> length(GroundItemStore.query_in_range(@map, 23, 20, 0)) == 1 end)
    [original] = GroundItemStore.query_in_range(@map, 23, 20, 0)

    mob =
      start_mob_session(
        map_name: @map,
        position: {20, 20},
        modes: [:looter, :can_move, :no_random_walk],
        awake: true
      )

    :sys.replace_state(mob.pid, fn state -> %{state | no_drops: true, no_exp: true} end)

    assert_eventually(fn -> length(get_mob_state(mob.pid).looted_items) == 1 end)
    state = get_mob_state(mob.pid)
    assert {state.x, state.y} == {23, 20}
    assert {:error, :gone} = GroundItemStore.get(@map, original.id)

    MobSession.apply_damage(mob.pid, state.hp, nil)

    assert_eventually(fn -> length(GroundItemStore.query_in_range(@map, 23, 20, 2)) == 1 end)
    [returned] = GroundItemStore.query_in_range(@map, 23, 20, 2)
    assert returned.id != original.id
    assert {returned.nameid, returned.amount, returned.x, returned.y} == {501, 3, 23, 21}
    assert returned.owners != original.owners
  end
end
