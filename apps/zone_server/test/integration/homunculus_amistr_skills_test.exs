defmodule Aesir.ZoneServer.Integration.HomunculusAmistrSkillsTest do
  use Aesir.ZoneServer.IntegrationCase

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.Homunculus
  alias Aesir.Net.ParamChange
  alias Aesir.Repo
  alias Aesir.ZoneServer.Mmo.Homunculus.Ai.Config, as: AiConfig
  alias Aesir.ZoneServer.Mmo.Homunculus.Stats
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter
  alias Aesir.ZoneServer.Mmo.Skills.Homunculus.HamiCastle
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Bloodlust
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.AiHandler
  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.CastingHandler
  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.CommandHandler
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Homunculus.StateCommit
  alias Aesir.ZoneServer.Unit.Movement
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup do
    on_exit(&Catalog.reload/0)
    Catalog.reload()
    :ok
  end

  test "Amistr skill definitions expose Renewal costs and timing" do
    assert {:ok, castle} = Catalog.by_id(8005)
    assert castle.name == :hami_castle
    assert castle.max_level == 5
    assert castle.target_type == :self
    assert castle.damage_type == :no_damage
    assert castle.sp_cost == List.duplicate(10, 5)
    assert castle.cooldown == List.duplicate(1_000, 5)
    assert castle.after_cast_delay == []

    assert {:ok, defence} = Catalog.by_id(8006)
    assert defence.sp_cost == [20, 25, 30, 35, 40]
    assert defence.duration == [40_000, 35_000, 30_000, 25_000, 20_000]
    assert defence.cooldown == List.duplicate(30_000, 5)
    assert defence.status == :sc_defence

    assert {:ok, skin} = Catalog.by_id(8007)
    assert skin.target_type == :passive
    assert :error = Catalog.active_module_for(:hami_skin)

    assert {:ok, bloodlust} = Catalog.by_id(8008)
    assert bloodlust.sp_cost == List.duplicate(120, 3)
    assert bloodlust.duration == [60_000, 180_000, 300_000]
    assert bloodlust.cooldown == [300_000, 600_000, 900_000]
    assert bloodlust.status == :sc_bloodlust
  end

  test "Castling chance boundaries and failed cast settlement" do
    refute HamiCastle.chance_success?(1, 21)
    assert HamiCastle.chance_success?(1, 20)
    refute HamiCastle.chance_success?(3, 61)
    assert HamiCastle.chance_success?(3, 60)
    assert HamiCastle.chance_success?(5, 100)

    session = start_amistr_session()
    on_exit(fn -> stop_if_alive(session.pid) end)
    :rand.seed(:exsss, {1, 2, 3})

    :sys.replace_state(session.pid, fn current ->
      homunculus = %{
        current.homunculus
        | learned_skills: %{8005 => 1},
          sp: 200,
          cooldowns: %{}
      }

      current = StateCommit.commit(current, homunculus)
      assert {:ok, failed} = CastingHandler.begin(current, 8005, 1, :self)
      failed
    end)

    failed = PlayerSession.get_state(session.pid).homunculus
    assert failed.sp == 190
    assert Map.has_key?(failed.cooldowns, 8005)
  end

  test "Castling rejects stale owner preflight without settling SP or cooldown" do
    session = start_amistr_session()
    on_exit(fn -> stop_if_alive(session.pid) end)
    initial = PlayerSession.get_state(session.pid)
    owner = initial.game_state

    SpatialIndex.update_unit_position(
      :player,
      owner.character_id,
      owner.x + 1,
      owner.y,
      owner.map_name
    )

    assert {:error, :invalid_castling_endpoint, unchanged} =
             CastingHandler.begin(initial, 8005, 5, :self)

    assert unchanged.homunculus.sp == initial.homunculus.sp
    assert unchanged.homunculus.cooldowns == initial.homunculus.cooldowns
  end

  test "Castling rolls back a stale second endpoint validation without touching live runtime" do
    session = start_amistr_session()
    on_exit(fn -> stop_if_alive(session.pid) end)
    initial = PlayerSession.get_state(session.pid)
    owner_position = {initial.game_state.x, initial.game_state.y}
    homunculus_position = {initial.homunculus.x, initial.homunculus.y}
    Mimic.copy(Movement)
    Mimic.allow(Movement, self(), session.pid)

    stub(Movement, :swap_positions, fn _first, _second, _map_name -> {:error, :stale_endpoint} end)

    :sys.replace_state(session.pid, fn current ->
      movement_ref = Process.send_after(self(), :castling_movement_fixture, 60_000)
      separation_ref = Process.send_after(self(), :castling_separation_fixture, 60_000)
      cast_ref = Process.send_after(self(), :castling_cast_fixture, 60_000)
      cooldown_ref = Process.send_after(self(), :castling_cooldown_fixture, 60_000)
      cooldowns = %{8006 => System.monotonic_time(:millisecond) + 60_000}

      homunculus = %{
        current.homunculus
        | learned_skills: %{8005 => 5},
          sp: 200,
          cooldowns: cooldowns
      }

      current = StateCommit.commit(current, homunculus)

      runtime = %{
        current.homunculus_runtime
        | movement_timer_ref: movement_ref,
          separation_timer_ref: separation_ref,
          cast_timer_ref: cast_ref,
          cooldown_timer_ref: cooldown_ref,
          movement_path: [{49, 50}],
          private_dirty: false
      }

      staged = %{current | homunculus_runtime: runtime}

      assert {:error, :stale_castling_endpoint, restored} =
               CastingHandler.begin(staged, 8005, 5, :self)

      assert restored.homunculus.sp == homunculus.sp
      assert restored.homunculus.cooldowns == cooldowns
      assert restored.homunculus_runtime.movement_timer_ref == movement_ref
      assert restored.homunculus_runtime.separation_timer_ref == separation_ref
      assert restored.homunculus_runtime.cast_timer_ref == cast_ref
      assert restored.homunculus_runtime.movement_path == [{49, 50}]
      assert restored.homunculus_runtime.cooldown_timer_ref != cooldown_ref
      assert is_reference(restored.homunculus_runtime.cooldown_timer_ref)
      assert Process.read_timer(cooldown_ref) == false
      assert is_integer(Process.read_timer(restored.homunculus_runtime.cooldown_timer_ref))
      assert restored.homunculus_runtime.private_dirty == false

      assert {:ok, {_module, registered, _pid}} =
               UnitRegistry.get_unit(:homunculus, restored.homunculus.world_gid)

      assert registered.sp == homunculus.sp
      assert registered.cooldowns == cooldowns
      restored
    end)

    restored = PlayerSession.get_state(session.pid)
    assert {restored.game_state.x, restored.game_state.y} == owner_position
    assert {restored.homunculus.x, restored.homunculus.y} == homunculus_position

    assert {:ok, {elem(owner_position, 0), elem(owner_position, 1), restored.game_state.map_name}} ==
             SpatialIndex.get_unit_position(:player, restored.game_state.character_id)

    assert {:ok,
            {elem(homunculus_position, 0), elem(homunculus_position, 1),
             restored.game_state.map_name}} ==
             SpatialIndex.get_unit_position(:homunculus, restored.homunculus.world_gid)
  end

  test "Adamantium Skin uses the existing stat path for original and evolved Amistr only" do
    for {class_id, rank, expected_hp, expected_def, expected_regen} <- [
          {6002, 1, 1_020, 24, 5},
          {6002, 5, 1_100, 40, 25},
          {6010, 5, 1_100, 40, 25}
        ] do
      updated =
        amistr(%{class_id: class_id, learned_skills: %{8007 => rank}})
        |> Stats.recompute()

      assert updated.max_hp == expected_hp
      assert updated.combat_stats.def == expected_def
      assert updated.combat_stats.hp_regen_rate == expected_regen
    end

    wrong_species =
      amistr(%{class_id: 6001, learned_skills: %{8007 => 5}})
      |> Stats.recompute()

    assert wrong_species.max_hp == 1_000
    assert wrong_species.combat_stats.def == 20
    assert wrong_species.combat_stats.hp_regen_rate == 0
  end

  test "AI Castling uses the same CastingHandler outcome as a manual cast" do
    session = start_amistr_session()
    on_exit(fn -> stop_if_alive(session.pid) end)
    initial = PlayerSession.get_state(session.pid)
    owner_position = {initial.game_state.x, initial.game_state.y}
    hom_position = {initial.homunculus.x, initial.homunculus.y}

    :sys.replace_state(session.pid, fn current ->
      spec = %{id: 8005, target: :self, allowed_thresholds: []}
      config = AiConfig.default([spec])
      config = %{config | skills: %{8005 => %{config.skills[8005] | mode: :auto}}}

      homunculus = %{
        current.homunculus
        | class_id: 6002,
          learned_skills: %{8005 => 5},
          ai_config: config,
          sp: 200,
          max_sp: 200,
          raw_max_sp: 200
      }

      current = StateCommit.commit(current, homunculus)
      armed = AiHandler.arm(current)

      assert {:noreply, casted} =
               AiHandler.tick(armed.homunculus_runtime.ai_timer_ref, armed)

      casted
    end)

    casted = PlayerSession.get_state(session.pid)
    assert {casted.game_state.x, casted.game_state.y} == hom_position
    assert {casted.homunculus.x, casted.homunculus.y} == owner_position
    assert casted.homunculus.sp == 190
    assert Map.has_key?(casted.homunculus.cooldowns, 8005)
  end

  test "Defence and Bloodlust apply ranked statuses through the shared cast path" do
    session = start_amistr_session()
    on_exit(fn -> stop_if_alive(session.pid) end)
    current = PlayerSession.get_state(session.pid)
    homunculus = current.homunculus
    gid = homunculus.world_gid
    owner_id = current.game_state.character_id
    now = System.monotonic_time(:millisecond)

    for {level, val2, duration} <- [{1, 10, 40_000}, {3, 20, 30_000}, {5, 30, 20_000}] do
      caster = %{
        homunculus
        | learned_skills: %{8006 => level},
          sp: 200,
          cooldowns: %{}
      }

      assert {:instant, updated, []} =
               Interpreter.begin_homunculus_cast(caster, 8006, level, :self)

      assert updated.sp == 200 - Enum.at([20, 25, 30, 35, 40], level - 1)
      assert updated.cooldowns[8006] >= now + 29_000

      assert %{val1: ^level, val2: ^val2, source_id: ^gid} =
               owner_status =
               StatusStorage.get_status(:player, owner_id, :sc_defence)

      assert %{val1: ^level, val2: ^val2, source_id: ^gid} =
               hom_status =
               StatusStorage.get_status(:homunculus, homunculus.world_gid, :sc_defence)

      assert owner_status.expires_at in (now + duration - 1_000)..(now + duration + 1_000)
      assert hom_status.expires_at in (now + duration - 1_000)..(now + duration + 1_000)
      assert ModifierCalculator.get_all_modifiers(:player, owner_id).vit == val2
      assert ModifierCalculator.get_all_modifiers(:homunculus, homunculus.world_gid).def == val2
    end

    for {level, val2, val3, duration, cooldown} <- [
          {1, 30, 9, 60_000, 300_000},
          {2, 40, 18, 180_000, 600_000},
          {3, 50, 27, 300_000, 900_000}
        ] do
      caster = %{
        homunculus
        | class_id: 6010,
          intimacy_hundredths: 91_000,
          learned_skills: %{8008 => level},
          sp: 200,
          cooldowns: %{}
      }

      assert {:instant, updated, []} =
               Interpreter.begin_homunculus_cast(caster, 8008, level, :self)

      assert updated.sp == 80
      assert updated.cooldowns[8008] >= now + cooldown - 1_000

      assert %{val1: ^level, val2: ^val2, val3: ^val3, val4: 20} =
               status =
               StatusStorage.get_status(:homunculus, homunculus.world_gid, :sc_bloodlust)

      assert status.expires_at in (now + duration - 1_000)..(now + duration + 1_000)
    end

    instance = %StatusEntry{val2: 50, val3: 27, val4: 20}
    holder = {:homunculus, homunculus.world_gid}
    :rand.seed(:exsss, {1, 2, 3})

    assert {:ok, ^instance, [{:local_heal, ^holder, 24, ^holder}]} =
             Bloodlust.on_dealt_damage(
               holder,
               instance,
               %{damage: 123, primary_basic_weapon_hit?: true},
               %{}
             )
  end

  test "the existing AI timer chain commits due natural regeneration" do
    session = start_amistr_session()
    on_exit(fn -> stop_if_alive(session.pid) end)

    :sys.replace_state(session.pid, fn current ->
      homunculus =
        %{current.homunculus | hp: 500, learned_skills: %{8007 => 5}}
        |> Stats.recompute()

      current = StateCommit.commit(current, homunculus)
      now = System.monotonic_time(:millisecond)

      runtime = %{
        current.homunculus_runtime
        | hp_regen_deadline_ms: now - 1,
          sp_regen_deadline_ms: now + 60_000
      }

      armed = AiHandler.arm(%{current | homunculus_runtime: runtime})

      assert {:noreply, regenerated} =
               AiHandler.tick(armed.homunculus_runtime.ai_timer_ref, armed)

      regenerated
    end)

    regenerated = PlayerSession.get_state(session.pid)
    assert regenerated.homunculus.hp == 508
    assert is_reference(regenerated.homunculus_runtime.ai_timer_ref)

    assert regenerated.homunculus_runtime.hp_regen_deadline_ms >
             System.monotonic_time(:millisecond)
  end

  test "Defence refreshes real owner stats and restores them on expiry" do
    session = start_amistr_session()
    on_exit(fn -> stop_if_alive(session.pid) end)
    initial = PlayerSession.get_state(session.pid)
    owner_id = initial.game_state.character_id
    baseline_vit = PlayerStats.get_effective_stat(initial.game_state.stats, :vit)

    :sys.replace_state(session.pid, fn current ->
      homunculus = %{current.homunculus | learned_skills: %{8006 => 1}, sp: 200, cooldowns: %{}}
      current = StateCommit.commit(current, homunculus)
      assert {:ok, casted} = CastingHandler.begin(current, 8006, 1, :self)
      casted
    end)

    assert_eventually(fn ->
      state = PlayerSession.get_state(session.pid)
      PlayerStats.get_effective_stat(state.game_state.stats, :vit) == baseline_vit + 10
    end)

    assert_receive {:packet_sent, %ParamChange{}, :gameplay}
    :ok = StatusInterpreter.remove_status(:player, owner_id, :sc_defence, owner_refresh: :notify)

    assert_eventually(fn ->
      state = PlayerSession.get_state(session.pid)
      PlayerStats.get_effective_stat(state.game_state.stats, :vit) == baseline_vit
    end)
  end

  test "Castling clears movement and combat intent while preserving an active owner cast" do
    session = start_amistr_session()
    on_exit(fn -> stop_if_alive(session.pid) end)

    :sys.replace_state(session.pid, fn current ->
      owner_timer = Process.send_after(self(), :owner_cast_fixture, 60_000)
      attack_timer = Process.send_after(self(), :owner_attack_fixture, 60_000)
      hom_move_timer = Process.send_after(self(), :hom_move_fixture, 60_000)
      hom_cast_timer = Process.send_after(self(), :hom_cast_fixture, 60_000)

      casting = %{timer_ref: owner_timer, token: make_ref(), skill_id: 1, skill_level: 1}

      owner = %{
        current.game_state
        | action_state: :casting,
          state_context: %{cast_fixture: true},
          casting: casting,
          walk_path: [{60, 60}],
          movement_state: :moving,
          movement_intent: :combat,
          combat_target_id: 123,
          continuous_attack_timer: attack_timer
      }

      homunculus = %{current.homunculus | casting: %{token: make_ref()}, target: {:mob, 123}}

      runtime = %{
        current.homunculus_runtime
        | movement_timer_ref: hom_move_timer,
          cast_timer_ref: hom_cast_timer,
          movement_path: [{49, 50}]
      }

      :ok = UnitRegistry.update_unit_state(:player, owner.character_id, owner)
      :ok = UnitRegistry.update_unit_state(:homunculus, homunculus.world_gid, homunculus)
      staged = %{current | game_state: owner, homunculus: homunculus, homunculus_runtime: runtime}

      assert {:noreply, swapped} =
               CommandHandler.local_effect(
                 {:homunculus, {:castling_swap, homunculus.world_gid}},
                 staged
               )

      swapped
    end)

    swapped = PlayerSession.get_state(session.pid)
    assert swapped.game_state.action_state == :casting
    assert is_reference(swapped.game_state.casting.timer_ref)
    assert swapped.game_state.state_context == %{cast_fixture: true}
    assert swapped.game_state.walk_path == []
    assert swapped.game_state.combat_target_id == nil
    assert swapped.game_state.continuous_attack_timer == nil
    assert swapped.homunculus.action_state == :idle
    assert swapped.homunculus.casting == nil
    assert swapped.homunculus.target == nil
    assert swapped.homunculus_runtime.movement_timer_ref == nil
    assert swapped.homunculus_runtime.cast_timer_ref == nil
    assert swapped.homunculus_runtime.movement_path == []
  end

  test "Castling bounds definitive redirect failures and halts on an unknown outcome" do
    session = start_amistr_session()
    on_exit(fn -> stop_if_alive(session.pid) end)
    owner_id = PlayerSession.get_state(session.pid).game_state.character_id
    test_pid = self()
    {:ok, redirect_result} = Agent.start_link(fn -> {:error, :target_changed} end)

    mobs =
      for unit_id <- 1_820_001..1_820_009 do
        start_mob_session(unit_id: unit_id, map_name: "amistr_castling_map", awake: false)
      end

    Enum.each(mobs, &on_exit(fn -> end_mob_session(&1) end))
    Enum.each(mobs, &MobSession.set_target(&1.pid, {:player, owner_id}))

    assert_eventually(fn ->
      Enum.all?(mobs, &(get_mob_state(&1.pid).target_ref == {:player, owner_id}))
    end)

    Enum.each(mobs, fn mob ->
      :ok = UnitRegistry.update_unit_state(:mob, mob.unit_id, get_mob_state(mob.pid))
    end)

    Mimic.copy(MobSession)
    Mimic.allow(MobSession, self(), session.pid)

    stub(MobSession, :redirect_target, fn pid, {:player, ^owner_id}, _replacement ->
      send(test_pid, {:castling_redirect_attempt, pid})
      Agent.get(redirect_result, & &1)
    end)

    swap = fn ->
      :sys.replace_state(session.pid, fn current ->
        assert {:noreply, swapped} =
                 CommandHandler.local_effect(
                   {:homunculus, {:castling_swap, current.homunculus.world_gid}},
                   current
                 )

        swapped
      end)
    end

    swap.()
    mob_ids_by_pid = Map.new(mobs, &{&1.pid, &1.unit_id})

    attempts =
      for _ <- 1..8 do
        assert_receive {:castling_redirect_attempt, pid}
        Map.fetch!(mob_ids_by_pid, pid)
      end

    assert attempts == Enum.to_list(1_820_001..1_820_008)
    refute_receive {:castling_redirect_attempt, _}

    Agent.update(redirect_result, fn _ -> {:error, :outcome_unknown} end)
    swap.()
    assert_receive {:castling_redirect_attempt, _pid}
    refute_receive {:castling_redirect_attempt, _}
  end

  test "rank-five Castling swaps the real aggregate and redirects exactly one mob" do
    session = start_amistr_session()
    on_exit(fn -> stop_if_alive(session.pid) end)

    initial = PlayerSession.get_state(session.pid)
    owner_id = initial.game_state.character_id
    gid = initial.homunculus.world_gid

    first =
      start_mob_session(
        unit_id: 1_810_001,
        map_name: initial.game_state.map_name,
        awake: false
      )

    second =
      start_mob_session(
        unit_id: 1_810_002,
        map_name: initial.game_state.map_name,
        awake: false
      )

    unrelated =
      start_mob_session(
        unit_id: 1_810_003,
        map_name: initial.game_state.map_name,
        awake: false
      )

    Enum.each([first, second, unrelated], &on_exit(fn -> end_mob_session(&1) end))

    MobSession.set_target(first.pid, {:player, owner_id})
    MobSession.set_target(second.pid, {:player, owner_id})
    MobSession.set_target(unrelated.pid, {:player, owner_id + 1})

    assert_eventually(fn -> get_mob_state(first.pid).target_ref == {:player, owner_id} end)
    assert_eventually(fn -> get_mob_state(second.pid).target_ref == {:player, owner_id} end)

    MobSession.set_target(first.pid, {:player, owner_id + 2})
    assert_eventually(fn -> get_mob_state(first.pid).target_ref == {:player, owner_id + 2} end)

    owner_position = {initial.game_state.x, initial.game_state.y}
    hom_position = {initial.homunculus.x, initial.homunculus.y}

    :sys.replace_state(session.pid, fn current ->
      homunculus = %{
        current.homunculus
        | class_id: 6002,
          learned_skills: %{8005 => 5},
          sp: 200,
          max_sp: 200,
          raw_max_sp: 200
      }

      current = StateCommit.commit(current, homunculus)
      assert {:ok, casted} = CastingHandler.begin(current, 8005, 5, :self)
      casted
    end)

    swapped = PlayerSession.get_state(session.pid)
    assert {swapped.game_state.x, swapped.game_state.y} == hom_position
    assert {swapped.homunculus.x, swapped.homunculus.y} == owner_position
    assert swapped.game_state.movement_state == :standing
    assert swapped.homunculus.movement_state == :standing
    assert swapped.homunculus_runtime.private_dirty
    assert Process.alive?(session.pid)

    assert {:ok, {elem(hom_position, 0), elem(hom_position, 1), swapped.game_state.map_name}} ==
             SpatialIndex.get_unit_position(:player, owner_id)

    assert {:ok, {elem(owner_position, 0), elem(owner_position, 1), swapped.game_state.map_name}} ==
             SpatialIndex.get_unit_position(:homunculus, gid)

    assert {:ok, {_module, registered_owner, _pid}} = UnitRegistry.get_unit(:player, owner_id)
    assert {:ok, {_module, registered_hom, _pid}} = UnitRegistry.get_unit(:homunculus, gid)
    assert {registered_owner.x, registered_owner.y} == hom_position
    assert {registered_hom.x, registered_hom.y} == owner_position

    dirty = Movement.drain_dirty(swapped.game_state.map_name)
    assert {:player, owner_id, 0} in dirty
    assert {:homunculus, gid, 0} in dirty

    assert get_mob_state(first.pid).target_ref == {:player, owner_id + 2}
    assert_eventually(fn -> get_mob_state(second.pid).target_ref == {:homunculus, gid} end)
    assert get_mob_state(unrelated.pid).target_ref == {:player, owner_id + 1}
  end

  defp amistr(overrides) do
    struct!(
      HomunculusState,
      Map.merge(
        %{
          id: 5,
          owner_character_id: 100,
          owner_session_pid: self(),
          class_id: 6002,
          name: "Amistr",
          lifecycle: :active,
          level: 20,
          hp: 1_000,
          max_hp: 1_000,
          raw_max_hp: 1_000,
          sp: 200,
          max_sp: 200,
          raw_max_sp: 200,
          str: 10,
          raw_str: 10,
          agi: 10,
          raw_agi: 10,
          vit: 10,
          raw_vit: 10,
          int: 10,
          raw_int: 10,
          dex: 10,
          raw_dex: 10,
          luk: 10,
          raw_luk: 10,
          learned_skills: %{},
          world_gid: 1_500_005,
          map_name: "amistr_skill_test",
          x: 10,
          y: 10,
          action_state: :idle,
          movement_state: :standing,
          attack_delay_ms: 500,
          raw_attack_delay_ms: 500
        },
        overrides
      )
    )
  end

  defp start_amistr_session do
    suffix = System.unique_integer([:positive])

    account =
      %Account{}
      |> Account.changeset(%{
        userid: "amistr_#{suffix}",
        user_pass: "password",
        email: "amistr-#{suffix}@example.com"
      })
      |> Repo.insert!()

    character =
      %Character{}
      |> Character.changeset(%{
        account_id: account.id,
        char_num: 0,
        name: "Amistr#{suffix}",
        class: 5,
        base_level: 50,
        job_level: 50,
        hp: 1_000,
        max_hp: 1_000,
        sp: 500,
        max_sp: 500,
        last_map: "amistr_castling_map",
        last_x: 50,
        last_y: 50
      })
      |> Repo.insert!()

    %Homunculus{}
    |> Homunculus.changeset(%{
      character_id: character.id,
      class_id: 6002,
      name: "Amistr",
      lifecycle: "active",
      level: 50,
      hp: 1_000,
      max_hp: 1_000,
      sp: 200,
      max_sp: 200,
      str: 10,
      agi: 10,
      vit: 10,
      int: 10,
      dex: 10,
      luk: 10,
      active_remaining_ms: 1_800_000,
      learned_skills: %{"8005" => 5},
      cooldowns: %{},
      ai_config: %{}
    })
    |> Repo.insert!()

    character
    |> Repo.preload(:homunculus)
    |> then(&start_player_session(character: &1))
  end

  defp stop_if_alive(pid) do
    if Process.alive?(pid) do
      Process.unlink(pid)
      Process.exit(pid, :kill)
    end
  end
end
