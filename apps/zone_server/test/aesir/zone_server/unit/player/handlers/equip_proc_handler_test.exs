defmodule Aesir.ZoneServer.Unit.Player.Handlers.EquipProcHandlerTest do
  use ExUnit.Case, async: true
  use Mimic

  import ExUnit.CaptureLog

  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Commons.StatusParams
  alias Aesir.Net.ParamChange
  alias Aesir.Net.SkillList
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.Handlers.EquipProcHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.StatusSync
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @key {101, 0}

  setup :verify_on_exit!
  setup :set_mimic_from_context

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})
    :ok
  end

  test "activation installs the generation before one stat calculation and sync" do
    state = state_with_registration()
    test_pid = self()

    expect(Stats, :calculate_stats, fn stats, 1 ->
      send(test_pid, {:calculated, stats.active_autobonuses})
      put_in(stats.combat_stats.atk, stats.combat_stats.atk + 25)
    end)

    expect(UnitRegistry, :update_unit_state, fn :player, 1, _game_state -> :ok end)

    expect(StatusSync, :send_stat_updates, fn _connection_pid, stats ->
      send(test_pid, {:synced, stats.active_autobonuses})
      :ok
    end)

    assert {:noreply, updated} = activate(state, @key)
    assert %{@key => token} = updated.game_state.stats.active_autobonuses
    assert is_integer(token) and token > 0
    assert_receive {:calculated, %{@key => ^token}}
    assert_receive {:synced, %{@key => ^token}}
    refute_receive {:send, _channel, {:skill_list, %SkillList{}}}
  end

  test "retrigger refreshes generation and only the current expiry removes it" do
    state = state_with_registration()
    test_pid = self()

    stub(Stats, :calculate_stats, fn stats, 1 ->
      send(test_pid, :calculated)
      put_in(stats.combat_stats.atk, stats.combat_stats.atk + 1)
    end)

    stub(UnitRegistry, :update_unit_state, fn :player, 1, _game_state ->
      send(test_pid, :committed)
      :ok
    end)

    stub(StatusSync, :send_stat_updates, fn _connection_pid, _stats ->
      send(test_pid, :synced)
      :ok
    end)

    {:noreply, first} = activate(state, @key)
    first_token = first.game_state.stats.active_autobonuses[@key]
    {:noreply, refreshed} = activate(first, @key)
    refreshed_token = refreshed.game_state.stats.active_autobonuses[@key]

    assert refreshed_token != first_token
    assert {:noreply, ^refreshed} = EquipProcHandler.expire(refreshed, @key, first_token)

    assert {:noreply, expired} = EquipProcHandler.expire(refreshed, @key, refreshed_token)
    assert expired.game_state.stats.active_autobonuses == %{}
    assert mailbox_count(:calculated) == 3
    assert mailbox_count(:committed) == 3
    assert mailbox_count(:synced) == 3
    refute_receive {:send, _channel, {:skill_list, %SkillList{}}}
  end

  test "activation applies primary then secondary status effects in source order" do
    registration = %{
      registration()
      | primary_effects: [
          {:status_start, :sc_summer, 3_000, 7},
          {:status_end, :sc_summer}
        ],
        secondary_effects: [{:status_start, :sc_strangelights, :infinite, 9}]
    }

    state = state_with_registration(registration)
    test_pid = self()

    expect(Interpreter, :apply_status, fn :player, 1, :sc_summer, params ->
      send(test_pid, {:effect, :start_summer, params})
      :ok
    end)

    expect(Interpreter, :remove_status, fn :player, 1, :sc_summer, opts ->
      send(test_pid, {:effect, :end_summer, opts})
      :ok
    end)

    expect(Interpreter, :apply_status, fn :player, 1, :sc_strangelights, params ->
      send(test_pid, {:effect, :start_lights, params})
      :ok
    end)

    stub(Stats, :calculate_stats, fn stats, 1 -> stats end)
    stub(UnitRegistry, :update_unit_state, fn :player, 1, _game_state -> :ok end)
    stub(StatusSync, :send_stat_updates, fn _connection_pid, _stats -> :ok end)

    assert {:noreply, _updated} = activate(state, @key)

    assert_receive {:effect, :start_summer, start_params}
    assert start_params[:caster_id] == 1
    assert start_params[:duration] == 3_000
    assert start_params[:val1] == 7
    assert start_params[:owner_refresh] == :defer

    assert_receive {:effect, :end_summer, [owner_refresh: :defer]}
    assert_receive {:effect, :start_lights, lights_params}
    assert lights_params[:caster_id] == 1
    assert lights_params[:val1] == 9
    refute Keyword.has_key?(lights_params, :duration)
  end

  test "activation applies signed heal effects in source order" do
    registration = %{
      registration()
      | primary_effects: [{:heal, 0, 20}],
        secondary_effects: [{:heal, 0, -5}]
    }

    state = state_with_registration(registration)
    state = put_in(state.game_state.stats.current_state.sp, 10)
    state = put_in(state.game_state.stats.derived_stats.max_sp, 100)

    stub(CharacterPersistence, :update_stats, fn _character_id, _attrs, _opts -> {:ok, nil} end)
    stub(Stats, :calculate_stats, fn stats, 1 -> stats end)
    stub(UnitRegistry, :update_unit_state, fn :player, 1, _game_state -> :ok end)
    stub(StatusSync, :send_stat_updates, fn _connection_pid, _stats -> :ok end)

    assert {:noreply, updated} = activate(state, @key)
    assert updated.game_state.stats.current_state.sp == 25
  end

  test "rejected status effects log context without rolling back the active modifier" do
    registration = %{
      registration()
      | primary_effects: [{:status_start, :sc_unknown_equip_proc, 1_000, 1}]
    }

    state = state_with_registration(registration)

    expect(Interpreter, :apply_status, fn :player, 1, :sc_unknown_equip_proc, _params ->
      {:error, :unknown_status}
    end)

    expect(Stats, :calculate_stats, fn stats, 1 ->
      put_in(stats.combat_stats.atk, stats.combat_stats.atk + 25)
    end)

    stub(UnitRegistry, :update_unit_state, fn :player, 1, _game_state -> :ok end)
    stub(StatusSync, :send_stat_updates, fn _connection_pid, _stats -> :ok end)

    log =
      capture_log(fn ->
        assert {:noreply, updated} = activate(state, @key)
        assert %{@key => token} = updated.game_state.stats.active_autobonuses
        assert is_integer(token) and token > 0

        assert updated.game_state.stats.combat_stats.atk ==
                 state.game_state.stats.combat_stats.atk + 25
      end)

    assert log =~ "item 501"
    assert log =~ "primary proc key {101, 0}"
    assert log =~ "unknown_status"
  end

  test "direct status reconciliation applies, changes, and removes owned statuses" do
    state = state_with_equip_statuses(%{sc_summer: {:infinite, 1}})
    :ok = UnitRegistry.register_player(state.game_state, self())

    test_pid = self()

    stub(Stats, :calculate_stats, fn stats, 1 ->
      send(test_pid, :status_recalculated)
      put_in(stats.combat_stats.atk, stats.combat_stats.atk + 1)
    end)

    stub(StatusSync, :send_stat_updates, fn _connection_pid, _stats -> :ok end)

    assert {:noreply, applied} = EquipProcHandler.reconcile_statuses(state)
    assert applied.applied_equip_statuses == %{sc_summer: {:infinite, 1}}
    assert StatusStorage.get_status(:player, 1, :sc_summer).val1 == 1

    changed =
      put_in(
        applied,
        [Access.key!(:game_state), Access.key!(:stats), Access.key!(:equip_statuses)],
        %{sc_summer: {:infinite, 2}}
      )

    assert {:noreply, reapplied} = EquipProcHandler.reconcile_statuses(changed)
    assert reapplied.applied_equip_statuses == %{sc_summer: {:infinite, 2}}
    assert StatusStorage.get_status(:player, 1, :sc_summer).val1 == 2

    removed =
      put_in(
        reapplied,
        [Access.key!(:game_state), Access.key!(:stats), Access.key!(:equip_statuses)],
        %{}
      )

    assert {:noreply, reconciled} = EquipProcHandler.reconcile_statuses(removed)
    assert reconciled.applied_equip_statuses == %{}
    refute StatusStorage.has_status?(:player, 1, :sc_summer)
    assert mailbox_count(:status_recalculated) == 3
  end

  test "unchanged desired statuses are removed and rebuilt from scratch" do
    state = state_with_equip_statuses(%{sc_summer: {:infinite, 1}})
    state = %{state | applied_equip_statuses: %{sc_summer: {:infinite, 1}}}
    test_pid = self()

    expect(Interpreter, :remove_status, fn :player, 1, :sc_summer, owner_refresh: :defer ->
      send(test_pid, :removed)
      :ok
    end)

    expect(Interpreter, :apply_status, fn :player, 1, :sc_summer, params ->
      send(test_pid, {:applied, params})
      :ok
    end)

    expect(Stats, :calculate_stats, fn stats, 1 ->
      send(test_pid, :recalculated)
      stats
    end)

    stub(UnitRegistry, :update_unit_state, fn :player, 1, _game_state -> :ok end)
    stub(StatusSync, :send_stat_updates, fn _connection_pid, _stats -> :ok end)

    assert {:noreply, rebuilt} = EquipProcHandler.reconcile_statuses(state)
    assert rebuilt.applied_equip_statuses == %{sc_summer: {:infinite, 1}}
    assert_receive :removed
    assert_receive {:applied, params}
    assert params[:owner_refresh] == :defer
    assert_receive :recalculated
  end

  test "login adopts card cleanup sources without executing them" do
    cleanup = %{{101, 0} => %{source_order: {0, 0}, effects: [{:heal, 0, 20}]}}
    state = state_with_equip_statuses(%{})
    state = put_in(state.game_state.stats.card_unequip_effects, cleanup)

    reject(&CharacterPersistence.update_stats/3)
    stub(Stats, :calculate_stats, fn stats, 1 -> stats end)
    stub(UnitRegistry, :update_unit_state, fn :player, 1, _game_state -> :ok end)
    stub(StatusSync, :send_stat_updates, fn _connection_pid, _stats -> :ok end)

    assert {:noreply, adopted} = EquipProcHandler.reconcile_statuses(state)
    assert adopted.applied_card_unequip_effects == cleanup
    assert adopted.game_state.stats.current_state.sp == state.game_state.stats.current_state.sp
  end

  test "removed card cleanup sources execute once in their previous source order" do
    state = state_with_equip_statuses(%{})

    previous = %{
      {101, 1} => %{source_order: {0, 1}, effects: [{:status_end, :sc_summer}]},
      {202, 0} => %{source_order: {1, 0}, effects: [{:status_end, :sc_strangelights}]},
      {101, 0} => %{source_order: {0, 0}, effects: [{:status_end, :sc_blessing}]}
    }

    current = Map.take(previous, [{202, 0}])

    state = %{
      state
      | applied_card_unequip_effects: previous,
        game_state: %{
          state.game_state
          | stats: %{state.game_state.stats | card_unequip_effects: current}
        }
    }

    test_pid = self()

    expect(Interpreter, :remove_status, 2, fn :player, 1, status, owner_refresh: :defer ->
      send(test_pid, {:cleanup, status})
      :ok
    end)

    stub(Stats, :calculate_stats, fn stats, 1 -> stats end)
    stub(UnitRegistry, :update_unit_state, fn :player, 1, _game_state -> :ok end)
    stub(StatusSync, :send_stat_updates, fn _connection_pid, _stats -> :ok end)

    assert {:noreply, reconciled} = EquipProcHandler.reconcile_statuses(state)
    assert_receive {:cleanup, :sc_blessing}
    assert_receive {:cleanup, :sc_summer}
    assert reconciled.applied_card_unequip_effects == current

    assert {:noreply, repeated} = EquipProcHandler.reconcile_statuses(reconciled)
    assert repeated.applied_card_unequip_effects == current
    refute_receive {:cleanup, _status}
  end

  test "full rebuild preserves statuses not owned by equipment" do
    state = state_with_equip_statuses(%{sc_summer: {:infinite, 1}})
    state = %{state | applied_equip_statuses: %{sc_summer: {:infinite, 1}}}
    :ok = UnitRegistry.register_player(state.game_state, self())

    assert :ok =
             Interpreter.apply_status(:player, 1, :sc_strangelights,
               caster_id: 1,
               duration: 30_000,
               owner_refresh: :defer
             )

    stub(Stats, :calculate_stats, fn stats, 1 -> stats end)
    stub(StatusSync, :send_stat_updates, fn _connection_pid, _stats -> :ok end)

    assert {:noreply, rebuilt} = EquipProcHandler.reconcile_statuses(state)
    assert rebuilt.applied_equip_statuses == %{sc_summer: {:infinite, 1}}
    assert StatusStorage.has_status?(:player, 1, :sc_summer)
    assert StatusStorage.has_status?(:player, 1, :sc_strangelights)
  end

  test "duplicate providers rebuild the one remaining desired status" do
    state = state_with_equip_statuses(%{sc_summer: {:infinite, 7}})
    state = %{state | applied_equip_statuses: %{sc_summer: {:infinite, 7}}}
    :ok = UnitRegistry.register_player(state.game_state, self())

    assert :ok =
             Interpreter.apply_status(:player, 1, :sc_summer,
               caster_id: 1,
               val1: 7,
               owner_refresh: :defer
             )

    stub(Stats, :calculate_stats, fn stats, 1 -> stats end)
    stub(StatusSync, :send_stat_updates, fn _connection_pid, _stats -> :ok end)

    assert {:noreply, rebuilt} = EquipProcHandler.reconcile_statuses(state)
    assert StatusStorage.get_status(:player, 1, :sc_summer).val1 == 7
    assert rebuilt.applied_equip_statuses == %{sc_summer: {:infinite, 7}}
  end

  test "status rebuild resends the skill list when recalculation changes granted skills" do
    state = state_with_equip_statuses(%{})
    state = put_in(state.game_state.stats.granted_skills, %{28 => 3})

    expect(Stats, :calculate_stats, fn stats, 1 -> %{stats | granted_skills: %{}} end)
    stub(UnitRegistry, :update_unit_state, fn :player, 1, _game_state -> :ok end)
    stub(StatusSync, :send_stat_updates, fn _connection_pid, _stats -> :ok end)

    assert {:noreply, rebuilt} = EquipProcHandler.reconcile_statuses(state)
    assert rebuilt.game_state.stats.granted_skills == %{}
    assert_receive {:send, _channel, {:skill_list, %SkillList{}}}
  end

  test "failed status applications log without crashing the reconcile" do
    state = state_with_equip_statuses(%{sc_unknown_equip_status: {1_000, 3}})

    expect(Interpreter, :apply_status, fn
      :player, 1, :sc_unknown_equip_status, _params -> {:error, :unknown_status}
    end)

    stub(Stats, :calculate_stats, fn stats, 1 -> stats end)
    stub(UnitRegistry, :update_unit_state, fn :player, 1, _game_state -> :ok end)
    stub(StatusSync, :send_stat_updates, fn _connection_pid, _stats -> :ok end)

    log =
      capture_log(fn ->
        assert {:noreply, reconciled} = EquipProcHandler.reconcile_statuses(state)
        assert reconciled.applied_equip_statuses == %{sc_unknown_equip_status: {1_000, 3}}
      end)

    assert log =~ "Equipment status sc_unknown_equip_status rejected for player 1"
    assert log =~ "unknown_status"
  end

  test "Blessing consumed curing Curse leaves no status and still recalculates once" do
    state = state_with_equip_statuses(%{sc_blessing: {30_000, 3}})
    :ok = UnitRegistry.register_player(state.game_state, self())
    test_pid = self()

    assert :ok =
             Interpreter.apply_status(:player, 1, :sc_curse,
               caster_id: 1,
               duration: 30_000,
               bypass_resistance: true,
               owner_refresh: :defer
             )

    stub(Stats, :calculate_stats, fn stats, 1 ->
      send(test_pid, :status_recalculated)
      stats
    end)

    stub(StatusSync, :send_stat_updates, fn _connection_pid, _stats -> :ok end)

    assert {:noreply, reconciled} = EquipProcHandler.reconcile_statuses(state)
    assert reconciled.applied_equip_statuses == %{sc_blessing: {30_000, 3}}
    refute StatusStorage.has_status?(:player, 1, :sc_blessing)
    refute StatusStorage.has_status?(:player, 1, :sc_curse)
    assert mailbox_count(:status_recalculated) == 1
  end

  test "queued activation is a no-op when an earlier card disappears and its key shifts" do
    autobonus = fn bonus ->
      {:autobonus,
       %{trigger: :attack, battle_flag: 0, primary: [{:bonus, :atk, bonus}], secondary: []},
       1_000, 10_000}
    end

    host = %ItemDefinition{
      id: 90_100,
      aegis_name: "SHIFT_HOST",
      name: "Shift Host",
      type: :armor,
      slots: 2
    }

    earlier = %ItemDefinition{
      id: 90_101,
      aegis_name: "EARLIER_CARD",
      name: "Earlier Card",
      type: :card,
      on_equip: [autobonus.(10)]
    }

    later = %ItemDefinition{
      id: 90_102,
      aegis_name: "LATER_CARD",
      name: "Later Card",
      type: :card,
      on_equip: [autobonus.(20)]
    }

    stub(ItemManagement, :get_item_by_id, fn
      90_100 -> {:ok, host}
      90_101 -> {:ok, earlier}
      90_102 -> {:ok, later}
    end)

    row = %InventoryItem{
      id: 101,
      nameid: 90_100,
      amount: 1,
      equip: 16,
      identify: 1,
      card0: 90_101,
      card1: 90_102
    }

    game_state = PlayerState.new(character())
    initial_stats = Stats.calculate_stats(game_state.stats, 1, [row])
    queued_identity = initial_stats.equip_autobonuses[@key].source_identity
    shifted_stats = Stats.calculate_stats(initial_stats, 1, [%{row | card0: 0}])

    state = %SessionState{
      connection_pid: self(),
      game_state: %{game_state | stats: shifted_stats}
    }

    assert shifted_stats.equip_autobonuses[@key].source_identity == {:card, 1, 90_102}
    assert queued_identity == {:card, 0, 90_101}

    reject(&Stats.calculate_stats/2)
    reject(&StatusSync.send_stat_updates/2)
    reject(&UnitRegistry.update_unit_state/3)
    reject(&Interpreter.apply_status/4)
    reject(&Interpreter.remove_status/4)

    assert {:noreply, ^state} = EquipProcHandler.activate(state, @key, queued_identity)
  end

  test "missing registrations and source-removed expiries are exact no-ops" do
    state = state_with_equip_statuses(%{})

    reject(&Stats.calculate_stats/2)
    reject(&StatusSync.send_stat_updates/2)
    reject(&UnitRegistry.update_unit_state/3)
    reject(&Interpreter.apply_status/4)
    reject(&Interpreter.remove_status/4)

    assert {:noreply, ^state} = EquipProcHandler.activate(state, @key, {:card, 0, 501})

    source_removed =
      put_in(
        state,
        [Access.key!(:game_state), Access.key!(:stats), Access.key!(:active_autobonuses)],
        %{@key => 4}
      )

    assert {:noreply, ^source_removed} = EquipProcHandler.expire(source_removed, @key, 4)
  end

  test "primary modifier remains active until the current expiry" do
    state = state_with_registration()
    base_atk = state.game_state.stats.combat_stats.atk

    stub(Stats, :calculate_stats, fn stats, 1 ->
      bonus = if Map.has_key?(stats.active_autobonuses, @key), do: 25, else: 0
      put_in(stats.combat_stats.atk, base_atk + bonus)
    end)

    stub(UnitRegistry, :update_unit_state, fn :player, 1, _game_state -> :ok end)
    stub(StatusSync, :send_stat_updates, fn _connection_pid, _stats -> :ok end)

    assert {:noreply, active} = activate(state, @key)
    assert active.game_state.stats.combat_stats.atk == base_atk + 25
    token = active.game_state.stats.active_autobonuses[@key]

    assert {:noreply, expired} = EquipProcHandler.expire(active, @key, token)
    assert expired.game_state.stats.combat_stats.atk == base_atk
  end

  test "activation schedules the generation-tagged expiry message" do
    registration = %{registration() | duration_ms: 1}
    state = state_with_registration(registration)

    stub(Stats, :calculate_stats, fn stats, 1 -> stats end)
    stub(UnitRegistry, :update_unit_state, fn :player, 1, _game_state -> :ok end)
    stub(StatusSync, :send_stat_updates, fn _connection_pid, _stats -> :ok end)

    assert {:noreply, active} = activate(state, @key)
    token = active.game_state.stats.active_autobonuses[@key]
    assert_receive {:equip_autobonus_expire, @key, ^token}
  end

  test "an old expiry cannot remove a re-equipped activation with the same persistent key" do
    {state, row} = state_with_real_proc([{:bonus, :atk, 25}])
    :ok = UnitRegistry.register_player(state.game_state, self())

    {:noreply, first} = activate(state, @key)
    old_token = first.game_state.stats.active_autobonuses[@key]

    pruned_stats = Stats.calculate_stats(first.game_state.stats, 1, [])
    rederived_stats = Stats.calculate_stats(pruned_stats, 1, [row])
    reequipped = %{first | game_state: %{first.game_state | stats: rederived_stats}}

    {:noreply, current} = activate(reequipped, @key)
    current_token = current.game_state.stats.active_autobonuses[@key]

    assert current_token != old_token
    assert {:noreply, ^current} = EquipProcHandler.expire(current, @key, old_token)
    assert current.game_state.stats.active_autobonuses == %{@key => current_token}
  end

  test "a primary movement-speed modifier updates state and the client on activation and expiry" do
    {state, _row} = state_with_real_proc([{:bonus, :movement_speed, 25}])
    :ok = UnitRegistry.register_player(state.game_state, self())

    assert state.game_state.walk_speed == 150
    assert {:noreply, active} = activate(state, @key)
    assert active.game_state.walk_speed == 112

    speed_param = StatusParams.speed()

    assert_receive {:send, _channel,
                    {:param_change, %ParamChange{var_id: ^speed_param, value: 112}}}

    token = active.game_state.stats.active_autobonuses[@key]
    assert {:noreply, expired} = EquipProcHandler.expire(active, @key, token)
    assert expired.game_state.walk_speed == 150

    assert_receive {:send, _channel,
                    {:param_change, %ParamChange{var_id: ^speed_param, value: 150}}}
  end

  test "activation and expiry resend the skill list only when granted skills change" do
    {state, _row} = state_with_real_proc([{:grant_skill, 28, 3}])
    :ok = UnitRegistry.register_player(state.game_state, self())

    assert state.game_state.stats.granted_skills == %{}
    assert {:noreply, active} = activate(state, @key)
    assert active.game_state.stats.granted_skills == %{28 => 3}
    assert_receive {:send, _channel, {:skill_list, %SkillList{}}}

    token = active.game_state.stats.active_autobonuses[@key]
    assert {:noreply, expired} = EquipProcHandler.expire(active, @key, token)
    assert expired.game_state.stats.granted_skills == %{}
    assert_receive {:send, _channel, {:skill_list, %SkillList{}}}

    assert {:noreply, ^expired} = EquipProcHandler.expire(expired, @key, token)
    refute_receive {:send, _channel, {:skill_list, %SkillList{}}}
  end

  defp state_with_registration(registration \\ registration()) do
    game_state = PlayerState.new(character())

    %SessionState{
      connection_pid: self(),
      game_state: %{
        game_state
        | stats: %{game_state.stats | equip_autobonuses: %{@key => registration}}
      }
    }
  end

  defp state_with_equip_statuses(equip_statuses) do
    game_state = PlayerState.new(character())

    %SessionState{
      connection_pid: self(),
      game_state: %{game_state | stats: %{game_state.stats | equip_statuses: equip_statuses}}
    }
  end

  defp state_with_real_proc(primary) do
    item_id = 90_001

    item = %ItemDefinition{
      id: item_id,
      aegis_name: "PROC_TEST_ITEM",
      name: "Proc Test Item",
      on_equip: [
        {:autobonus, %{trigger: :attack, battle_flag: 0, primary: primary, secondary: []}, 1_000,
         60_000}
      ]
    }

    stub(ItemManagement, :get_item_by_id, fn ^item_id -> {:ok, item} end)

    row = %InventoryItem{id: 101, nameid: item_id, amount: 1, equip: 16, identify: 1}
    game_state = PlayerState.new(character())
    stats = Stats.calculate_stats(game_state.stats, game_state.character_id, [row])

    {%SessionState{connection_pid: self(), game_state: %{game_state | stats: stats}}, row}
  end

  defp activate(state, key) do
    source_identity = state.game_state.stats.equip_autobonuses[key].source_identity
    EquipProcHandler.activate(state, key, source_identity)
  end

  defp mailbox_count(message) do
    {:messages, messages} = Process.info(self(), :messages)
    Enum.count(messages, &(&1 == message))
  end

  defp registration do
    %{
      item_id: 501,
      source_identity: {:card, 0, 501},
      refine: 0,
      source_order: {0, 0},
      trigger: :attack,
      rate: 1_000,
      duration_ms: 60_000,
      battle_flag: 0,
      primary: [],
      secondary: [],
      primary_effects: [],
      secondary_effects: []
    }
  end

  defp character do
    %Character{
      id: 1,
      account_id: 2,
      name: "ProcOwner",
      last_map: "prontera",
      last_x: 50,
      last_y: 50,
      sex: "M",
      str: 10,
      agi: 10,
      vit: 10,
      int: 10,
      dex: 10,
      luk: 10,
      base_level: 99,
      job_level: 50,
      class: 1
    }
  end
end
