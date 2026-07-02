defmodule Aesir.ZoneServer.Unit.Player.PlayerSessionPartyExpTest do
  @moduledoc """
  Exercises party even-share EXP through `PlayerSession`'s `:mob_killed`
  handling (design "EXP share", Task 11): eligible same-map members receive a
  `{:party_exp, ...}` slice via PubSub, the killer applies its own slice
  in-line, a different-map member gets nothing, and a non-`exp_share` party
  falls through to the Task 10 solo-penalty grant with no broadcasts.
  `Party.Manager` is stubbed (its own semantics are covered by
  `manager_test.exs`); `UnitRegistry` and `PubSub` are exercised for real.
  """

  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.ItemDrop.LevelPenalty
  alias Aesir.ZoneServer.Party.Manager, as: PartyManager
  alias Aesir.ZoneServer.Party.Member
  alias Aesir.ZoneServer.Party.State, as: PartyState
  alias Aesir.ZoneServer.Unit.Player.Handlers.ExperienceHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry
  alias Phoenix.PubSub

  setup :verify_on_exit!
  setup :set_mimic_from_context
  setup :setup_ets_tables

  setup do
    :persistent_term.put({LevelPenalty, :exp}, %{})
    on_exit(fn -> :persistent_term.erase({LevelPenalty, :exp}) end)
    :ok
  end

  defp character(char_id) do
    %Character{
      id: char_id,
      account_id: char_id,
      name: "Char#{char_id}",
      last_map: "prontera",
      last_x: 150,
      last_y: 150,
      class: 0,
      base_level: 100,
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

  defp session_state(char_id, party_id) do
    game_state = %{PlayerState.new(character(char_id)) | party_id: party_id}
    %{game_state: game_state, connection_pid: self()}
  end

  defp register_member(char_id, map_name) do
    game_state = %{PlayerState.new(character(char_id)) | map_name: map_name}
    UnitRegistry.register_unit(:player, char_id, PlayerState, game_state, self())
  end

  defp party_member(char_id, map_name) do
    Member.new(char_id, "Char#{char_id}", 100, true, map_name)
  end

  defp payload(base_exp, job_exp, mob_level) do
    %{base_exp: base_exp, job_exp: job_exp, mob_level: mob_level}
  end

  test "splits pooled EXP across same-map members and skips a different-map member" do
    register_member(1, "prontera")
    register_member(2, "prontera")
    register_member(3, "geffen")

    party_state = %PartyState{
      party_id: 10,
      name: "Party",
      leader_char_id: 1,
      exp_share: true,
      members: %{
        1 => party_member(1, "prontera"),
        2 => party_member(2, "prontera"),
        3 => party_member(3, "geffen")
      }
    }

    expect(PartyManager, :get, fn 10 -> {:ok, party_state} end)
    expect(ExperienceHandler, :handle_gain_exp, fn 50, 25, state -> {:noreply, state} end)

    PubSub.subscribe(Aesir.PubSub, "player:2")
    PubSub.subscribe(Aesir.PubSub, "player:3")

    {:noreply, _state} =
      PlayerSession.handle_info({:mob_killed, payload(100, 50, 100)}, session_state(1, 10))

    assert_receive {:party_exp, 50, 25}
    refute_receive {:party_exp, _base, _job}, 50
  end

  test "exp_share false falls through to the solo-penalty grant with no broadcasts" do
    register_member(1, "prontera")
    register_member(2, "prontera")

    party_state = %PartyState{
      party_id: 10,
      name: "Party",
      leader_char_id: 1,
      exp_share: false,
      members: %{
        1 => party_member(1, "prontera"),
        2 => party_member(2, "prontera")
      }
    }

    expect(PartyManager, :get, fn 10 -> {:ok, party_state} end)
    expect(LevelPenalty, :exp, fn 100, 100 -> 100 end)
    expect(ExperienceHandler, :handle_gain_exp, fn 100, 50, state -> {:noreply, state} end)

    PubSub.subscribe(Aesir.PubSub, "player:2")

    {:noreply, _state} =
      PlayerSession.handle_info({:mob_killed, payload(100, 50, 100)}, session_state(1, 10))

    refute_receive {:party_exp, _base, _job}, 50
  end

  test "a party entry that has gone missing falls through to the solo-penalty grant" do
    register_member(1, "prontera")

    expect(PartyManager, :get, fn 10 -> {:error, :not_found} end)
    expect(LevelPenalty, :exp, fn 100, 100 -> 100 end)
    expect(ExperienceHandler, :handle_gain_exp, fn 100, 50, state -> {:noreply, state} end)

    {:noreply, _state} =
      PlayerSession.handle_info({:mob_killed, payload(100, 50, 100)}, session_state(1, 10))
  end

  test "{:party_exp, base, job} delegates straight to ExperienceHandler.handle_gain_exp/3" do
    expect(ExperienceHandler, :handle_gain_exp, fn 10, 5, state -> {:noreply, state} end)

    {:noreply, _state} = PlayerSession.handle_info({:party_exp, 10, 5}, session_state(1, 0))
  end
end
