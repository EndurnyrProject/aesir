defmodule Aesir.ZoneServer.Unit.Player.PlayerSessionExpPenaltyTest do
  @moduledoc """
  Exercises the renewal EXP level-gap penalty applied to the solo `:mob_killed`
  path (design "Renewal level-gap penalty"): the killer's granted base/job EXP
  is scaled by `LevelPenalty.exp/2` before reaching `ExperienceHandler`.
  """

  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.ItemDrop.LevelPenalty
  alias Aesir.ZoneServer.Unit.Player.Handlers.ExperienceHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup :verify_on_exit!

  defp character(base_level) do
    %Character{
      id: 1,
      account_id: 100,
      name: "Killer",
      last_map: "prontera",
      last_x: 150,
      last_y: 150,
      class: 0,
      base_level: base_level,
      job_level: 50,
      sex: "M",
      str: 10,
      agi: 10,
      vit: 10,
      int: 10,
      dex: 10,
      luk: 7
    }
  end

  defp state(base_level) do
    %{game_state: PlayerState.new(character(base_level)), connection_pid: self()}
  end

  defp payload(base_exp, job_exp, mob_level) do
    %{base_exp: base_exp, job_exp: job_exp, mob_level: mob_level}
  end

  test "scales base/job exp by the level-gap penalty rate before granting" do
    expect(LevelPenalty, :exp, fn 80, 100 -> 60 end)
    expect(ExperienceHandler, :handle_gain_exp, fn 60, 30, state -> {:noreply, state} end)

    {:noreply, _state} =
      PlayerSession.handle_info({:mob_killed, payload(100, 50, 80)}, state(100))
  end

  test "leaves exp unchanged for a neutral in-range gap" do
    expect(LevelPenalty, :exp, fn 100, 100 -> 100 end)
    expect(ExperienceHandler, :handle_gain_exp, fn 100, 50, state -> {:noreply, state} end)

    {:noreply, _state} =
      PlayerSession.handle_info({:mob_killed, payload(100, 50, 100)}, state(100))
  end

  test "floors a positive scaled amount at 1 instead of rounding down to 0" do
    expect(LevelPenalty, :exp, fn 10, 100 -> 5 end)
    expect(ExperienceHandler, :handle_gain_exp, fn 1, 1, state -> {:noreply, state} end)

    {:noreply, _state} = PlayerSession.handle_info({:mob_killed, payload(10, 1, 10)}, state(100))
  end

  test "a zero exp amount stays zero even at a positive rate" do
    expect(LevelPenalty, :exp, fn 100, 100 -> 100 end)
    expect(ExperienceHandler, :handle_gain_exp, fn 100, 0, state -> {:noreply, state} end)

    {:noreply, _state} =
      PlayerSession.handle_info({:mob_killed, payload(100, 0, 100)}, state(100))
  end
end
