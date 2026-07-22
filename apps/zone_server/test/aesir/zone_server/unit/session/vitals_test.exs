defmodule Aesir.ZoneServer.Unit.Session.VitalsTest do
  @moduledoc """
  Clamp math and per-field side effects for the shared vitals handler, exercised
  through both real adapters.

  Locks the behaviour the player/mob sessions used to own inline: floor at 0 for
  SP drain, ceiling at max for heal/restore, a non-positive amount is a no-op,
  and each op's wire/persist footprint is exactly the field it touched (SP drain
  never sends an HP `ParamChange` nor persists HP). The mob branch publishes an
  HP broadcast on heal but never commits to the registry, and drains SP silently.
  Dead-unit no-ops are a session-dispatch concern (the guard differs by op/type)
  and are covered by the session tests, not here - Vitals itself never guards.
  """

  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.Commons.StatusParams
  alias Aesir.Net.ParamChange
  alias Aesir.Net.UnitHp
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.SessionFixtures
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Mob.SessionAdapter, as: MobAdapter
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionAdapter, as: PlayerAdapter
  alias Aesir.ZoneServer.Unit.Session.Vitals
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  describe "drain_sp/4 clamp math" do
    test "player floors the drain at 0 rather than going negative" do
      stub_player_commit()
      state = player_state(hp: 100, sp: 5, max_hp: 250, max_sp: 90)

      drained = Vitals.drain_sp(state, 20, PlayerAdapter, commit: true)

      assert PlayerAdapter.get_vitals(drained).sp == 0
    end

    test "mob floors the drain at 0 rather than going negative" do
      state = mob_state(hp: 100, sp: 5, max_hp: 250, max_sp: 90)

      drained = Vitals.drain_sp(state, 20, MobAdapter)

      assert drained.sp == 0
    end

    test "a non-positive drain is a no-op with no side effects" do
      reject(&CharacterPersistence.update_stats/3)
      reject(&UnitRegistry.update_unit_state/3)
      state = player_state(hp: 100, sp: 50, max_hp: 250, max_sp: 90)

      assert Vitals.drain_sp(state, 0, PlayerAdapter, commit: true) == state
      assert Vitals.drain_sp(state, -5, PlayerAdapter, commit: true) == state
      refute_received {:send, _, _}
    end
  end

  describe "restore_sp/4 clamp math" do
    test "player ceils the restore at max_sp" do
      stub_player_commit()
      state = player_state(hp: 100, sp: 80, max_hp: 250, max_sp: 90)

      restored = Vitals.restore_sp(state, 50, PlayerAdapter, commit: true)

      assert PlayerAdapter.get_vitals(restored).sp == 90
    end

    test "a non-positive restore is a no-op" do
      state = player_state(hp: 100, sp: 50, max_hp: 250, max_sp: 90)

      assert Vitals.restore_sp(state, 0, PlayerAdapter, commit: true) == state
      refute_received {:send, _, _}
    end
  end

  describe "heal/4 clamp math" do
    test "mob ceils the heal at max_hp" do
      stub_mob_broadcast()
      state = mob_state(hp: 240, sp: 5, max_hp: 250, max_sp: 90)

      healed = Vitals.heal(state, 50, MobAdapter)

      assert healed.hp == 250
    end

    test "a non-positive heal is a no-op" do
      reject(&Broadcast.to_in_range/5)
      state = mob_state(hp: 100, sp: 5, max_hp: 250, max_sp: 90)

      assert Vitals.heal(state, 0, MobAdapter) == state
    end
  end

  describe "per-field wire/persist footprint" do
    test "player SP drain sends only the SP ParamChange and persists only sp" do
      test_pid = self()

      stub(UnitRegistry, :update_unit_state, fn _, _, _ -> :ok end)

      expect(CharacterPersistence, :update_stats, fn 1, stats, opts ->
        send(test_pid, {:persist, stats, opts})
        :ok
      end)

      state = player_state(hp: 100, sp: 50, max_hp: 250, max_sp: 90)

      Vitals.drain_sp(state, 10, PlayerAdapter, commit: true)

      sp_id = StatusParams.sp()
      hp_id = StatusParams.hp()
      assert_received {:send, _channel, {_tag, %ParamChange{var_id: ^sp_id, value: 40}}}
      refute_received {:send, _channel, {_tag, %ParamChange{var_id: ^hp_id}}}
      assert_received {:persist, persisted, [async: true]}
      assert persisted == %{sp: 40}
    end

    test "mob SP drain sends nothing and never commits to the registry" do
      reject(&Broadcast.to_in_range/5)
      reject(&UnitRegistry.update_unit_state/3)
      state = mob_state(hp: 100, sp: 50, max_hp: 250, max_sp: 90)

      drained = Vitals.drain_sp(state, 10, MobAdapter)

      assert drained.sp == 40
    end

    test "mob heal broadcasts a UnitHp and never commits to the registry" do
      reject(&UnitRegistry.update_unit_state/3)
      test_pid = self()

      expect(Broadcast, :to_in_range, fn "prontera", 150, 150, _range, packet ->
        send(test_pid, {:broadcast, packet})
        :ok
      end)

      state = mob_state(hp: 100, sp: 5, max_hp: 250, max_sp: 90)

      Vitals.heal(state, 30, MobAdapter)

      assert_received {:broadcast, %UnitHp{id: 9001, hp: 130, max_hp: 250}}
    end
  end

  describe "can_pay_sp?/3" do
    test "true only when the unit holds at least the amount" do
      state = mob_state(hp: 100, sp: 10, max_hp: 250, max_sp: 90)

      assert Vitals.can_pay_sp?(state, MobAdapter, 10)
      refute Vitals.can_pay_sp?(state, MobAdapter, 11)
    end
  end

  # Helpers ------------------------------------------------------------------

  defp stub_player_commit do
    stub(UnitRegistry, :update_unit_state, fn _, _, _ -> :ok end)
    stub(CharacterPersistence, :update_stats, fn _, _, _ -> :ok end)
  end

  defp stub_mob_broadcast do
    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)
  end

  defp player_state(overrides) do
    game_state = PlayerState.new(SessionFixtures.character(name: "Vitals"))
    stats = game_state.stats

    current_state = %{
      stats.current_state
      | hp: Keyword.fetch!(overrides, :hp),
        sp: Keyword.fetch!(overrides, :sp)
    }

    derived_stats = %{
      stats.derived_stats
      | max_hp: Keyword.fetch!(overrides, :max_hp),
        max_sp: Keyword.fetch!(overrides, :max_sp)
    }

    game_state = %{
      game_state
      | stats: %{stats | current_state: current_state, derived_stats: derived_stats}
    }

    %{game_state: game_state, connection_pid: self()}
  end

  defp mob_state(overrides) do
    %MobState{
      instance_id: 9001,
      mob_id: 1002,
      mob_data: SessionFixtures.mob_definition(),
      spawn_ref: SessionFixtures.mob_spawn(),
      x: 150,
      y: 150,
      map_name: "prontera",
      hp: Keyword.fetch!(overrides, :hp),
      max_hp: Keyword.fetch!(overrides, :max_hp),
      sp: Keyword.fetch!(overrides, :sp),
      max_sp: Keyword.fetch!(overrides, :max_sp),
      spawned_at: System.system_time(:second)
    }
  end
end
