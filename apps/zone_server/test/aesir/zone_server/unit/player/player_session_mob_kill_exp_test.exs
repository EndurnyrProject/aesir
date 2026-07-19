defmodule Aesir.ZoneServer.Unit.Player.PlayerSessionMobKillExpTest do
  @moduledoc """
  Exercises `PlayerSession`'s side of a mob kill now that damage-based EXP
  distribution lives in `Unit.Mob.KillExp` (design "Damage-based EXP share"):
  `{:mob_kill_exp, base, job, race}` -- this session's own final share, already
  computed and (for a party) pooled/split by `KillExp.distribute/6` -- is
  handed to `ExperienceHandler.handle_gain_exp/4` untouched, along with the
  dead mob's race, which only this session can turn into a per-race equipment
  EXP bonus.
  """

  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Unit.Player.Handlers.ExperienceHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup :verify_on_exit!

  defp character do
    %Character{
      id: 1,
      account_id: 100,
      name: "Killer",
      last_map: "prontera",
      last_x: 150,
      last_y: 150,
      class: 0,
      base_level: 50,
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

  defp state do
    %{game_state: PlayerState.new(character()), connection_pid: self()}
  end

  test "{:mob_kill_exp, base, job, race} delegates to ExperienceHandler.handle_gain_exp/4" do
    expect(ExperienceHandler, :handle_gain_exp, fn 10, 5, :brute, state -> {:noreply, state} end)

    {:noreply, _state} = PlayerSession.handle_info({:mob_kill_exp, 10, 5, :brute}, state())
  end
end
