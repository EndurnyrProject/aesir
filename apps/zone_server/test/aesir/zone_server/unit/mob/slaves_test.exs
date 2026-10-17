defmodule Aesir.ZoneServer.Unit.Mob.SlavesTest do
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Net.SkillCasting
  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.MobManagement.Mobs
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.PlayerStateFixture
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.AIStateMachine
  alias Aesir.ZoneServer.Unit.Mob.Handlers.AiHandler
  alias Aesir.ZoneServer.Unit.Mob.Handlers.CastingHandler
  alias Aesir.ZoneServer.Unit.Mob.Handlers.CombatHandler
  alias Aesir.ZoneServer.Unit.Mob.Handlers.MovementHandler
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Mob.Slaves
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.Stats.CombatStats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @map "slave_test"
  setup :setup_ets_tables
  setup :set_mimic_private

  setup do
    :ets.insert(EtsTable.table_for(:map_cache), {@map, MapData.new(@map, 50, 50)})
    :ok
  end

  test "a slave without a target returns to a random nearby master cell, not the master itself" do
    master = mob(1, 20, 20)
    register(master)
    slave = %{mob(2, 26, 20) | master_id: 1}
    register(slave)

    assert {:halt, walking} = Slaves.process(slave, 1_000)
    assert walking.movement_state == :moving
    assert {x, y} = List.last(walking.walk_path)
    assert Geometry.chebyshev_distance(x, y, 20, 20) <= 2
    refute {x, y} == {20, 20}
  end

  test "a nearby idle slave adopts its master's target at most once per second" do
    master = %{mob(1, 20, 20) | target_ref: {:player, 10}, attack_target: {:player, 10}}
    register(master)

    player =
      PlayerStateFixture.build(%{
        character_id: 10,
        map_name: @map,
        x: 25,
        y: 20,
        stats: %{combat_stats: %CombatStats{}}
      })

    UnitRegistry.register_unit(:player, 10, PlayerState, player, self())
    SpatialIndex.add_unit(:player, 10, 25, 20, @map)
    slave = %{mob(2, 22, 20) | master_id: 1}

    assert {:cont, waiting} = Slaves.process(slave, 500)
    assert waiting.target_ref == nil
    assert {:halt, adopted} = Slaves.process(waiting, 1_000)
    assert adopted.target_ref == {:player, 10}
    assert adopted.last_linktime == 1_000

    idle_again = %{adopted | target_ref: nil}
    assert {:cont, waiting} = Slaves.process(idle_again, 1_999)
    assert waiting.target_ref == nil
  end

  test "a busy slave keeps its target instead of returning or teleporting to a distant master" do
    register(mob(1, 20, 20))
    slave = %{mob(2, 40, 20) | master_id: 1, target_ref: {:player, 10}}
    assert {:cont, kept} = Slaves.process(slave, 1_000)
    assert kept.target_ref == {:player, 10}
    assert {kept.x, kept.y} == {40, 20}
  end

  test "a missing or dead master kills its slave, but a master between map removals does not" do
    stub(Coordinator, :mob_died, fn @map, _, nil -> :ok end)
    slave = %{mob(2, 22, 20) | master_id: 1}
    assert {:halt, dead} = Slaves.process(slave, 1_000)
    assert dead.is_dead
    assert dead.hp == 0

    master = mob(1, 20, 20)
    UnitRegistry.register_unit(:mob, 1, MobState, master, self())
    assert {:cont, ^slave} = Slaves.process(slave, 1_000)

    register(%{master | hp: 0, is_dead: true})
    assert {:halt, dead} = Slaves.process(slave, 1_000)
    assert dead.is_dead
  end

  test "recall and master death dispatch only to this master's living same-map slaves" do
    master = mob(1, 20, 20)
    register(master)
    register(%{mob(2, 25, 20) | master_id: 1})
    register(%{mob(3, 25, 20) | master_id: 9})
    register(%{mob(4, 25, 20) | master_id: 1, map_name: "elsewhere"})
    register(%{mob(5, 25, 20) | master_id: 1, is_dead: true, hp: 0})

    assert :ok = Slaves.recall(master)
    assert_received {:"$gen_cast", {:movement, {:warp, @map, x, y}}}
    assert Geometry.chebyshev_distance(x, y, 20, 20) <= 2
    refute_received {:"$gen_cast", {:movement, {:warp, _, _, _}}}

    assert :ok = Slaves.master_died(%{master | can_summon: true})
    assert_received {:"$gen_cast", {:combat, {:master_dead, 1}}}
    refute_received {:"$gen_cast", {:combat, {:master_dead, _}}}
  end

  test "master target commands publish the snapshot that followers read" do
    master = mob(1, 20, 20)
    register(master)

    player =
      PlayerStateFixture.build(%{
        character_id: 10,
        map_name: @map,
        x: 25,
        y: 20,
        stats: %{combat_stats: %CombatStats{}}
      })

    UnitRegistry.register_unit(:player, 10, PlayerState, player, self())
    SpatialIndex.add_unit(:player, 10, 25, 20, @map)

    assert {:noreply, %{target_ref: {:player, 10}}} =
             AiHandler.handle_set_target(master, {:player, 10})

    assert {:ok, {_, %{target_ref: {:player, 10}}, _}} = UnitRegistry.get_unit(:mob, 1)
  end

  test "the hard AI runs the slave step before normal idle behavior" do
    register(mob(1, 20, 20))
    slave = %{mob(2, 26, 20) | master_id: 1}
    register(slave)
    assert AIStateMachine.process_ai(slave, 1_000).movement_state == :moving
  end

  test "a master warp recalls its existing slaves after landing" do
    master = mob(1, 20, 20)
    register(master)
    register(%{mob(2, 22, 20) | master_id: 1})
    warped = MovementHandler.warp_to(master, 30, 30)
    assert {warped.x, warped.y} == {30, 30}
    assert_received {:"$gen_cast", {:movement, {:warp, @map, x, y}}}
    assert Geometry.chebyshev_distance(x, y, 30, 30) <= 2
  end

  test "the master's real death path dispatches slave death before its coordinator removal" do
    stub(Coordinator, :mob_died, fn @map, _, nil -> :ok end)
    master = %{mob(1, 20, 20) | can_summon: true}
    register(master)
    register(%{mob(2, 22, 20) | master_id: 1})

    assert {:noreply, dead} =
             CombatHandler.handle_apply_damage(master.hp, nil, %{passive?: true}, master)

    assert dead.is_dead
    assert_received {:"$gen_cast", {:combat, {:master_dead, 1}}}
  end

  test "a unit cast and its followers keep the chosen target when the master's AI intent changes" do
    master = %{mob(1, 20, 20) | target_ref: {:player, 10}}
    register(master)
    register_player(10)
    test_pid = self()

    stub(Broadcast, :to_in_range, fn _, _, _, _, packet ->
      send(test_pid, {:cast_packet, packet})
      :ok
    end)

    row = %{
      skill: "MG_FIREBOLT",
      skill_id: 19,
      level: 1,
      cast_time: 60_000,
      delay: 1_000,
      target: :randomtarget,
      cancelable: false,
      emotion: nil
    }

    assert {:ok, casting} = CastingHandler.begin_cast(master, row, 1_000)
    assert_received {:cast_packet, %SkillCasting{target_id: 10, skill_id: 19}}
    register_player(11)
    assert {:noreply, changed} = AiHandler.handle_set_target(casting, {:player, 11})
    slave = %{mob(2, 22, 20) | master_id: 1}
    assert {:halt, inherited} = Slaves.process(slave, 2_000)
    assert inherited.target_ref == {:player, 10}

    Process.cancel_timer(casting.casting.timer_ref)
    expect(Combat, :execute_magic_attack, fn _, 10, _ -> {:ok, {:player, 10}} end)
    assert {:noreply, completed} = CastingHandler.handle_cast_complete(changed)
    assert completed.casting == nil
    Process.cancel_timer(completed.ai_timer_ref)

    UnitRegistry.unregister_unit(:player, 10)
    reject(&Combat.execute_magic_attack/3)
    assert {:noreply, aborted} = CastingHandler.handle_cast_complete(changed)
    assert aborted.casting == nil
    Process.cancel_timer(aborted.ai_timer_ref)
  end

  test "a ground cast has no unit skill target, so a follower may use the master's AI target" do
    master = %{mob(1, 20, 20) | target_ref: {:player, 10}}
    register(master)
    register_player(10)

    row = %{
      skill: "WZ_STORMGUST",
      skill_id: 89,
      level: 1,
      cast_time: 60_000,
      delay: 1_000,
      target: :self,
      cancelable: false,
      emotion: nil
    }

    assert {:ok, casting} = CastingHandler.begin_cast(master, row, 1_000)
    slave = %{mob(2, 22, 20) | master_id: 1}
    assert {:halt, inherited} = Slaves.process(slave, 2_000)
    assert inherited.target_ref == {:player, 10}
    Process.cancel_timer(casting.casting.timer_ref)
  end

  defp register_player(id) do
    player =
      PlayerStateFixture.build(%{
        character_id: id,
        map_name: @map,
        x: 25,
        y: 20,
        stats: %{combat_stats: %CombatStats{}}
      })

    UnitRegistry.register_unit(:player, id, PlayerState, player, self())
    SpatialIndex.add_unit(:player, id, 25, 20, @map)
  end

  defp mob(id, x, y) do
    {:ok, data} = Mobs.by_id(1002)
    data = %{data | modes: [:can_move, :can_attack, :no_random_walk]}
    spawn = %MobSpawn{mob: 1002, amount: 1, respawn_time: 0, spawn_area: %SpawnArea{x: x, y: y}}
    MobState.new(id, data, spawn, @map, x, y)
  end

  defp register(mob) do
    UnitRegistry.register_unit(:mob, mob.instance_id, MobState, mob, self())
    SpatialIndex.add_unit(:mob, mob.instance_id, mob.x, mob.y, mob.map_name)
  end
end
