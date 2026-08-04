defmodule Aesir.ZoneServer.Mmo.StatusEffect.HomunculusStatusTest do
  use Aesir.ZoneServer.IntegrationCase

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.Homunculus
  alias Aesir.Repo
  alias Aesir.ZoneServer.Mmo.Combat.DamageApplication
  alias Aesir.ZoneServer.Mmo.StatusEffect.ContextBuilder
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Bloodlust
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Mmo.StatusTickManager
  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.CommandHandler
  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.ProgressionHandler
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Homunculus.StateCommit
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup do
    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        userid: "hom_status_#{System.unique_integer([:positive])}",
        user_pass: "password",
        email: "hom-status@example.com"
      })
      |> Repo.insert()

    {:ok, character} =
      %Character{}
      |> Character.changeset(%{
        account_id: account.id,
        char_num: 0,
        name: "HomStatus#{System.unique_integer([:positive])}",
        class: 5,
        base_level: 50,
        job_level: 50,
        hp: 1_000,
        max_hp: 1_000,
        sp: 500,
        max_sp: 500,
        last_map: "hom_status_map",
        last_x: 50,
        last_y: 50
      })
      |> Repo.insert()

    insert_homunculus(character.id)
    character = Repo.preload(character, :homunculus)
    session = start_player_session(character: character)
    on_exit(fn -> stop_if_alive(session.pid) end)

    state = PlayerSession.get_state(session.pid)
    %{character: character, session: session, gid: state.homunculus.world_gid}
  end

  test "a generic status applies to a living Homunculus using its own context", %{
    session: session,
    gid: gid
  } do
    assert :ok = Interpreter.apply_status(:homunculus, gid, :sc_increaseagi, val1: 4, val2: 7)
    assert StatusStorage.has_status?(:homunculus, gid, :sc_increaseagi)

    assert_eventually(fn -> PlayerSession.get_state(session.pid).homunculus.agi == 19 end)
    entry = StatusStorage.get_status(:homunculus, gid, :sc_increaseagi)
    context = ContextBuilder.build_context(:homunculus, gid, nil, entry)
    homunculus = PlayerSession.get_state(session.pid).homunculus

    assert context.target == HomunculusState.get_stats(homunculus)
    assert {:ok, entity_info} = UnitRegistry.get_unit_info(:homunculus, gid)
    assert entity_info.race == homunculus.race
    assert entity_info.element == elem(homunculus.element, 0)
    assert entity_info.element_level == elem(homunculus.element, 1)
    assert entity_info.size == homunculus.size
  end

  test "status application notifies the owner aggregate", %{session: session, gid: gid} do
    assert PlayerSession.get_state(session.pid).homunculus_runtime.private_dirty == false

    assert :ok = Interpreter.apply_status(:homunculus, gid, :sc_increaseagi, val1: 4, val2: 7)

    assert_eventually(fn ->
      PlayerSession.get_state(session.pid).homunculus_runtime.private_dirty
    end)
  end

  test "a non-damaging tick notifies the owner aggregate", %{session: session, gid: gid} do
    assert :ok =
             Interpreter.apply_status(:homunculus, gid, :sc_increaseagi,
               tick: 60_000,
               duration: 60_000
             )

    assert_eventually(fn ->
      PlayerSession.get_state(session.pid).homunculus_runtime.private_dirty
    end)

    :sys.replace_state(session.pid, fn current ->
      runtime = %{current.homunculus_runtime | private_dirty: false}
      %{current | homunculus_runtime: runtime}
    end)

    past = System.monotonic_time(:millisecond) - 1
    :ok = StatusStorage.update_next_tick(:homunculus, gid, :sc_increaseagi, past)
    assert {:noreply, _state} = StatusTickManager.handle_info(:tick, %StatusTickManager.State{})

    assert_eventually(fn ->
      PlayerSession.get_state(session.pid).homunculus_runtime.private_dirty
    end)
  end

  test "player-only, equipment-only, and player-resource statuses reject Homunculi", %{
    gid: gid
  } do
    assert {:error, :ineligible_target} =
             Interpreter.apply_status(:homunculus, gid, :sc_devotion)

    assert {:error, :ineligible_target} =
             Interpreter.apply_status(:homunculus, gid, :sc_adrenaline)

    assert {:error, :ineligible_target} =
             Interpreter.apply_status(:homunculus, gid, :sc_maximizepower)
  end

  test "a manual status tick delivers typed damage through the owner session", %{
    session: session,
    gid: gid
  } do
    assert :ok =
             Interpreter.apply_status(:homunculus, gid, :sc_poison, bypass_resistance: true)

    past = System.monotonic_time(:millisecond) - 1
    :ok = StatusStorage.update_next_tick(:homunculus, gid, :sc_poison, past)

    assert {:noreply, _state} =
             StatusTickManager.handle_info(:tick, %StatusTickManager.State{})

    assert_eventually(fn -> PlayerSession.get_state(session.pid).homunculus.hp == 793 end)
    session_pid = session.pid

    assert {:ok, {HomunculusState, %{hp: 793}, ^session_pid}} =
             UnitRegistry.get_unit(:homunculus, gid)
  end

  test "a lethal status tick clears rows and world presence", %{session: session, gid: gid} do
    :sys.replace_state(session.pid, fn current ->
      StateCommit.commit(current, %{current.homunculus | hp: 1})
    end)

    assert :ok =
             Interpreter.apply_status(:homunculus, gid, :sc_poison, bypass_resistance: true)

    past = System.monotonic_time(:millisecond) - 1
    :ok = StatusStorage.update_next_tick(:homunculus, gid, :sc_poison, past)

    assert {:noreply, _state} =
             StatusTickManager.handle_info(:tick, %StatusTickManager.State{})

    assert_eventually(fn -> StatusStorage.get_unit_statuses(:homunculus, gid) == [] end)
    assert_eventually(fn -> UnitRegistry.get_unit(:homunculus, gid) == {:error, :not_found} end)
  end

  test "cross-map warp clears flagged statuses and retains ordinary statuses", %{
    session: session,
    gid: gid
  } do
    assert :ok = Interpreter.apply_status(:homunculus, gid, :sc_anklesnare)
    assert :ok = Interpreter.apply_status(:homunculus, gid, :sc_increaseagi)

    :sys.replace_state(session.pid, &CommandHandler.detach_for_warp(&1, false))

    refute StatusStorage.has_status?(:homunculus, gid, :sc_anklesnare)
    assert StatusStorage.has_status?(:homunculus, gid, :sc_increaseagi)
  end

  test "retained Fleet and Speed modifiers survive warp re-entry", %{session: session, gid: gid} do
    baseline = PlayerSession.get_state(session.pid).homunculus
    assert :ok = Interpreter.apply_status(:homunculus, gid, :sc_fleet, val2: 120, val3: 25)
    assert :ok = Interpreter.apply_status(:homunculus, gid, :sc_speed, val2: 50)

    assert_eventually(fn ->
      current = PlayerSession.get_state(session.pid).homunculus

      current.attack_delay_ms < baseline.attack_delay_ms and
        current.combat_stats.flee == baseline.combat_stats.flee + 50
    end)

    before_warp = PlayerSession.get_state(session.pid).homunculus
    :sys.replace_state(session.pid, &CommandHandler.detach_for_warp(&1, false))

    :sys.replace_state(session.pid, fn current ->
      StateCommit.activate_claimed(current, current.homunculus, gid)
    end)

    reentered = PlayerSession.get_state(session.pid).homunculus
    assert reentered.world_gid == gid
    assert reentered.attack_delay_ms == before_warp.attack_delay_ms
    assert reentered.combat_stats.flee == before_warp.combat_stats.flee
    assert StatusStorage.has_status?(:homunculus, gid, :sc_fleet)
    assert StatusStorage.has_status?(:homunculus, gid, :sc_speed)
  end

  test "same-GID activation preserves modifiers and fresh activation is isolated", %{
    session: session,
    gid: gid
  } do
    baseline = PlayerSession.get_state(session.pid).homunculus
    assert :ok = Interpreter.apply_status(:homunculus, gid, :sc_fleet, val2: 120, val3: 25)
    assert :ok = Interpreter.apply_status(:homunculus, gid, :sc_speed, val2: 50)

    assert_eventually(fn ->
      PlayerSession.get_state(session.pid).homunculus.attack_delay_ms < baseline.attack_delay_ms
    end)

    :sys.replace_state(session.pid, fn current ->
      StateCommit.activate_claimed(current, current.homunculus, gid)
    end)

    retained = PlayerSession.get_state(session.pid).homunculus
    assert retained.attack_delay_ms < baseline.attack_delay_ms
    assert retained.combat_stats.flee == baseline.combat_stats.flee + 50

    fresh_gid = 1_950_000 + rem(System.unique_integer([:positive]), 40_000)
    assert UnitRegistry.claim_unit_id(fresh_gid, :homunculus)

    :sys.replace_state(session.pid, fn current ->
      fresh = %{current.homunculus | world_gid: nil}
      StateCommit.activate_claimed(current, fresh, fresh_gid)
    end)

    activated = PlayerSession.get_state(session.pid).homunculus
    assert activated.world_gid == fresh_gid
    assert activated.attack_delay_ms == baseline.attack_delay_ms
    assert activated.combat_stats.flee == baseline.combat_stats.flee
  end

  test "progression recompute retains active StatusStorage modifiers", %{
    session: session,
    gid: gid
  } do
    assert :ok = Interpreter.apply_status(:homunculus, gid, :sc_change, val2: 30, val3: 20)
    assert :ok = Interpreter.apply_status(:homunculus, gid, :sc_fleet, val2: 120, val3: 25)

    assert_eventually(fn -> PlayerSession.get_state(session.pid).homunculus.vit == 43 end)
    active = PlayerSession.get_state(session.pid).homunculus

    assert {:ok, progressed} = ProgressionHandler.gain_exp(active, 0)
    assert progressed.vit == active.vit
    assert progressed.int == active.int
    assert progressed.attack_delay_ms == active.attack_delay_ms
    assert StatusStorage.has_status?(:homunculus, gid, :sc_change)
    assert StatusStorage.has_status?(:homunculus, gid, :sc_fleet)
  end

  test "Rest clears statuses without clearing durable cooldowns", %{session: session, gid: gid} do
    assert :ok = Interpreter.apply_status(:homunculus, gid, :sc_increaseagi)
    cooldowns = PlayerSession.get_state(session.pid).homunculus.cooldowns

    :sys.replace_state(session.pid, fn current ->
      rested = %{current.homunculus | lifecycle: :rested}
      StateCommit.commit(current, rested)
    end)

    state = PlayerSession.get_state(session.pid)
    assert state.homunculus.lifecycle == :rested
    assert state.homunculus.cooldowns == cooldowns
    assert StatusStorage.get_unit_statuses(:homunculus, gid) == []
  end

  test "death and graceful logout leave no Homunculus status rows", %{
    session: session,
    gid: gid
  } do
    assert :ok = Interpreter.apply_status(:homunculus, gid, :sc_increaseagi)

    assert :ok =
             DamageApplication.apply_unit_damage(
               :homunculus,
               session.pid,
               gid,
               10_000,
               %{},
               {:mob, 2_001}
             )

    assert_eventually(fn -> StatusStorage.get_unit_statuses(:homunculus, gid) == [] end)
    :ok = PlayerSession.disconnect(session.pid)
    assert StatusStorage.get_unit_statuses(:homunculus, gid) == []
  end

  test "reconnect cleanup clears statuses left by a dead owner process", %{
    character: character,
    session: session,
    gid: gid
  } do
    assert :ok = Interpreter.apply_status(:homunculus, gid, :sc_increaseagi)
    Process.unlink(session.pid)
    monitor = Process.monitor(session.pid)
    Process.exit(session.pid, :kill)
    assert_receive {:DOWN, ^monitor, :process, _, :killed}, 500
    assert StatusStorage.has_status?(:homunculus, gid, :sc_increaseagi)

    reloaded = character |> Repo.reload!() |> Repo.preload(:homunculus)
    replacement = start_player_session(character: reloaded)
    on_exit(fn -> stop_if_alive(replacement.pid) end)

    assert_eventually(fn ->
      not StatusStorage.has_status?(:homunculus, gid, :sc_increaseagi)
    end)
  end

  test "all six shared statuses are discovered with canonical metadata", %{gid: gid} do
    expected = %{
      sc_avoid: :hlif_avoid,
      sc_change: :hlif_change,
      sc_defence: nil,
      sc_bloodlust: :hami_bloodlust,
      sc_fleet: :hfli_fleet,
      sc_speed: :hfli_speed
    }

    Enum.each(expected, fn {status_id, icon} ->
      definition = Registry.get_definition(status_id)
      assert definition.properties == [:buff]
      assert definition.no_dispel == false
      assert definition.icon == icon
      assert :ok = Interpreter.apply_status(:homunculus, gid, status_id, duration: 60_000)
      assert StatusStorage.has_status?(:homunculus, gid, status_id)

      :ok =
        StatusStorage.update_status(:homunculus, gid, status_id, fn entry ->
          %{entry | expires_at: System.monotonic_time(:millisecond) - 1}
        end)
    end)

    assert {:noreply, _state} = StatusTickManager.handle_info(:tick, %StatusTickManager.State{})
    assert_eventually(fn -> StatusStorage.get_unit_statuses(:homunculus, gid) == [] end)
  end

  test "shared status modifier channels feed the Homunculus readers", %{gid: gid} do
    assert :ok = Interpreter.apply_status(:homunculus, gid, :sc_avoid, val2: 80)
    assert :ok = Interpreter.apply_status(:homunculus, gid, :sc_change, val2: 30, val3: 20)
    assert :ok = Interpreter.apply_status(:homunculus, gid, :sc_defence, val2: 15)
    assert :ok = Interpreter.apply_status(:homunculus, gid, :sc_bloodlust, val2: 40)
    assert :ok = Interpreter.apply_status(:homunculus, gid, :sc_fleet, val2: 120, val3: 25)
    assert :ok = Interpreter.apply_status(:homunculus, gid, :sc_speed, val2: 50)

    assert %{
             movement_speed: -80,
             vit: 30,
             int: 20,
             def: 15,
             atk_rate: 65,
             hom_aspd_rate: 120,
             flee: 50
           } = ModifierCalculator.get_all_modifiers(:homunculus, gid)

    assert {:error, :prevented} =
             Interpreter.apply_status(:homunculus, gid, :sc_change, val2: 60, val3: 40)
  end

  test "Change natural expiry sets exactly 10 HP and SP but explicit removal does not", %{
    session: session,
    character: character,
    gid: gid
  } do
    assert :ok =
             Interpreter.apply_status(:homunculus, gid, :sc_change,
               val2: 30,
               val3: 20,
               duration: 60_000
             )

    :ok =
      StatusStorage.update_status(:homunculus, gid, :sc_change, fn entry ->
        %{entry | expires_at: System.monotonic_time(:millisecond) - 1}
      end)

    assert {:noreply, _state} = StatusTickManager.handle_info(:tick, %StatusTickManager.State{})
    assert_eventually(fn -> PlayerSession.get_state(session.pid).homunculus.hp == 10 end)
    assert PlayerSession.get_state(session.pid).homunculus.sp == 10
    assert Repo.get_by!(Homunculus, character_id: character.id).hp == 10

    :sys.replace_state(session.pid, fn current ->
      StateCommit.commit(current, %{current.homunculus | hp: 400, sp: 100})
    end)

    assert :ok = Interpreter.apply_status(:homunculus, gid, :sc_change, val2: 30, val3: 20)
    assert :ok = Interpreter.remove_status(:homunculus, gid, :sc_change)
    assert_eventually(fn -> PlayerSession.get_state(session.pid).homunculus.hp == 400 end)
    assert PlayerSession.get_state(session.pid).homunculus.sp == 100
  end

  test "Bloodlust emits one typed local heal only for positive primary basic hits" do
    instance = %StatusEntry{val2: 50, val3: 100, val4: 20}
    holder = {:homunculus, 70_001}

    assert {:ok, ^instance, [{:local_heal, ^holder, 24, ^holder}]} =
             Bloodlust.on_dealt_damage(
               holder,
               instance,
               %{damage: 123, primary_basic_weapon_hit?: true},
               %{}
             )

    for hit <- [
          %{damage: 0, primary_basic_weapon_hit?: true},
          %{damage: 123, skill_id: 8_005},
          %{damage: 123, reflected: true},
          %{damage: 123, dmg_type: :magic}
        ] do
      assert {:ok, ^instance} = Bloodlust.on_dealt_damage(holder, instance, hit, %{})
    end
  end

  test "a dead Homunculus rejects status application", %{session: session, gid: gid} do
    homunculus = PlayerSession.get_state(session.pid).homunculus
    dead = %{homunculus | lifecycle: :dead, action_state: :dead, hp: 0}
    UnitRegistry.update_unit_state(:homunculus, gid, dead)

    assert {:error, :target_dead} =
             Interpreter.apply_status(:homunculus, gid, :sc_increaseagi, val1: 4, val2: 7)

    refute StatusStorage.has_status?(:homunculus, gid, :sc_increaseagi)
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
      str: 11,
      agi: 12,
      vit: 13,
      int: 14,
      dex: 15,
      luk: 16,
      active_remaining_ms: 1_800_000,
      learned_skills: %{"8001" => 1},
      cooldowns: %{"8001" => 30_000},
      ai_config: %{}
    })
    |> Repo.insert!()
  end

  defp stop_if_alive(pid) do
    if Process.alive?(pid) do
      Process.unlink(pid)
      Process.exit(pid, :kill)
    end
  end
end
