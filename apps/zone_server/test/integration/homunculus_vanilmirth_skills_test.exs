defmodule Aesir.ZoneServer.Integration.HomunculusVanilmirthSkillsTest do
  use Aesir.ZoneServer.IntegrationCase

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.Homunculus
  alias Aesir.Repo
  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.Combat.MagicAttack
  alias Aesir.ZoneServer.Mmo.Homunculus.Ai.Config
  alias Aesir.ZoneServer.Mmo.Homunculus.SkillTree
  alias Aesir.ZoneServer.Mmo.Homunculus.Stats, as: HomunculusStats
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.Skill.Unit.TrapState
  alias Aesir.ZoneServer.Mmo.Skills.Homunculus.HvanCaprice
  alias Aesir.ZoneServer.Mmo.Skills.Homunculus.HvanChaotic
  alias Aesir.ZoneServer.Mmo.Skills.Homunculus.HvanExplosion
  alias Aesir.ZoneServer.Unit.Homunculus.Clock
  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.AiHandler
  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.CastingHandler
  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.CombatHandler
  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.CommandHandler
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Homunculus.Persistence, as: HomunculusPersistence
  alias Aesir.ZoneServer.Unit.Homunculus.Runtime
  alias Aesir.ZoneServer.Unit.Homunculus.StateCommit
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState

  setup do
    Mimic.copy(MagicAttack)
    Mimic.copy(MobSession)
    Mimic.copy(HomunculusPersistence)
    Mimic.copy(StateCommit)

    :ets.insert(
      EtsTable.table_for(:map_cache),
      {"vanilmirth_skills_map", MapData.new("vanilmirth_skills_map", 100, 100)}
    )

    :ok = Catalog.reload()

    on_exit(fn -> Catalog.reload() end)
  end

  test "Vanilmirth skill tree publishes exact ranks, prerequisites, evolution, and intimacy gates" do
    assert {:ok, caprice} = SkillTree.entry(6_004, 8_013)
    assert {caprice.max_level, caprice.form, caprice.requires} == {5, :any, []}

    assert {:ok, chaotic} = SkillTree.entry(6_004, 8_014)

    assert {chaotic.max_level, chaotic.form, chaotic.requires} ==
             {5, :any, [%{skill_id: 8_013, level: 3}]}

    assert {:ok, instruct} = SkillTree.entry(6_004, 8_015)

    assert {instruct.max_level, instruct.form, instruct.requires} ==
             {5, :any, [%{skill_id: 8_013, level: 5}]}

    assert {:ok, explosion} = SkillTree.entry(6_012, 8_016)
    assert explosion.max_level == 3
    assert explosion.form == :evolved
    assert explosion.required_intimacy == 91_000
    assert explosion.requires == []
  end

  test "Caprice publishes the exact Renewal definition" do
    assert {:ok, definition} = Catalog.by_id(8_013)
    assert definition.name == :hvan_caprice
    assert definition.max_level == 5
    assert definition.target_type == :target_enemy
    assert definition.damage_type == :damage
    assert definition.damage_kind == :magic
    assert definition.range == 9
    assert definition.sp_cost == [22, 24, 26, 28, 30]
    assert definition.cooldown == [2_000, 2_200, 2_400, 2_600, 2_800]
  end

  test "Caprice uniformly maps all four deterministic branches to the selected bolt id" do
    caster = vanilmirth()

    for {bolt_id, roll} <- Enum.with_index([14, 19, 20, 90], 1) do
      seed_rolls([{4, roll}])

      expect(MagicAttack, :execute_bolt, fn ^caster, {:mob, 7_001}, ^bolt_id, 5, [] ->
        {:ok, {:mob, 7_001}}
      end)

      assert {:ok, ^caster} =
               HvanCaprice.cast(caster, {:unit, {:mob, 7_001}}, 5, HvanCaprice.definition())
    end
  end

  test "Benediction of Chaos publishes the exact non-damaging self definition" do
    assert {:ok, definition} = Catalog.by_id(8_014)
    assert definition.name == :hvan_chaotic
    assert definition.max_level == 5
    assert definition.target_type == :self
    assert definition.damage_type == :no_damage
    assert definition.sp_cost == List.duplicate(40, 5)
    assert definition.cooldown == List.duplicate(3_000, 5)
    assert definition.after_cast_delay == []
  end

  test "Benediction independently rolls heal rank and uses the exact formula at ranks 1, 3, and 5" do
    caster = vanilmirth()

    for {cast_rank, recipient_roll} <- [{1, 21}, {3, 26}, {5, 35}] do
      seed_rolls([{100, recipient_roll}, {cast_rank, cast_rank}])
      expected = 60 * cast_rank + 7

      assert {:local_effects, ^caster,
              [{:player, {:apply_heal, ^expected, {:homunculus, 1_500_001}}}]} =
               HvanChaotic.cast(caster, :self, cast_rank, HvanChaotic.definition())
    end
  end

  test "Benediction honors every rank threshold edge and falls back to Vanilmirth without an attacker" do
    caster = vanilmirth()

    for {level, hom_threshold, owner_threshold} <- [
          {1, 20, 50},
          {2, 50, 60},
          {3, 25, 75},
          {4, 50, 54},
          {5, 34, 67}
        ] do
      seed_rolls([{100, hom_threshold}, {level, 1}])

      assert {:local_effects, ^caster,
              [{:homunculus, {:apply_heal, 1_500_001, 67, {:homunculus, 1_500_001}}}]} =
               HvanChaotic.cast(caster, :self, level, HvanChaotic.definition())

      seed_rolls([{100, hom_threshold + 1}, {level, 1}])

      assert {:local_effects, ^caster, [{:player, {:apply_heal, 67, {:homunculus, 1_500_001}}}]} =
               HvanChaotic.cast(caster, :self, level, HvanChaotic.definition())

      seed_rolls([{100, owner_threshold + 1}, {level, 1}])

      assert {:local_effects, ^caster,
              [{:homunculus, {:apply_heal, 1_500_001, 67, {:homunculus, 1_500_001}}}]} =
               HvanChaotic.cast(caster, :self, level, HvanChaotic.definition())
    end
  end

  test "Benediction centers on the owner and reads a real mob's current target" do
    owner = %PlayerState{character_id: 100, map_name: "vanilmirth_skills_map", x: 20, y: 20}
    :ok = UnitRegistry.register_unit(:player, 100, PlayerState, owner, self())
    :ok = SpatialIndex.add_unit(:player, 100, 20, 20, owner.map_name)

    caster = %{vanilmirth() | x: 10, y: 10}

    mob =
      start_mob_session(
        unit_id: 7_002,
        map_name: owner.map_name,
        position: {34, 20},
        max_hp: 5_000,
        hp: 4_000
      )

    on_exit(fn -> end_mob_session(mob) end)
    :ok = MobSession.set_target(mob.pid, {:player, 100})
    assert_eventually(fn -> get_mob_state(mob.pid).target_ref == {:player, 100} end)
    seed_rolls([{100, 100}, {1, 1}, {5, 1}])

    assert {:local_effects, ^caster, [{:mob, {:apply_heal, 7_002, 67, {:homunculus, 1_500_001}}}]} =
             HvanChaotic.cast(caster, :self, 5, HvanChaotic.definition())

    :ok = MobSession.set_target(mob.pid, {:player, 999})
    assert_eventually(fn -> get_mob_state(mob.pid).target_ref == {:player, 999} end)
    seed_rolls([{100, 100}, {5, 1}])

    assert {:local_effects, ^caster,
            [{:homunculus, {:apply_heal, 1_500_001, 67, {:homunculus, 1_500_001}}}]} =
             HvanChaotic.cast(caster, :self, 5, HvanChaotic.definition())
  end

  test "Benediction bounds all unresponsive attacker reads to one scan budget" do
    owner = %PlayerState{character_id: 100, map_name: "vanilmirth_skills_map", x: 20, y: 20}
    :ok = UnitRegistry.register_unit(:player, 100, PlayerState, owner, self())
    :ok = SpatialIndex.add_unit(:player, 100, 20, 20, owner.map_name)

    pids =
      for id <- 7_010..7_014 do
        register_mob(id, 25, 20, {:player, 100})

        pid =
          spawn(fn ->
            receive do
              :stop -> :ok
            end
          end)

        {:ok, {MobState, mob, _pid}} = UnitRegistry.get_unit(:mob, id)
        :ok = UnitRegistry.register_unit(:mob, id, MobState, mob, pid)
        {id, pid}
      end

    on_exit(fn ->
      Enum.each(pids, fn {id, pid} ->
        Process.exit(pid, :kill)
        UnitRegistry.unregister_unit(:mob, id)
        SpatialIndex.remove_unit(:mob, id)
      end)
    end)

    seed_rolls([{100, 100}, {5, 1}])
    started_at = System.monotonic_time(:millisecond)

    assert {:local_effects, _,
            [{:homunculus, {:apply_heal, 1_500_001, 67, {:homunculus, 1_500_001}}}]} =
             HvanChaotic.cast(vanilmirth(), :self, 5, HvanChaotic.definition())

    assert System.monotonic_time(:millisecond) - started_at <= 180
  end

  test "the typed mob heal effect is delivered only through the post-settlement local route" do
    caster = vanilmirth()
    register_mob(7_001, 10, 11, {:player, 100})

    session = %SessionState{
      game_state: %PlayerState{character_id: 100},
      connection_pid: self(),
      homunculus: caster
    }

    expect(MobSession, :heal, fn pid, 67 ->
      assert pid == self()
      :ok
    end)

    effect = {:mob, {:apply_heal, 7_001, 67, {:homunculus, caster.world_gid}}}
    assert {:noreply, ^session} = CommandHandler.local_effect(effect, session)
  end

  test "Bio Explosion returns only its ranked delayed destructive descriptor" do
    caster = %{vanilmirth() | class_id: 6_012, intimacy_hundredths: 45_000}

    assert {:ok, definition} = Catalog.by_id(8_016)
    assert definition.name == :hvan_explosion
    assert definition.max_level == 3
    assert definition.target_type == :self
    assert definition.damage_kind == :misc
    assert definition.sp_cost == [1, 1, 1]
    assert definition.cooldown == [1_000, 1_000, 1_000]
    assert definition.splash_radius == 5
    assert :ok = HvanExplosion.validate(caster, :self, 1, definition)

    assert {:error, :insufficient_intimacy} =
             HvanExplosion.validate(%{caster | intimacy_hundredths: 44_999}, :self, 1, definition)

    for {rank, damage} <- [{1, 1_000}, {2, 1_500}, {3, 2_000}] do
      assert {:local_effects, ^caster,
              [
                {:homunculus,
                 {:schedule_bio_explosion,
                  %{
                    kind: :bio_explosion,
                    homunculus_id: 1,
                    world_gid: 1_500_001,
                    map_name: "vanilmirth_skills_map",
                    lifecycle: :active,
                    center: {10, 10},
                    skill_id: 8_016,
                    skill_level: ^rank,
                    base_damage: ^damage,
                    radius: 5,
                    delay_ms: 1_500,
                    required_intimacy: 45_000,
                    reset_intimacy: 100,
                    ignore_element: true,
                    target_skill_units: true,
                    shoot_range_los: true
                  }}}
              ]} = HvanExplosion.cast(caster, :self, rank, definition)
    end
  end

  test "Bio Explosion atomically persists settlement before scheduling and resolves once into no-reward death" do
    {session, row} = explosion_session()
    original_exp = session.homunculus.exp

    assert {:ok, settled} = CastingHandler.begin(session, 8_016, 1, :self)
    assert settled.homunculus.hp == 1_000
    assert settled.homunculus.exp == original_exp
    assert settled.homunculus.sp == 99
    assert settled.homunculus.intimacy_hundredths == 100
    assert is_reference(settled.homunculus_runtime.bio_explosion_timer_ref)
    assert settled.homunculus_runtime.bio_explosion_descriptor.kind == :bio_explosion

    persisted = Repo.reload!(row)
    assert persisted.hp == 1_000
    assert persisted.sp == 99
    assert persisted.intimacy_hundredths == 100
    assert persisted.exp == original_exp
    assert persisted.cooldowns["8016"] in 0..1_000

    ref = settled.homunculus_runtime.bio_explosion_timer_ref
    Process.cancel_timer(ref)
    assert {:noreply, resolved} = CommandHandler.info(:bio_explosion, ref, settled)
    assert resolved.homunculus.lifecycle == :dead
    assert resolved.homunculus.hp == 0
    assert resolved.homunculus.exp == original_exp
    assert resolved.homunculus.intimacy_hundredths == 100
    assert resolved.homunculus_runtime.bio_explosion_timer_ref == nil
    assert resolved.homunculus_runtime.bio_explosion_descriptor == nil

    persisted = Repo.reload!(row)
    assert persisted.lifecycle == "dead"
    assert persisted.hp == 0
    assert persisted.exp == original_exp
    assert persisted.intimacy_hundredths == 100
  end

  test "automatic Bio Explosion uses the same settlement and destructive descriptor as manual casting" do
    {session, row} = explosion_session()
    config = session.homunculus.ai_config
    skill = %{config.skills[8_016] | mode: :auto}
    homunculus = %{session.homunculus | ai_config: %{config | skills: %{8_016 => skill}}}
    armed = session |> Map.put(:homunculus, homunculus) |> AiHandler.arm()
    ai_ref = armed.homunculus_runtime.ai_timer_ref
    Process.cancel_timer(ai_ref)

    assert {:noreply, automatic} = CommandHandler.info(:ai_tick, ai_ref, armed)
    assert automatic.homunculus.sp == 99
    assert automatic.homunculus.intimacy_hundredths == 100
    assert automatic.homunculus.cooldowns[8_016] > Clock.now_ms()
    assert automatic.homunculus_runtime.bio_explosion_descriptor.kind == :bio_explosion
    assert is_reference(automatic.homunculus_runtime.bio_explosion_timer_ref)

    persisted = Repo.reload!(row)
    assert persisted.sp == 99
    assert persisted.intimacy_hundredths == 100
    assert persisted.cooldowns["8016"] in 0..1_000
  end

  test "a pending Bio Explosion rejects every manual and AI Homunculus cast unchanged" do
    {session, _row} = explosion_session()
    assert {:ok, pending} = CastingHandler.begin(session, 8_016, 1, :self)

    ref = pending.homunculus_runtime.bio_explosion_timer_ref
    descriptor = pending.homunculus_runtime.bio_explosion_descriptor

    resources =
      {pending.homunculus.hp, pending.homunculus.sp, pending.homunculus.intimacy_hundredths,
       pending.homunculus.cooldowns}

    for {id, target} <- [{8_013, {:unit, {:mob, 7_101}}}, {8_014, :self}] do
      assert {:error, :bio_explosion_pending, ^pending} =
               CastingHandler.begin(pending, id, 1, target)
    end

    target =
      start_mob_session(
        unit_id: 7_105,
        map_name: "vanilmirth_skills_map",
        position: {11, 10},
        max_hp: 5_000,
        hp: 5_000
      )

    on_exit(fn -> end_mob_session(target) end)

    for {id, target_type} <- [{8_013, :enemy}, {8_014, :self}] do
      config = Config.default([%{id: id, target: target_type, allowed_thresholds: []}])
      skill = %{config.skills[id] | mode: :auto}

      automatic = %{
        pending
        | homunculus: %{
            pending.homunculus
            | class_id: 6_004,
              learned_skills: %{id => 1},
              ai_config: %{config | stance: :aggressive, skills: %{id => skill}}
          }
      }

      armed = AiHandler.arm(automatic)
      ai_ref = armed.homunculus_runtime.ai_timer_ref
      Process.cancel_timer(ai_ref)

      assert {:noreply, rejected} = CommandHandler.info(:ai_tick, ai_ref, armed)
      assert rejected.homunculus_runtime.bio_explosion_timer_ref == ref
      assert rejected.homunculus_runtime.bio_explosion_descriptor == descriptor

      assert {rejected.homunculus.hp, rejected.homunculus.sp,
              rejected.homunculus.intimacy_hundredths, rejected.homunculus.cooldowns} == resources

      Process.cancel_timer(rejected.homunculus_runtime.ai_timer_ref)
    end

    assert get_mob_state(target.pid).hp == 5_000
    Process.cancel_timer(ref)
  end

  test "Bio Explosion settles persistence and local state before its first AoE delivery" do
    {session, row} = explosion_session()
    gid = session.homunculus.world_gid

    near =
      start_mob_session(
        unit_id: 7_101,
        map_name: "vanilmirth_skills_map",
        position: {15, 10},
        max_hp: 5_000,
        hp: 5_000,
        element: {:ghost, 4}
      )

    far =
      start_mob_session(
        unit_id: 7_102,
        map_name: "vanilmirth_skills_map",
        position: {16, 10},
        max_hp: 5_000,
        hp: 5_000,
        element: {:ghost, 4}
      )

    on_exit(fn ->
      end_mob_session(near)
      end_mob_session(far)
    end)

    :ok =
      UnitRegistry.register_unit(
        :homunculus,
        gid,
        HomunculusState,
        session.homunculus,
        self()
      )

    test_pid = self()

    expect(HomunculusPersistence, :save_semantic, fn persisted, attrs ->
      assert persisted.id == row.id
      assert attrs.intimacy_hundredths == 100
      call_original(HomunculusPersistence, :save_semantic, [persisted, attrs])
    end)

    expect(StateCommit, :commit, fn current, committed ->
      assert committed.sp == 99
      assert committed.intimacy_hundredths == 100
      call_original(StateCommit, :commit, [current, committed])
    end)

    expect(MobSession, :apply_damage, fn pid, damage, attacker ->
      assert pid == near.pid
      assert damage == 1_000
      assert attacker == {:homunculus, gid}
      assert Repo.reload!(row).intimacy_hundredths == 100

      assert {:ok, {HomunculusState, committed, _pid}} =
               UnitRegistry.get_unit(:homunculus, gid)

      assert committed.sp == 99
      assert committed.intimacy_hundredths == 100
      send(test_pid, :bio_explosion_delivered)
      call_original(MobSession, :apply_damage, [pid, damage, attacker])
    end)

    manager =
      start_supervised!(
        {Manager,
         name: nil,
         schedule_tick: fn _pid, _interval -> :ok end,
         unit_available?: fn _unit_type, _unit_id, _map_name -> true end}
      )

    :ok = Manager.register(manager, explosion_group(1, :mob, 7_101, {10, 15}, true))
    :ok = Manager.register(manager, explosion_group(2, :homunculus, gid, {11, 10}, true))
    :ok = Manager.register(manager, explosion_group(3, :mob, 7_101, {12, 10}, false))

    [enemy_trap] = Storage.get_cells_by_group(1)
    [ally_trap] = Storage.get_cells_by_group(2)
    [generic_unit] = Storage.get_cells_by_group(3)

    assert {:ok, settled} = CastingHandler.begin(session, 8_016, 1, :self)
    assert settled.homunculus.lifecycle == :active
    assert Process.read_timer(settled.homunculus_runtime.bio_explosion_timer_ref) in 1_400..1_500
    assert_received :bio_explosion_delivered
    assert_eventually(fn -> get_mob_state(near.pid).hp == 4_000 end)
    assert get_mob_state(far.pid).hp == 5_000
    assert {:error, :not_found} = UnitRegistry.get_unit(:skill_unit, enemy_trap.cell_id)
    assert {:ok, _registered} = UnitRegistry.get_unit(:skill_unit, ally_trap.cell_id)
    assert {:ok, _registered} = UnitRegistry.get_unit(:skill_unit, generic_unit.cell_id)

    Process.cancel_timer(settled.homunculus_runtime.bio_explosion_timer_ref)
  end

  test "Bio Explosion excludes an in-radius target behind a projectile blocker" do
    {session, _row} = explosion_session()

    blocked =
      start_mob_session(
        unit_id: 7_103,
        map_name: "vanilmirth_skills_map",
        position: {15, 10},
        max_hp: 5_000,
        hp: 5_000
      )

    :ok =
      Cell.put("vanilmirth_skills_map", 12, 10, :bio_explosion_test, 1, blocks_projectiles: true)

    on_exit(fn ->
      Cell.delete("vanilmirth_skills_map", 12, 10, :bio_explosion_test, 1)
      end_mob_session(blocked)
    end)

    assert {:ok, settled} = CastingHandler.begin(session, 8_016, 1, :self)
    assert get_mob_state(blocked.pid).hp == 5_000
    Process.cancel_timer(settled.homunculus_runtime.bio_explosion_timer_ref)
  end

  test "Bio Explosion persistence failure leaves a hostile target and session unchanged" do
    {session, row} = explosion_session()

    target =
      start_mob_session(
        unit_id: 7_104,
        map_name: "vanilmirth_skills_map",
        position: {15, 10},
        max_hp: 5_000,
        hp: 5_000
      )

    on_exit(fn -> end_mob_session(target) end)
    stub(HomunculusPersistence, :save_semantic, fn _row, _attrs -> {:error, :forced} end)
    reject(&MobSession.apply_damage/3)

    assert {:error, :bio_explosion_settlement_failed, ^session} =
             CastingHandler.begin(session, 8_016, 1, :self)

    assert get_mob_state(target.pid).hp == 5_000
    assert session.homunculus_runtime.bio_explosion_timer_ref == nil
    assert session.homunculus_runtime.bio_explosion_descriptor == nil

    persisted = Repo.reload!(row)
    assert persisted.hp == 1_000
    assert persisted.sp == 100
    assert persisted.intimacy_hundredths == 45_000
    assert persisted.exp == session.homunculus.exp
    assert persisted.cooldowns == %{}
    assert session.homunculus_runtime.bio_explosion_timer_ref == nil
  end

  test "Bio Explosion rejects 44_999 and accepts the inclusive 45_000 boundary" do
    {session, row} = explosion_session()
    homunculus = %{session.homunculus | intimacy_hundredths: 44_999}
    session = %{session | homunculus: homunculus}

    assert {:error, :insufficient_intimacy, ^session} =
             CastingHandler.begin(session, 8_016, 1, :self)

    persisted = Repo.reload!(row)
    assert persisted.hp == 1_000
    assert persisted.sp == 100
    assert persisted.intimacy_hundredths == 45_000
    assert persisted.cooldowns == %{}
  end

  for operation <- [:warp, :owner_death, :prior_death, :active_expiry, :terminate] do
    test "a settled Bio Explosion timer is canceled and stale after #{operation}" do
      {session, row} = explosion_session()
      assert {:ok, settled} = CastingHandler.begin(session, 8_016, 1, :self)
      explosion_ref = settled.homunculus_runtime.bio_explosion_timer_ref

      canceled = cancel_explosion_through(unquote(operation), settled)
      assert canceled.homunculus_runtime.bio_explosion_timer_ref == nil
      assert canceled.homunculus_runtime.bio_explosion_descriptor == nil

      before_stale = persisted_outcome(Repo.reload!(row))

      assert {:noreply, unchanged} =
               CommandHandler.info(:bio_explosion, explosion_ref, canceled)

      assert unchanged == canceled
      assert persisted_outcome(Repo.reload!(row)) == before_stale
    end
  end

  test "Bio Explosion death fails closed after identity, map, lifecycle, or life changes" do
    for changed_field <- [:map_name, :id, :world_gid, :lifecycle, :hp] do
      {session, row} = explosion_session()
      assert {:ok, settled} = CastingHandler.begin(session, 8_016, 1, :self)
      ref = settled.homunculus_runtime.bio_explosion_timer_ref
      Process.cancel_timer(ref)

      changed_homunculus =
        case changed_field do
          :map_name -> %{settled.homunculus | map_name: "different_map"}
          :id -> %{settled.homunculus | id: settled.homunculus.id + 1}
          :world_gid -> %{settled.homunculus | world_gid: settled.homunculus.world_gid + 1}
          :lifecycle -> %{settled.homunculus | lifecycle: :rested}
          :hp -> %{settled.homunculus | hp: 0}
        end

      changed = %{settled | homunculus: changed_homunculus}
      assert {:noreply, unchanged} = CommandHandler.info(:bio_explosion, ref, changed)
      assert unchanged.homunculus == changed_homunculus
      assert unchanged.homunculus_runtime.bio_explosion_timer_ref == nil
      assert Repo.reload!(row).hp == 1_000
    end
  end

  test "Instruction Change applies exact STR and INT ranks only to original and evolved Vanilmirth" do
    deltas = [{1, {1, 1}}, {2, {1, 2}}, {3, {3, 2}}, {4, {4, 4}}, {5, {4, 5}}]

    for class_id <- [6_004, 6_012], {rank, {str_delta, int_delta}} <- deltas do
      base =
        vanilmirth()
        |> Map.put(:class_id, class_id)
        |> Map.put(:learned_skills, %{})
        |> HomunculusStats.recompute()

      changed =
        base
        |> Map.put(:learned_skills, %{8_015 => rank})
        |> HomunculusStats.recompute()

      assert changed.str - base.str == str_delta
      assert changed.int - base.int == int_delta
    end

    wrong_species =
      vanilmirth()
      |> Map.put(:class_id, 6_001)
      |> Map.put(:learned_skills, %{8_015 => 5})
      |> HomunculusStats.recompute()

    without_skill =
      wrong_species
      |> Map.put(:learned_skills, %{})
      |> HomunculusStats.recompute()

    assert {wrong_species.str, wrong_species.int} == {without_skill.str, without_skill.int}
  end

  test "Instruction Change is a passive marker with the exact catalog identity" do
    assert {:ok, definition} = Catalog.by_id(8_015)
    assert definition.name == :hvan_instruct
    assert definition.max_level == 5
    assert definition.target_type == :passive
    assert :error = Catalog.active_module_for(:hvan_instruct)
    assert {:ok, _module} = Catalog.passive_module_for(:hvan_instruct)
  end

  defp explosion_group(id, caster_type, caster_id, cell, trap?) do
    state = %{
      cell_attrs: %{
        cell => %{
          hp: 500,
          max_hp: 500,
          flags: [:targetable],
          state: %{combat: %{element: {:neutral, 1}}}
        }
      }
    }

    state = if trap?, do: Map.put(state, :trap, %TrapState{}), else: state

    %Group{
      group_id: id,
      skill_id: 0,
      skill_name: :explosion_fixture,
      level: 1,
      caster_type: caster_type,
      caster_id: caster_id,
      map_name: "vanilmirth_skills_map",
      center: cell,
      cells: [cell],
      next_tick_at: 0,
      expires_at: System.monotonic_time(:millisecond) + 60_000,
      interval: 1_000,
      visibility: :public,
      state: state
    }
  end

  defp cancel_explosion_through(:warp, session),
    do: CommandHandler.detach_for_warp(session, false)

  defp cancel_explosion_through(:owner_death, session),
    do: CommandHandler.owner_died(session)

  defp cancel_explosion_through(:prior_death, session) do
    gid = session.homunculus.world_gid

    {:noreply, dead} =
      CombatHandler.handle({:apply_damage, gid, session.homunculus.hp, %{}, {:mob, 1}}, session)

    dead
  end

  defp cancel_explosion_through(:active_expiry, session) do
    ref = session.homunculus_runtime.active_expiry_timer_ref
    runtime = %{session.homunculus_runtime | active_deadline_ms: Clock.now_ms() - 1}

    {:noreply, expired} =
      CommandHandler.info(:active_expired, ref, %{session | homunculus_runtime: runtime})

    expired
  end

  defp cancel_explosion_through(:terminate, session), do: CommandHandler.terminate(session)

  defp persisted_outcome(row) do
    {row.lifecycle, row.hp, row.sp, row.exp, row.intimacy_hundredths, row.cooldowns}
  end

  defp explosion_session do
    suffix = System.unique_integer([:positive])

    account =
      %Account{}
      |> Account.changeset(%{
        userid: "hvan#{suffix}",
        user_pass: "secret",
        email: "hvan#{suffix}@example.com"
      })
      |> Repo.insert!()

    character =
      %Character{}
      |> Character.changeset(%{
        account_id: account.id,
        char_num: 0,
        name: "Hvan#{suffix}",
        class: 4_019,
        hair: 0,
        hair_color: 0,
        last_map: "vanilmirth_skills_map",
        last_x: 10,
        last_y: 10
      })
      |> Repo.insert!()

    row =
      %Homunculus{}
      |> Homunculus.changeset(%{
        character_id: character.id,
        class_id: 6_012,
        name: "Vanilmirth",
        lifecycle: "active",
        level: 50,
        exp: 123,
        skill_points: 0,
        hp: 1_000,
        max_hp: 1_000,
        sp: 100,
        max_sp: 100,
        str: 1,
        agi: 1,
        vit: 1,
        int: 50,
        dex: 1,
        luk: 1,
        hunger: 50,
        intimacy_hundredths: 45_000,
        active_remaining_ms: 60_000,
        learned_skills: %{"8016" => 1},
        cooldowns: %{},
        ai_config: %{}
      })
      |> Repo.insert!()

    homunculus = %{
      vanilmirth()
      | id: row.id,
        owner_character_id: character.id,
        class_id: 6_012,
        exp: 123,
        intimacy_hundredths: 45_000,
        learned_skills: %{8_016 => 1},
        ai_config:
          Config.default([
            %{id: 8_016, target: :self, allowed_thresholds: []}
          ]),
        raw_max_hp: 1_000,
        raw_max_sp: 100,
        raw_str: 1,
        raw_agi: 1,
        raw_vit: 1,
        raw_int: 50,
        raw_dex: 1,
        raw_luk: 1
    }

    game_state = %PlayerState{
      character_id: character.id,
      account_id: account.id,
      map_name: "vanilmirth_skills_map",
      x: 10,
      y: 10,
      dir: 0
    }

    now_ms = System.monotonic_time(:millisecond)
    active_deadline_ms = now_ms + 60_000

    session = %SessionState{
      game_state: game_state,
      connection_pid: self(),
      homunculus: homunculus,
      homunculus_runtime: %Runtime{
        private_dirty: false,
        clocks_online: true,
        active_deadline_ms: active_deadline_ms,
        active_expiry_timer_ref: Clock.arm_active(active_deadline_ms, now_ms)
      }
    }

    {session, row}
  end

  defp vanilmirth do
    %HomunculusState{
      id: 1,
      owner_character_id: 100,
      owner_session_pid: self(),
      class_id: 6_004,
      name: "Vanilmirth",
      lifecycle: :active,
      level: 50,
      hp: 1_000,
      max_hp: 1_000,
      sp: 100,
      max_sp: 100,
      int: 50,
      world_gid: 1_500_001,
      map_name: "vanilmirth_skills_map",
      x: 10,
      y: 10,
      action_state: :idle,
      movement_state: :standing,
      combat_stats: %{
        atk: 0,
        atk_min: 0,
        atk_max: 0,
        def: 0,
        soft_def: 0,
        hit: 0,
        flee: 0,
        perfect_dodge: 0,
        critical: 0,
        matk: 7,
        matk_min: 7,
        matk_max: 7,
        mdef: 0,
        soft_mdef: 0,
        hp_regen_rate: 0,
        sp_regen_rate: 0
      }
    }
  end

  defp register_mob(id, x, y, target_ref, overrides \\ []) do
    mob = %MobState{
      instance_id: id,
      mob_id: 1,
      mob_data: nil,
      spawn_ref: nil,
      x: x,
      y: y,
      map_name: "vanilmirth_skills_map",
      hp: Keyword.get(overrides, :hp, 100),
      max_hp: 100,
      sp: 0,
      max_sp: 0,
      is_dead: Keyword.get(overrides, :is_dead, false),
      target_ref: target_ref,
      spawned_at: 0
    }

    :ok = UnitRegistry.register_unit(:mob, id, MobState, mob, self())
    :ok = SpatialIndex.add_unit(:mob, id, x, y, mob.map_name)
  end

  defp seed_rolls(expected) do
    seed =
      Enum.find(1..100_000, fn seed ->
        :rand.seed(:exsss, {seed, seed + 1, seed + 2})
        Enum.all?(expected, fn {upper, roll} -> :rand.uniform(upper) == roll end)
      end)

    :rand.seed(:exsss, {seed, seed + 1, seed + 2})
  end
end
