defmodule Aesir.ZoneServer.Unit.Mob.HomunculusTargetingTest do
  use Aesir.ZoneServer.IntegrationCase

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.Homunculus
  alias Aesir.Repo
  alias Aesir.ZoneServer.Mmo.Combat.HitCalculations
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup do
    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        userid: "mob_hom_#{System.unique_integer([:positive])}",
        user_pass: "password",
        email: "mob-hom@example.com"
      })
      |> Repo.insert()

    {:ok, character} =
      %Character{}
      |> Character.changeset(%{
        account_id: account.id,
        char_num: 0,
        name: "MobHom#{System.unique_integer([:positive])}",
        class: 5,
        base_level: 50,
        job_level: 50,
        hp: 1_000,
        max_hp: 1_000,
        sp: 500,
        max_sp: 500,
        last_map: "homunculus_targeting_map",
        last_x: 50,
        last_y: 50
      })
      |> Repo.insert()

    {:ok, _homunculus} =
      %Homunculus{}
      |> Homunculus.changeset(%{
        character_id: character.id,
        class_id: 6_001,
        name: "Lif",
        lifecycle: "active",
        level: 1,
        hp: 800,
        max_hp: 800,
        sp: 150,
        max_sp: 150,
        hunger: 32,
        intimacy_hundredths: 2_100,
        active_remaining_ms: 1_800_000
      })
      |> Repo.insert()

    session = start_player_session(character: Repo.preload(character, :homunculus))
    on_exit(fn -> if Process.alive?(session.pid), do: GenServer.stop(session.pid) end)

    %{session: session}
  end

  test "an aggressive mob acquires and attacks a living Homunculus through its owner session", %{
    session: session
  } do
    Mimic.copy(HitCalculations)
    stub(HitCalculations, :calculate_hit_result, fn _attacker, _target -> :hit end)

    state = PlayerSession.get_state(session.pid)
    homunculus = state.homunculus
    SpatialIndex.remove_unit(:player, state.game_state.character_id)
    register_colliding_player(homunculus.world_gid, state.game_state, session.pid, {80, 80})

    mob =
      start_mob_session(
        unit_id: 1_811_001,
        map_name: homunculus.map_name,
        position: {homunculus.x + 1, homunculus.y},
        modes: [:aggressive],
        awake: false
      )

    on_exit(fn -> end_mob_session(mob) end)
    Mimic.allow(HitCalculations, self(), mob.pid)
    :sys.replace_state(mob.pid, &%{&1 | ai_awake: true, spawn_tick_pending?: false})

    hp_before = homunculus.hp
    send(mob.pid, {:ai, :tick})

    assert_eventually(fn ->
      MobSession.get_state(mob.pid).target_ref == {:homunculus, homunculus.world_gid}
    end)

    send(mob.pid, {:ai, :tick})
    send(mob.pid, {:ai, :tick})

    assert_eventually(fn -> PlayerSession.get_state(session.pid).homunculus.hp < hp_before end)
    assert MobSession.get_state(mob.pid).target_ref == {:homunculus, homunculus.world_gid}
    assert PlayerSession.get_state(session.pid).game_state.stats.current_state.hp == 1_000

    UnitRegistry.unregister_unit(:homunculus, homunculus.world_gid)
    send(mob.pid, {:ai, :tick})
    assert_eventually(fn -> MobSession.get_state(mob.pid).target_ref == nil end)
  end

  test "retaliation and damage groundwork retain colliding typed contributors in first-hit order",
       %{
         session: session
       } do
    state = PlayerSession.get_state(session.pid)
    homunculus = state.homunculus
    register_colliding_player(homunculus.world_gid, state.game_state, session.pid, {50, 50})

    mob = start_mob_session(unit_id: 1_811_002, map_name: homunculus.map_name, awake: false)
    on_exit(fn -> end_mob_session(mob) end)

    MobSession.apply_damage(mob.pid, 10, {:homunculus, homunculus.world_gid})
    MobSession.apply_damage(mob.pid, 20, {:player, homunculus.world_gid})
    MobSession.apply_damage(mob.pid, 5, {:homunculus, homunculus.world_gid})
    damaged = MobSession.get_state(mob.pid)

    assert damaged.target_ref == {:player, homunculus.world_gid}

    assert Aesir.ZoneServer.Unit.Mob.MobState.typed_damage_log(damaged) == [
             %{
               contributor: {:homunculus, homunculus.world_gid},
               source_type: :homunculus,
               reward_owner_id: state.game_state.character_id,
               damage: 15,
               first_hit_order: 0
             },
             %{
               contributor: {:player, homunculus.world_gid},
               source_type: :player,
               reward_owner_id: homunculus.world_gid,
               damage: 20,
               first_hit_order: 1
             }
           ]
  end

  test "a real mob skill cast damages the exact Homunculus target", %{session: session} do
    Mimic.copy(HitCalculations)
    stub(HitCalculations, :calculate_hit_result, fn _attacker, _target -> :hit end)

    state = PlayerSession.get_state(session.pid)
    homunculus = state.homunculus
    target_ref = {:homunculus, homunculus.world_gid}

    row = %{
      skill: "NPC_FIREATTACK",
      skill_id: 186,
      level: 1,
      target: :target,
      cast_time: 1,
      delay: 0
    }

    mob =
      start_mob_session(
        unit_id: 1_811_003,
        map_name: homunculus.map_name,
        position: {homunculus.x + 1, homunculus.y},
        awake: false
      )

    on_exit(fn -> end_mob_session(mob) end)
    Mimic.allow(HitCalculations, self(), mob.pid)

    :sys.replace_state(mob.pid, fn mob_state ->
      %{mob_state | target_ref: target_ref, casting: %{row: row, timer_ref: nil}}
    end)

    send(mob.pid, {:casting, :complete})

    assert_eventually(fn ->
      PlayerSession.get_state(session.pid).homunculus.hp < homunculus.hp
    end)

    assert MobSession.get_state(mob.pid).target_ref == target_ref
  end

  defp register_colliding_player(gid, player, pid, {x, y}) do
    UnitRegistry.register_unit(:player, gid, PlayerState, player, pid)
    SpatialIndex.add_unit(:player, gid, x, y, player.map_name)

    on_exit(fn ->
      UnitRegistry.unregister_unit(:player, gid)
      SpatialIndex.remove_unit(:player, gid)
    end)
  end
end
