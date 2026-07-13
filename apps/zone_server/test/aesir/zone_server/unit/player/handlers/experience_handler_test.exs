defmodule Aesir.ZoneServer.Unit.Player.Handlers.ExperienceHandlerTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.Commons.StatusParams
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Mmo.Leveling
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Party.Manager
  alias Aesir.ZoneServer.Party.Member
  alias Aesir.ZoneServer.Unit.Player.Handlers.ExperienceHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.StatusSync
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  setup do
    stub(Stats, :calculate_stats, fn stats, _char_id -> stats end)
    stub(UnitRegistry, :update_unit_state, fn :player, _id, _gs -> :ok end)
    stub(CharacterPersistence, :update_character, fn _id, _attrs, async: true -> {:ok, %{}} end)
    stub(StatusSync, :send_stat_updates, fn _pid, _stats -> :ok end)
    stub(StatusSync, :send_params, fn _pid, _params -> :ok end)
    stub(Leveling, :next_base_exp, fn _progression -> 0 end)
    stub(Leveling, :next_job_exp, fn _progression -> 0 end)

    :ok
  end

  # Captures the (already-boosted) base/job amounts the handler forwards to
  # Leveling, without engaging the real level-up math or job DB.
  defp capture_grant(modifiers) do
    test_pid = self()

    stub(ModifierCalculator, :get_all_modifiers, fn :player, 1000 -> modifiers end)

    stub(Leveling, :apply_exp, fn progression, base, job ->
      send(test_pid, {:granted, base, job})
      {progression, 0, 0}
    end)

    ExperienceHandler.handle_gain_exp(100, 100, state())

    assert_received {:granted, base, job}
    {base, job}
  end

  defp state do
    base = PlayerState.new(character())
    game_state = %{base | character_id: 1000}
    %{connection_pid: self(), game_state: game_state}
  end

  defp state_with(progression_overrides) do
    base = PlayerState.new(character())
    progression = struct(base.stats.progression, progression_overrides)
    game_state = %{base | character_id: 1000, stats: %{base.stats | progression: progression}}
    %{connection_pid: self(), game_state: game_state}
  end

  defp character do
    %Aesir.Commons.Models.Character{
      id: 1000,
      account_id: 2000,
      name: "Grinder",
      last_map: "prontera",
      last_x: 150,
      last_y: 150,
      sex: "M",
      str: 1,
      agi: 1,
      vit: 1,
      int: 1,
      dex: 1,
      luk: 1,
      base_level: 50,
      job_level: 50,
      class: 1
    }
  end

  describe "handle_gain_exp/3 EXP-rate boost" do
    test "exp_rate boosts both base and job by the same percent" do
      assert {150, 150} == capture_grant(%{exp_rate: 50})
    end

    test "job_exp_rate stacks onto job only, on top of exp_rate" do
      assert {150, 170} == capture_grant(%{exp_rate: 50, job_exp_rate: 20})
    end

    test "job_exp_rate alone leaves base untouched" do
      assert {100, 130} == capture_grant(%{job_exp_rate: 30})
    end

    test "absent keys are an identity transform" do
      assert {100, 100} == capture_grant(%{})
    end

    test "a positive grant never floors to zero under a full reduction" do
      assert {1, 1} == capture_grant(%{exp_rate: -100})
    end
  end

  describe "handle_gain_exp/3 trait-point grant" do
    defp stub_level_up(from_level, to_level) do
      stub(ModifierCalculator, :get_all_modifiers, fn :player, 1000 -> %{} end)

      stub(Leveling, :apply_exp, fn progression, _base, _job ->
        {%{progression | base_level: to_level}, to_level - from_level, 0}
      end)

      state_with(base_level: from_level)
    end

    test "leveling 200 -> 201 grants +3 trait points" do
      {:noreply, new_state} =
        ExperienceHandler.handle_gain_exp(100, 0, stub_level_up(200, 201))

      assert new_state.game_state.stats.progression.trait_point == 3
    end

    test "leveling 204 -> 205 grants +7 trait points" do
      {:noreply, new_state} =
        ExperienceHandler.handle_gain_exp(100, 0, stub_level_up(204, 205))

      assert new_state.game_state.stats.progression.trait_point == 0 + 7
    end

    test "leveling below 201 grants 0 trait points" do
      {:noreply, new_state} =
        ExperienceHandler.handle_gain_exp(100, 0, stub_level_up(50, 51))

      assert new_state.game_state.stats.progression.trait_point == 0
    end

    test "a non-4th-job character gains 0 trait points across a level-up" do
      {:noreply, new_state} =
        ExperienceHandler.handle_gain_exp(100, 0, stub_level_up(90, 99))

      assert new_state.game_state.stats.progression.trait_point == 0
    end

    test "trait_point is persisted" do
      test_pid = self()

      stub(CharacterPersistence, :update_character, fn 1000, attrs, async: true ->
        send(test_pid, {:persisted, attrs})
        {:ok, %{}}
      end)

      {:noreply, new_state} =
        ExperienceHandler.handle_gain_exp(100, 0, stub_level_up(200, 201))

      stats = new_state.game_state.stats
      assert_received {:persisted, attrs}

      assert attrs == %{
               base_level: stats.progression.base_level,
               job_level: stats.progression.job_level,
               base_exp: stats.progression.base_exp,
               job_exp: stats.progression.job_exp,
               hp: stats.current_state.hp,
               max_hp: stats.derived_stats.max_hp,
               sp: stats.current_state.sp,
               max_sp: stats.derived_stats.max_sp,
               ap: stats.current_state.ap,
               max_ap: stats.derived_stats.max_ap,
               skill_point: stats.progression.skill_point,
               status_point: stats.progression.status_point,
               trait_point: 3
             }
    end

    test "trait_point is synced" do
      test_pid = self()

      stub(StatusSync, :send_params, fn _pid, params ->
        send(test_pid, {:synced, params})
        :ok
      end)

      ExperienceHandler.handle_gain_exp(100, 0, stub_level_up(200, 201))

      trait_point = StatusParams.trait_point()
      assert_received {:synced, %{^trait_point => 3}}
    end

    test "publishes the final healed party snapshot after a base level gain" do
      state = stub_level_up(50, 51)
      game_state = %{state.game_state | party_id: 7}
      state = %{state | game_state: game_state}

      expect(Manager, :sync_member, fn 7, 1000, member ->
        assert member == %Member{
                 char_id: 1000,
                 name: "Grinder",
                 job_id: 1,
                 base_level: 51,
                 hp: game_state.stats.derived_stats.max_hp,
                 max_hp: game_state.stats.derived_stats.max_hp,
                 sp: game_state.stats.derived_stats.max_sp,
                 max_sp: game_state.stats.derived_stats.max_sp,
                 ap: game_state.stats.current_state.ap,
                 max_ap: game_state.stats.derived_stats.max_ap,
                 online: true,
                 map_name: "prontera"
               }

        {:ok, %{}}
      end)

      assert {:noreply, _new_state} = ExperienceHandler.handle_gain_exp(100, 0, state)
    end
  end

  describe "handle_gain_exp/3 with a zero grant" do
    test "a zero input stays zero regardless of the boost" do
      test_pid = self()
      stub(ModifierCalculator, :get_all_modifiers, fn :player, 1000 -> %{exp_rate: 50} end)

      stub(Leveling, :apply_exp, fn progression, base, job ->
        send(test_pid, {:granted, base, job})
        {progression, 0, 0}
      end)

      ExperienceHandler.handle_gain_exp(0, 100, state())

      assert_received {:granted, 0, 150}
    end
  end
end
