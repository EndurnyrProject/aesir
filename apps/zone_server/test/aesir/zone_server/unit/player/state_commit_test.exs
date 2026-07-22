defmodule Aesir.ZoneServer.Unit.Player.StateCommitTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup
  import ExUnit.CaptureLog

  alias Aesir.ZoneServer.Party.Manager
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.Player.StateCommit
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.Stats.CurrentState
  alias Aesir.ZoneServer.Unit.Stats.DerivedStats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!
  setup :set_mimic_from_context
  setup :setup_ets_tables

  test "publishes registry state before party sync and keeps it when party sync fails" do
    previous = player_state(40)
    current = player_state(35)
    session = %SessionState{connection_pid: self(), game_state: previous}

    :ok = UnitRegistry.register_unit(:player, 12, PlayerState, previous, self())

    expect(Manager, :sync_member, fn 7, 12, _member ->
      assert {:ok, {PlayerState, ^current, _pid}} = UnitRegistry.get_unit(:player, 12)
      {:error, :party_unavailable}
    end)

    log =
      capture_log(fn ->
        assert %{session | game_state: current} == StateCommit.commit(session, current)
      end)

    assert log =~ "party_unavailable"
    assert {:ok, {PlayerState, ^current, _pid}} = UnitRegistry.get_unit(:player, 12)
  end

  defp player_state(hp) do
    %PlayerState{
      character_id: 12,
      character_name: "Aesir",
      party_id: 7,
      map_name: "prontera",
      stats: %PlayerStats{
        progression: %PlayerProgression{base_level: 175, job_id: 4054},
        current_state: %CurrentState{hp: hp, sp: 900, ap: 120},
        derived_stats: %DerivedStats{max_hp: 8_000, max_sp: 1_200, max_ap: 200}
      }
    }
  end
end
