defmodule Aesir.ZoneServer.Unit.Homunculus.CombatDeliveryTest do
  use Aesir.ZoneServer.IntegrationCase

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.Homunculus
  alias Aesir.Net.Knockback, as: KnockbackPacket
  alias Aesir.Net.UnitDespawn
  alias Aesir.Net.UnitHp
  alias Aesir.Net.UnitSpawn
  alias Aesir.Repo
  alias Aesir.ZoneServer.Constants.DespawnReason
  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.Combat.AutoAttack
  alias Aesir.ZoneServer.Mmo.Combat.DamageApplication
  alias Aesir.ZoneServer.Mmo.Combat.HitCalculations
  alias Aesir.ZoneServer.Mmo.Combat.Knockback
  alias Aesir.ZoneServer.Mmo.Combat.LineTargets
  alias Aesir.ZoneServer.Mmo.Combat.MagicAttack
  alias Aesir.ZoneServer.Mmo.Combat.MagicDefense
  alias Aesir.ZoneServer.Mmo.Combat.SkillAttack
  alias Aesir.ZoneServer.Mmo.Combat.SplashTargets
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.CommandHandler
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Homunculus.Persistence
  alias Aesir.ZoneServer.Unit.Homunculus.StateCommit
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Resource
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup do
    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        userid: "hom_combat_#{System.unique_integer([:positive])}",
        user_pass: "password",
        email: "hom-combat@example.com"
      })
      |> Repo.insert()

    {:ok, character} =
      %Character{}
      |> Character.changeset(%{
        account_id: account.id,
        char_num: 0,
        name: "HomCombat#{System.unique_integer([:positive])}",
        class: 5,
        base_level: 50,
        job_level: 50,
        hp: 1_000,
        max_hp: 1_000,
        sp: 500,
        max_sp: 500,
        last_map: "hom_combat_map",
        last_x: 50,
        last_y: 50
      })
      |> Repo.insert()

    insert_homunculus(character.id)
    character = Repo.preload(character, :homunculus)
    session = start_player_session(character: character)
    on_exit(fn -> stop_if_alive(session.pid) end)

    state = PlayerSession.get_state(session.pid)

    %{
      account: account,
      character: character,
      session: session,
      gid: state.homunculus.world_gid
    }
  end

  test "typed resolution never confuses a same-ID player with the Homunculus", %{
    session: session,
    gid: gid
  } do
    player = PlayerSession.get_state(session.pid).game_state
    session_pid = session.pid
    UnitRegistry.register_unit(:player, gid, PlayerState, player, session_pid)
    on_exit(fn -> UnitRegistry.unregister_unit(:player, gid) end)

    assert {:ok, ^session_pid, %HomunculusState{world_gid: ^gid}, :homunculus} =
             TargetResolver.resolve({:homunculus, gid})

    assert {:ok, ^session_pid, %PlayerState{}, :player} = TargetResolver.resolve(gid)
  end

  test "real owner-session attack applies same-PID Reflect Shield damage locally", %{
    session: session,
    gid: gid
  } do
    Mimic.copy(HitCalculations)
    stub(HitCalculations, :calculate_hit_result, fn _attacker, _target -> :hit end)
    Mimic.allow(HitCalculations, self(), session.pid)

    homunculus = PlayerSession.get_state(session.pid).homunculus

    mob =
      start_mob_session(
        unit_id: 1_800_010,
        map_name: homunculus.map_name,
        position: {homunculus.x + 1, homunculus.y},
        hp: 5_000,
        max_hp: 5_000,
        awake: false
      )

    on_exit(fn -> end_mob_session(mob) end)

    assert :ok =
             StatusInterpreter.apply_status(:mob, mob.unit_id, :sc_reflectshield, val1: 10)

    mob_hp_before = get_mob_state(mob.pid).hp
    hom_hp_before = homunculus.hp

    GenServer.cast(session.pid, {:homunculus, {:basic_attack, gid, {:mob, mob.unit_id}}})

    assert_eventually(fn -> get_mob_state(mob.pid).hp < mob_hp_before end)
    dealt = mob_hp_before - get_mob_state(mob.pid).hp
    reflected = div(dealt * 40, 100)

    assert_eventually(fn ->
      PlayerSession.get_state(session.pid).homunculus.hp == hom_hp_before - reflected
    end)

    state = PlayerSession.get_state(session.pid)
    assert Process.alive?(session.pid)
    assert state.homunculus.action_state == :idle
    assert state.homunculus.target == nil
    assert {:ok, state.homunculus.hp} == Resource.read({:homunculus, gid}, :hp)

    session_pid = session.pid

    assert {:ok, {HomunculusState, registered, ^session_pid}} =
             UnitRegistry.get_unit(:homunculus, gid)

    assert registered.hp == state.homunculus.hp
  end

  test "local HP potion recovery rounds before the Renewal three-times multiplier", %{
    session: session,
    gid: gid
  } do
    :sys.replace_state(session.pid, fn current ->
      current = StateCommit.commit(current, %{current.homunculus | hp: 100})
      effect = DamageApplication.local_heal_effect({:homunculus, gid}, {:potion, :hp, 101}, nil)
      {:noreply, current} = CommandHandler.local_effect(effect, current)
      current
    end)

    assert PlayerSession.get_state(session.pid).homunculus.hp == 463
  end

  test "Homunculus SP potion recovery is canonical target recovery without HP's multiplier", %{
    session: session,
    gid: gid
  } do
    :sys.replace_state(session.pid, fn current ->
      effect = DamageApplication.local_heal_effect({:homunculus, gid}, {:potion, :sp, 41}, nil)
      {:noreply, current} = CommandHandler.local_effect(effect, current)
      current
    end)

    assert PlayerSession.get_state(session.pid).homunculus.sp == 199
  end

  test "local HP potion recovery clamps to the effective maximum", %{session: session, gid: gid} do
    :sys.replace_state(session.pid, fn current ->
      effect = DamageApplication.local_heal_effect({:homunculus, gid}, {:potion, :hp, 101}, nil)
      {:noreply, current} = CommandHandler.local_effect(effect, current)
      current
    end)

    assert PlayerSession.get_state(session.pid).homunculus.hp == 1_000
  end

  test "external mob damage and typed SP drains arrive asynchronously", %{
    session: session,
    gid: gid
  } do
    target = {:homunculus, gid}

    assert :ok =
             DamageApplication.apply_unit_damage(
               :homunculus,
               session.pid,
               gid,
               40,
               %{},
               {:mob, 2_001}
             )

    assert PlayerSession.get_state(session.pid).homunculus.hp in [760, 800]

    assert_eventually(fn -> PlayerSession.get_state(session.pid).homunculus.hp == 760 end)
    assert {:ok, 150} = Resource.read(target, :sp)
    assert :ok = Resource.drain_sp_percent(target, 20)
    assert_eventually(fn -> PlayerSession.get_state(session.pid).homunculus.sp == 110 end)

    :sys.replace_state(session.pid, fn current ->
      effect = Resource.local_sp_drain_effect(target, 10)
      {:noreply, current} = CommandHandler.local_effect(effect, current)
      current
    end)

    assert PlayerSession.get_state(session.pid).homunculus.sp == 100
  end

  test "skill knockback displaces only the Homunculus through its owner session", %{
    session: session,
    gid: gid
  } do
    :ets.insert(
      EtsTable.table_for(:map_cache),
      {"hom_combat_map", MapData.new("hom_combat_map", 100, 100)}
    )

    before = PlayerSession.get_state(session.pid)
    owner_position = {before.game_state.x, before.game_state.y}
    homunculus = before.homunculus
    destination = {destination_x, destination_y} = {homunculus.x + 2, homunculus.y}

    attacker = PlayerState.to_combatant(before.game_state)
    target = HomunculusState.to_combatant(homunculus)
    result = %{hit?: true, target_survives?: true, coma?: false}

    assert {:ok, ^destination} =
             Knockback.skill(attacker, target, 18, result,
               base_distance: 2,
               origin: {homunculus.x - 1, homunculus.y}
             )

    assert_eventually(fn ->
      current = PlayerSession.get_state(session.pid)
      {current.homunculus.x, current.homunculus.y} == destination
    end)

    current = PlayerSession.get_state(session.pid)
    assert {current.game_state.x, current.game_state.y} == owner_position

    assert {:ok, {destination_x, destination_y, homunculus.map_name}} ==
             SpatialIndex.get_unit_position(:homunculus, gid)

    assert_receive {:packet_sent,
                    %KnockbackPacket{
                      unit_id: ^gid,
                      dst_x: ^destination_x,
                      dst_y: ^destination_y
                    }, :gameplay},
                   500
  end

  test "external coma is applied by the owning player aggregate", %{session: session, gid: gid} do
    assert :ok =
             DamageApplication.apply_unit_damage(
               :homunculus,
               session.pid,
               gid,
               40,
               %{coma?: true},
               {:mob, 2_001}
             )

    assert_eventually(fn ->
      homunculus = PlayerSession.get_state(session.pid).homunculus
      homunculus.hp == 1 and homunculus.sp == 1
    end)

    session_pid = session.pid

    assert {:ok, {HomunculusState, registered, ^session_pid}} =
             UnitRegistry.get_unit(:homunculus, gid)

    assert registered.hp == 1
    assert registered.sp == 1

    assert :ok =
             DamageApplication.apply_unit_damage(
               :homunculus,
               session.pid,
               gid,
               40,
               %{coma?: true},
               {:mob, 2_001}
             )

    assert %{hp: 1, sp: 1} = PlayerSession.get_state(session.pid).homunculus
  end

  test "same-owner coma is applied as an aggregate-local effect", %{session: session, gid: gid} do
    :sys.replace_state(session.pid, fn current ->
      current = StateCommit.commit(current, %{current.homunculus | hp: 800, sp: 150})

      assert {:local_effects, [effect]} =
               DamageApplication.apply_unit_damage(
                 :homunculus,
                 self(),
                 gid,
                 40,
                 %{coma?: true},
                 {:mob, 2_001}
               )

      {:noreply, current} = CommandHandler.local_effect(effect, current)
      current
    end)

    assert %{hp: 1, sp: 1} = PlayerSession.get_state(session.pid).homunculus

    session_pid = session.pid

    assert {:ok, {HomunculusState, %{hp: 1, sp: 1}, ^session_pid}} =
             UnitRegistry.get_unit(:homunculus, gid)
  end

  test "external coma does not alter an active HP-zero Homunculus", %{
    session: session,
    gid: gid
  } do
    session_pid = session.pid

    assert {:ok, {HomunculusState, registered_before, ^session_pid}} =
             UnitRegistry.get_unit(:homunculus, gid)

    :sys.replace_state(session.pid, fn current ->
      %{current | homunculus: %{current.homunculus | hp: 0, sp: 150, action_state: :idle}}
    end)

    before = PlayerSession.get_state(session.pid).homunculus

    assert :ok =
             DamageApplication.apply_unit_damage(
               :homunculus,
               session.pid,
               gid,
               40,
               %{coma?: true},
               {:mob, 2_001}
             )

    assert PlayerSession.get_state(session.pid).homunculus == before

    assert {:ok, {HomunculusState, ^registered_before, ^session_pid}} =
             UnitRegistry.get_unit(:homunculus, gid)
  end

  test "aggregate-local coma does not alter an active HP-zero Homunculus", %{
    session: session,
    gid: gid
  } do
    session_pid = session.pid

    assert {:ok, {HomunculusState, registered_before, ^session_pid}} =
             UnitRegistry.get_unit(:homunculus, gid)

    :sys.replace_state(session.pid, fn current ->
      current = %{
        current
        | homunculus: %{current.homunculus | hp: 0, sp: 150, action_state: :idle}
      }

      assert {:local_effects, [effect]} =
               DamageApplication.apply_unit_damage(
                 :homunculus,
                 self(),
                 gid,
                 40,
                 %{coma?: true},
                 {:mob, 2_001}
               )

      assert {:noreply, ^current} = CommandHandler.local_effect(effect, current)
      current
    end)

    homunculus = PlayerSession.get_state(session.pid).homunculus
    assert %{hp: 0, sp: 150, lifecycle: :active, action_state: :idle} = homunculus

    assert {:ok, {HomunculusState, ^registered_before, ^session_pid}} =
             UnitRegistry.get_unit(:homunculus, gid)
  end

  test "Homunculus attack, skill, and magic paths retain typed source and target identity", %{
    session: session,
    gid: gid
  } do
    homunculus = PlayerSession.get_state(session.pid).homunculus
    mob = mob(1_800_001, homunculus.x + 1, homunculus.y, homunculus.map_name)
    register_mob(mob)

    assert :ok = AutoAttack.execute_homunculus_attack(homunculus, {:mob, mob.instance_id})

    assert :ok =
             SkillAttack.execute_skill_attack(homunculus, {:mob, mob.instance_id},
               skill_id: 8_001,
               skill_level: 1,
               fixed_damage: 25,
               ignore_flee: true
             )

    assert {:ok, {:mob, mob.instance_id}} ==
             MagicAttack.execute_magic_damage(homunculus, {:mob, mob.instance_id}, 30,
               skill_id: 8_004,
               skill_level: 1,
               skip_range: true
             )

    assert_receive {:"$gen_cast", {:combat, {:apply_damage, _damage, {:homunculus, ^gid}}}}
    assert_receive {:"$gen_cast", {:combat, {:apply_damage, _damage, {:homunculus, ^gid}}}}
  end

  test "a reflected Homunculus bolt lands on the Homunculus through its owner session", %{
    session: session,
    gid: gid
  } do
    Mimic.copy(MagicDefense)
    stub(MagicDefense, :resolve, fn _defender, _hit_info -> :reflect end)

    homunculus = PlayerSession.get_state(session.pid).homunculus
    mob = mob(1_800_003, homunculus.x + 1, homunculus.y, homunculus.map_name)
    register_mob(mob)

    assert {:ok, {:homunculus, gid}} ==
             MagicAttack.execute_magic_damage(homunculus, {:mob, mob.instance_id}, 30,
               skill_id: 8_004,
               skill_level: 1,
               skip_range: true
             )

    refute_receive {:"$gen_cast", {:combat, {:apply_damage, _damage, _attacker}}}
    assert_eventually(fn -> PlayerSession.get_state(session.pid).homunculus.hp == 770 end)
  end

  test "splash, line, and skill-unit delivery include the typed Homunculus", %{
    session: session,
    gid: gid
  } do
    homunculus = PlayerSession.get_state(session.pid).homunculus
    caster_state = mob(1_800_002, homunculus.x - 1, homunculus.y, homunculus.map_name)
    caster = MobState.to_combatant(caster_state)

    assert {:homunculus, gid} in SplashTargets.select(
             homunculus.map_name,
             {homunculus.x, homunculus.y},
             1,
             caster
           )

    assert {:homunculus, gid} in LineTargets.select(
             homunculus.map_name,
             caster.position,
             {homunculus.x, homunculus.y},
             caster
           )

    assert :ok =
             MagicAttack.apply_skill_unit_damage(
               caster,
               :homunculus,
               gid,
               89,
               1,
               :neutral,
               100,
               fixed_damage: 35
             )

    assert_eventually(fn -> PlayerSession.get_state(session.pid).homunculus.hp == 765 end)
  end

  test "observer death delivery clears its ledger and permits a reused GID spawn", %{
    account: account,
    session: owner,
    gid: gid
  } do
    observer_character =
      %Character{}
      |> Character.changeset(%{
        account_id: account.id,
        char_num: 1,
        name: "HomObserver#{System.unique_integer([:positive])}",
        class: 0,
        base_level: 20,
        job_level: 10,
        hp: 500,
        max_hp: 500,
        sp: 100,
        max_sp: 100,
        last_map: "hom_combat_map",
        last_x: 51,
        last_y: 50
      })
      |> Repo.insert!()
      |> Repo.preload(:homunculus)

    test_pid = self()
    observer_connection = spawn_link(fn -> observer_connection_loop(test_pid) end)

    observer =
      start_player_session(
        character: observer_character,
        connection_pid: observer_connection,
        map_name: "hom_combat_map",
        position: {51, 50}
      )

    on_exit(fn ->
      stop_if_alive(observer.pid)
      send(observer_connection, :stop)
    end)

    PlayerSession.notify_homunculus_entered_view(observer.pid, gid)

    assert_eventually(fn ->
      PlayerSession.get_state(observer.pid).game_state.visible_homunculi == MapSet.new([gid])
    end)

    assert_receive {:observer_packet, %UnitSpawn{gid: ^gid}}, 500
    active = PlayerSession.get_state(owner.pid).homunculus

    assert :ok =
             DamageApplication.apply_unit_damage(
               :homunculus,
               owner.pid,
               gid,
               2_000,
               %{},
               {:mob, 2_001}
             )

    assert_receive {:observer_packet, %UnitDespawn{gid: ^gid, reason: reason}}, 500
    assert reason == DespawnReason.died()

    assert_eventually(fn ->
      PlayerSession.get_state(observer.pid).game_state.visible_homunculi == MapSet.new()
    end)

    observer_pid = observer.pid

    assert {:ok, {PlayerState, published, ^observer_pid}} =
             UnitRegistry.get_unit(:player, observer_character.id)

    assert published.visible_homunculi == MapSet.new()
    refute_receive {:observer_packet, %UnitDespawn{gid: ^gid}}, 50

    reused = %{active | hp: active.max_hp, lifecycle: :active}
    UnitRegistry.register_unit(:homunculus, gid, HomunculusState, reused, owner.pid)
    SpatialIndex.add_unit(:homunculus, gid, reused.x, reused.y, reused.map_name)

    PlayerSession.notify_homunculus_entered_view(observer.pid, gid)
    assert_receive {:observer_packet, %UnitSpawn{gid: ^gid}}, 500

    assert_eventually(fn ->
      PlayerSession.get_state(observer.pid).game_state.visible_homunculi == MapSet.new([gid])
    end)

    SpatialIndex.remove_unit(:homunculus, gid)
    UnitRegistry.unregister_unit(:homunculus, gid)
  end

  test "lethal damage persists before clearing presence and emits no reward path", %{
    character: character,
    session: session,
    gid: gid
  } do
    assert :ok =
             DamageApplication.apply_unit_damage(
               :homunculus,
               session.pid,
               gid,
               2_000,
               %{},
               {:mob, 2_001}
             )

    assert_eventually(fn ->
      PlayerSession.get_state(session.pid).homunculus.lifecycle == :dead
    end)

    state = PlayerSession.get_state(session.pid)
    assert state.homunculus.hp == 0
    assert is_nil(state.homunculus.world_gid)
    assert is_nil(state.homunculus_runtime.active_expiry_timer_ref)
    assert is_nil(state.homunculus_runtime.hunger_timer_ref)
    assert {:error, :not_found} = UnitRegistry.get_unit(:homunculus, gid)

    dead = state.homunculus
    GenServer.cast(session.pid, {:homunculus, {:apply_coma, gid, {:mob, 2_001}}})
    assert PlayerSession.get_state(session.pid).homunculus == dead

    row = Persistence.load_for_character(character.id)
    assert row.lifecycle == "dead"
    assert row.hp == 0
    assert row.active_remaining_ms == 0

    assert_receive {:packet_sent, %UnitHp{id: ^gid, hp: 0}, :world}, 500

    assert_receive {:packet_sent, %UnitDespawn{gid: ^gid, reason: reason}, :world},
                   500

    assert reason == DespawnReason.died()

    source = File.read!("lib/aesir/zone_server/unit/homunculus/handlers/combat_handler.ex")
    refute source =~ "KillExp"
    refute source =~ "ItemDrop"
    refute source =~ "Coordinator.mob_died"
  end

  defp insert_homunculus(character_id) do
    %Homunculus{}
    |> Homunculus.changeset(%{
      character_id: character_id,
      class_id: 6_001,
      name: "Hildr",
      lifecycle: "active",
      level: 50,
      hp: 800,
      max_hp: 1_000,
      sp: 150,
      max_sp: 200,
      str: 10,
      agi: 10,
      vit: 10,
      int: 10,
      dex: 10,
      luk: 10,
      active_remaining_ms: 1_800_000,
      learned_skills: %{"8001" => 1},
      cooldowns: %{},
      ai_config: %{}
    })
    |> Repo.insert!()
  end

  defp mob(id, x, y, map_name) do
    MobState.new(
      id,
      %MobDefinition{
        id: 1_001,
        aegis_name: "TEST_MOB",
        name: "Test Mob",
        level: 25,
        hp: 1_000,
        sp: 100,
        stats: %{str: 40, agi: 10, vit: 20, int: 20, dex: 100, luk: 10},
        atk: 50,
        matk: 60,
        def: 10,
        mdef: 10,
        attack_range: 1,
        walk_speed: 200,
        attack_delay: 1_000,
        attack_motion: 500,
        client_attack_motion: 400,
        damage_motion: 300,
        element: {:neutral, 1},
        race: :formless,
        size: :medium
      },
      %MobSpawn{
        mob: 1_001,
        amount: 1,
        respawn_time: 5_000,
        spawn_area: %MobSpawn.SpawnArea{x: x, y: y}
      },
      map_name,
      x,
      y
    )
  end

  defp register_mob(%MobState{} = mob) do
    UnitRegistry.register_unit(:mob, mob.instance_id, MobState, mob, self())
    SpatialIndex.add_unit(:mob, mob.instance_id, mob.x, mob.y, mob.map_name)

    on_exit(fn ->
      SpatialIndex.remove_unit(:mob, mob.instance_id)
      UnitRegistry.unregister_unit(:mob, mob.instance_id)
    end)
  end

  defp observer_connection_loop(test_pid) do
    receive do
      :stop ->
        :ok

      {:send, _channel, {_tag, packet}} ->
        send(test_pid, {:observer_packet, packet})
        observer_connection_loop(test_pid)

      _message ->
        observer_connection_loop(test_pid)
    end
  end

  defp stop_if_alive(pid) do
    if Process.alive?(pid) do
      Process.unlink(pid)
      Process.exit(pid, :kill)
    end
  end
end
