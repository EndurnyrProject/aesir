defmodule Aesir.ZoneServer.Integration.BossMonsterIntegrationTest do
  @moduledoc """
  End-to-end acceptance of the boss monster feature, driving the real
  subsystems rather than unit-level seams:

  1. **Kill to reward.** Three real `PlayerSession`s (backed by real character
     rows, because the inventory FK demands them) wear an MVP-tier boss down.
     The real `MobSession` death path runs `KillExp` and `MvpReward`, and the
     MVP drop is delivered through the documented `{:script_apply, op}` seam
     into a *real* session -- the winner's client receives the `ItemAdded`
     push, which the Task 8 unit tests could not show because they answered
     that call with a fake process.
  2. **Traits.** A boss rejects externally applied stun, freeze and sleep that
     the same mob id accepts without the boss mode, while its own self-buff
     still lands through the live `MobSkill.Executor` in the same fight.
  3. **Concealment.** A hidden player is invisible to a normal mob's real aggro
     scan and visible to a boss, which acts as a detector.
  4. **Respawn durability.** A real boss death writes the durable deadline, a
     simulated restart reconciles it, and the boss returns at its *original*
     deadline rather than a fresh one -- exactly one instance either way.

  The respawn scenario drives `Coordinator` callbacks directly against the
  struct instead of a live process, mirroring `BossReconciliationTest`: the
  `Process.send_after` timers then target the test process, so the re-armed
  deadline can be measured without sleeping through a real map's tick loop.
  The `{:mob_died, ...}` cast itself is still delivered for real, by
  registering the test process under the map's coordinator name.
  """

  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Commons.InterServer.PubSub, as: ServerPubSub
  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.BossRespawn, as: BossRespawnRow
  alias Aesir.Commons.Models.Character
  alias Aesir.Net.Announcement, as: AnnouncementMsg
  alias Aesir.Net.ItemAdded
  alias Aesir.Repo
  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.BossRespawn
  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Map.MapManager
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.ItemManagement.Items
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDrop
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.Spawns
  alias Aesir.ZoneServer.Mmo.MobSkill.Executor
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.AIStateMachine
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Mob.MobSupervisor
  alias Phoenix.PubSub

  @map "prontera"

  # Deliberately outside the mob catalog: the real `prontera` coordinator
  # handles this mob's death, and a catalog id would have it respawn a live
  # boss on the shared map seconds later, in whichever test is running by then.
  # The MVP drop still resolves through the real `Items.by_aegis/1`.
  @boss_id 999_999
  @mvp_exp 100_000
  @mvp_item "Red_Potion"
  @base_level 50

  # Boss respawn scenario: a private map patched into the spawn index, and
  # Osiris, a real boss in the mob catalog (the coordinator resolves the
  # respawning mob through the catalog, not through the dying instance).
  @respawn_map "boss_integration_respawn"
  @osiris_id 1038
  @respawn_ms 4_000

  setup :set_mimic_private
  setup :verify_on_exit!

  setup_all do
    # `MapManager` starts a real coordinator for every map in the cache, once,
    # shortly after boot. Waiting for it before publishing the respawn map
    # keeps that map coordinator-free, so the respawn test owns its name and
    # its timers.
    await_map_manager(100)

    index_key = Spawns
    _ = Spawns.all()
    index = :persistent_term.get(index_key)

    patched =
      Map.update!(index, :by_map, fn by_map ->
        Map.put(by_map, @respawn_map, [
          %MobSpawn{
            mob: @osiris_id,
            amount: 1,
            respawn_time: @respawn_ms,
            respawn_variance: 0,
            spawn_area: %MobSpawn.SpawnArea{x: 100, y: 100, xs: 0, ys: 0}
          }
        ])
      end)

    :persistent_term.put(index_key, patched)

    :ets.insert(
      EtsTable.table_for(:map_cache),
      {@respawn_map, MapData.new(@respawn_map, 200, 200)}
    )

    on_exit(fn ->
      :persistent_term.put(index_key, index)
      :ets.delete(EtsTable.table_for(:map_cache), @respawn_map)
    end)

    :ok
  end

  setup do
    on_exit(fn -> :persistent_term.erase(BossRespawn) end)
    :ok
  end

  describe "MVP kill to reward loop" do
    test "the top damage dealer, not the killer, receives the MVP exp, drop and announcement" do
      {:ok, %ItemDefinition{id: mvp_nameid}} = Items.by_aegis(@mvp_item)

      [low, mvp, killer] = Enum.map(["BossLow", "BossMvp", "BossKiller"], &start_attacker/1)

      Enum.each([low, mvp, killer], &PubSub.subscribe(Aesir.PubSub, "player:#{&1.character.id}"))
      :ok = ServerPubSub.subscribe_to_announcements()

      boss =
        start_mob_session(
          mob_id: @boss_id,
          map_name: @map,
          position: {150, 151},
          level: @base_level,
          hp: 800,
          max_hp: 800,
          modes: [:boss],
          mvp_exp: @mvp_exp,
          mvp_drops: [%MobDrop{item: @mvp_item, rate: 10_000}]
        )

      damage(boss, low, 100)
      damage(boss, mvp, 500)
      damage(boss, killer, 200)

      assert get_mob_state(boss.pid).is_dead

      # The announcement names the MVP, so it is an identity assertion: the
      # killer dealt the finishing blow but the MVP dealt the most damage.
      assert_receive {:announcement, %AnnouncementMsg{text: text}}, 500
      assert text == "#{mvp.character.name} has defeated TestMob_#{@boss_id}!"

      # Delivery is a supervised task, hence the wider window than the local
      # PubSub assertions above.
      assert_receive {:packet_for, mvp_char_id, %ItemAdded{nameid: ^mvp_nameid}}, 2_000
      assert mvp_char_id == mvp.character.id

      refute_receive {:packet_for, _other, %ItemAdded{nameid: ^mvp_nameid}}, 200

      assert mvp.pid |> get_player_state() |> held_amount(mvp_nameid) == 1
      assert killer.pid |> get_player_state() |> held_amount(mvp_nameid) == 0
      assert low.pid |> get_player_state() |> held_amount(mvp_nameid) == 0

      # MVP experience is base-only and unscaled at an equal level gap, so it
      # is distinguishable from the ordinary damage-share broadcasts every
      # contributor also receives.
      assert collect_mvp_exp_broadcasts() == [{@mvp_exp, 0}]
    end
  end

  describe "boss status immunity" do
    test "a boss rejects externally applied stun, freeze and sleep" do
      attacker = start_attacker("BossCaster")
      boss = start_mob_session(map_name: @map, position: {150, 151}, modes: [:boss])

      assert {:error, :boss_immune} = cast_status(boss, attacker, :sc_stun)
      assert {:error, :immune} = cast_status(boss, attacker, :sc_freeze)
      assert {:error, :boss_immune} = cast_status(boss, attacker, :sc_sleep)

      refute StatusStorage.has_status?(:mob, boss.unit_id, :sc_stun)
      refute StatusStorage.has_status?(:mob, boss.unit_id, :sc_freeze)
      refute StatusStorage.has_status?(:mob, boss.unit_id, :sc_sleep)
    end

    test "the same crowd control lands on a non-boss mob of the same id" do
      attacker = start_attacker("NormalCaster")
      mob = start_mob_session(map_name: @map, position: {150, 151}, modes: [])

      assert :ok = cast_status(mob, attacker, :sc_stun)
      assert :ok = cast_status(mob, attacker, :sc_freeze)
      assert :ok = cast_status(mob, attacker, :sc_sleep)

      assert StatusStorage.has_status?(:mob, mob.unit_id, :sc_stun)
      assert StatusStorage.has_status?(:mob, mob.unit_id, :sc_freeze)
      assert StatusStorage.has_status?(:mob, mob.unit_id, :sc_sleep)
    end

    test "a boss self-buff still applies while external crowd control is rejected" do
      attacker = start_attacker("BuffedFight")
      boss = start_mob_session(map_name: @map, position: {150, 151}, modes: [:boss])

      assert {:error, :boss_immune} = cast_status(boss, attacker, :sc_stun)

      assert :ok = Executor.execute(get_mob_state(boss.pid), self_buff_row())

      assert StatusStorage.has_status?(:mob, boss.unit_id, :sc_increaseagi)
      refute StatusStorage.has_status?(:mob, boss.unit_id, :sc_stun)
    end
  end

  describe "concealment and boss detection" do
    test "a hidden player is invisible to a normal mob and visible to a boss" do
      player = start_attacker("HiddenOne")
      char_id = player.character.id

      normal = start_mob_session(map_name: @map, position: {150, 151}, modes: [:aggressive])
      boss = start_mob_session(map_name: @map, position: {150, 152}, modes: [:aggressive, :boss])

      assert :ok = Interpreter.apply_status(:player, char_id, :sc_hiding, duration: 60_000)
      assert Interpreter.concealed?(:player, char_id)

      assert AIStateMachine.process_ai(idle(normal)).target_id == nil
      assert AIStateMachine.process_ai(idle(boss)).target_id == char_id

      :ok = Interpreter.remove_status(:player, char_id, :sc_hiding)

      assert AIStateMachine.process_ai(idle(normal)).target_id == char_id
    end
  end

  describe "boss respawn across a restart" do
    test "a reconciled boss returns at its original deadline and only once" do
      stub_mob_supervisor()
      claim_coordinator_name(@respawn_map)

      boss =
        start_mob_session(
          mob_id: @osiris_id,
          map_name: @respawn_map,
          position: {100, 100},
          hp: 1,
          max_hp: 1,
          modes: [:boss],
          respawn_time: @respawn_ms
        )

      killer = start_attacker("RespawnKiller", map_name: @respawn_map, position: {100, 101})

      {:ok, before_restart} = Coordinator.init(map_name: @respawn_map)

      damage(boss, killer, 10)
      assert get_mob_state(boss.pid).is_dead

      # The dying session's own cast, delivered for real to the process holding
      # the map's coordinator name.
      assert_receive {:"$gen_cast", {:mob_died, instance_id, _killer} = death}, 1_000
      assert instance_id == boss.unit_id

      died_at = System.monotonic_time(:millisecond)
      {:noreply, before_restart} = Coordinator.handle_cast(death, before_restart)

      assert [%BossRespawnRow{mob_id: @osiris_id}] = Repo.all(BossRespawnRow)

      simulate_restart(before_restart)

      # Real downtime, so a deadline restored from the row is distinguishable
      # from one restarted from scratch at reconcile time.
      Process.sleep(2_500)

      :ok = BossRespawn.reconcile()
      {:ok, after_restart} = Coordinator.init(map_name: @respawn_map)
      {:noreply, after_restart} = first_visit(after_restart)

      # The pending deadline must suppress the map's first spawn, or the boss
      # exists twice: once now and once when the re-armed timer fires.
      assert [] == spawned_mob_ids()
      assert [%BossRespawnRow{}] = Repo.all(BossRespawnRow)

      assert_receive {:respawn_mob, spawn_config}, @respawn_ms
      elapsed = System.monotonic_time(:millisecond) - died_at

      # The original deadline is ~@respawn_ms after the death, minus up to one
      # second: `respawn_at` is a second-granularity column, so the durable
      # deadline is always the truncated one. Restarting the interval from
      # scratch at reconcile time would land at ~6_500ms, far outside this
      # window even after the same truncation.
      assert elapsed >= @respawn_ms - 1_300 and elapsed <= @respawn_ms + 400,
             "boss respawned #{elapsed}ms after death, expected ~#{@respawn_ms}ms"

      {:noreply, _state} = Coordinator.handle_info({:respawn_mob, spawn_config}, after_restart)

      assert [@osiris_id] == spawned_mob_ids()
      assert [] == Repo.all(BossRespawnRow)
    end
  end

  defp await_map_manager(0) do
    raise "MapManager did not finish starting map coordinators"
  end

  defp await_map_manager(attempts) do
    if MapManager.coordinator_status().initialized do
      :ok
    else
      Process.sleep(50)
      await_map_manager(attempts - 1)
    end
  end

  defp start_attacker(name, opts \\ []) do
    character = insert_character(name)

    start_player_session(
      Keyword.merge(
        [
          character: character,
          connection_pid: labeled_connection(character.id),
          map_name: @map,
          position: {150, 150}
        ],
        opts
      )
    )
  end

  defp insert_character(name) do
    unique = System.unique_integer([:positive])

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        userid: "boss_#{unique}",
        user_pass: "password",
        sex: "M",
        email: "boss_#{unique}@example.com"
      })
      |> Repo.insert()

    {:ok, character} =
      %{
        account_id: account.id,
        char_num: 0,
        name: "#{name}#{unique}",
        class: 0,
        base_level: @base_level,
        job_level: 10,
        hp: 500,
        max_hp: 500,
        last_map: @map,
        last_x: 150,
        last_y: 150,
        save_map: @map,
        save_x: 150,
        save_y: 150
      }
      |> Character.new()
      |> Repo.insert()

    character
  end

  # Tags every outbound push with the owning character, so the MVP drop can be
  # attributed to one session rather than to "somebody's" connection.
  defp labeled_connection(char_id) do
    test_pid = self()

    spawn_link(fn -> labeled_loop(test_pid, char_id) end)
  end

  defp labeled_loop(test_pid, char_id) do
    receive do
      {:send, _channel, {_tag, proto}} ->
        send(test_pid, {:packet_for, char_id, proto})
        labeled_loop(test_pid, char_id)

      _other ->
        labeled_loop(test_pid, char_id)
    end
  end

  defp damage(mob, attacker, amount) do
    :ok = MobSession.apply_damage(mob.pid, amount, attacker.character.id)
    _sync = get_mob_state(mob.pid)
    :ok
  end

  defp held_amount(player_state, nameid) do
    player_state.inventory
    |> Map.values()
    |> Enum.filter(&(&1.nameid == nameid))
    |> Enum.map(& &1.amount)
    |> Enum.sum()
  end

  defp collect_mvp_exp_broadcasts(acc \\ []) do
    receive do
      {:mob_kill_exp, @mvp_exp, 0} -> collect_mvp_exp_broadcasts([{@mvp_exp, 0} | acc])
      {:mob_kill_exp, _base, _job} -> collect_mvp_exp_broadcasts(acc)
    after
      200 -> acc
    end
  end

  # An external application: an explicit player caster can never resolve to the
  # boss itself. The resistance roll is forced so the non-boss control case
  # cannot fail on a stat roll instead of on the gate.
  defp cast_status(mob, attacker, status_id) do
    Interpreter.apply_status(:mob, mob.unit_id, status_id,
      caster_id: attacker.character.id,
      source_id: attacker.character.id,
      source_type: :player,
      duration: 30_000,
      resistance_roll: fn _ -> true end
    )
  end

  defp self_buff_row do
    %{skill: "NPC_AGIUP", skill_id: 391, level: 3, target: :self, condition: %{type: :always}}
  end

  defp idle(mob) do
    %MobState{} = state = get_mob_state(mob.pid)

    %MobState{state | ai_state: :idle, target_id: nil}
  end

  defp stub_mob_supervisor do
    test_pid = self()

    stub(MobSupervisor, :start_link, fn _map ->
      {:ok, spawn(fn -> Process.sleep(:infinity) end)}
    end)

    stub(MobSupervisor, :spawn_mob, fn _map, %MobState{} = mob_state, _opts ->
      send(test_pid, {:spawned, mob_state})
      {:ok, spawn(fn -> :ok end)}
    end)

    stub(MobSupervisor, :wake_all_mobs, fn _map -> :ok end)
    :ok
  end

  # Takes over the map's coordinator name so the dying `MobSession`'s
  # `Coordinator.mob_died/3` cast is delivered here instead of being dropped.
  defp claim_coordinator_name(map_name) do
    {:ok, _owner} = Registry.register(Aesir.ZoneServer.MapRegistry, map_name, nil)
    :ok
  end

  # A restart loses every in-memory timer along with the coordinator process;
  # cancelling them keeps the surviving durable row as the only thing that can
  # bring the boss back.
  defp simulate_restart(state) do
    Enum.each(state.respawn_timers, fn {_id, {timer_ref, _config}} ->
      Process.cancel_timer(timer_ref)
    end)

    :persistent_term.erase(BossRespawn)
    :ok
  end

  defp first_visit(state) do
    SpatialIndex.add_player(2_001, 100, 100, state.map_name)
    Coordinator.handle_info(:broadcast_tick, state)
  end

  defp spawned_mob_ids(acc \\ []) do
    receive do
      {:spawned, %MobState{mob_id: mob_id}} -> spawned_mob_ids([mob_id | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end
end
