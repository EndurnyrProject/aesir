defmodule Aesir.ZoneServer.Unit.KnockbackCancelWalkTest do
  use Aesir.ZoneServer.IntegrationCase

  alias Aesir.Net.Knockback
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.SpatialIndex

  @map_name "prontera"

  test "real player session commits displacement and rejects a stale expected position" do
    player =
      start_player_session(
        id: 7_001,
        map_name: @map_name,
        position: {150, 150}
      )

    flush_packets()

    assert {:ok, {152, 150}} = Combat.knockback(:player, player.character.id, 149, 150, 2)
    assert_eventually(fn -> PlayerSession.get_state(player.pid).game_state.x == 152 end)
    assert_packet_sent(Knockback)

    GenServer.cast(
      player.pid,
      {:movement, {:displace, 150, 150, @map_name, 153, 150}}
    )

    Process.sleep(20)
    state = PlayerSession.get_state(player.pid).game_state
    assert {state.x, state.y, state.movement_state, state.walk_path} == {152, 150, :standing, []}

    flush_packets()
    GenServer.cast(player.pid, {:movement, {:displace, 152, 150, @map_name, -1, -1}})
    Process.sleep(20)
    assert PlayerSession.get_state(player.pid).game_state.x == 152
    refute_packet_sent(Knockback)

    assert {:ok, {152, 150, @map_name}} =
             SpatialIndex.get_unit_position(:player, player.character.id)
  end

  test "real mob session commits and broadcasts after its state and indexes move" do
    observer = start_player_session(id: 7_002, map_name: @map_name, position: {150, 151})
    mob = start_mob_session(unit_id: 9_002, map_name: @map_name, position: {150, 150})
    flush_packets()

    assert {:ok, {152, 150}} = Combat.knockback(:mob, mob.unit_id, 149, 150, 2)
    assert_eventually(fn -> MobSession.get_state(mob.pid).x == 152 end)
    assert {:ok, {152, 150, @map_name}} = SpatialIndex.get_unit_position(:mob, mob.unit_id)
    assert_packet_sent(Knockback)
    assert Process.alive?(observer.pid)
  end

  test "real mob session cancels walking and rejects FIFO damage-before-displacement after death" do
    mob =
      start_mob_session(
        unit_id: 9_001,
        map_name: @map_name,
        position: {150, 150},
        hp: 100,
        max_hp: 100
      )

    assert :ok = MobSession.move_to(mob.pid, 155, 150)
    MobSession.apply_damage(mob.pid, 100)
    assert {:ok, {152, 150}} = Combat.knockback(:mob, mob.unit_id, 149, 150, 2)

    assert_eventually(fn -> MobSession.get_state(mob.pid).is_dead end)
    state = MobSession.get_state(mob.pid)
    assert {state.x, state.y} == {150, 150}
    assert {:ok, {150, 150, @map_name}} = SpatialIndex.get_unit_position(:mob, mob.unit_id)
    refute_packet_sent(Knockback)
  end
end
