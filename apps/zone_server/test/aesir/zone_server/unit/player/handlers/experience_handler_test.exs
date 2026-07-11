defmodule Aesir.ZoneServer.Unit.Player.Handlers.ExperienceHandlerTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Mmo.Leveling
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
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
