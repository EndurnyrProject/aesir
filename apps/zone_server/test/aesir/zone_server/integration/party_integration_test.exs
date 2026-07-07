defmodule Aesir.ZoneServer.Integration.PartyIntegrationTest do
  @moduledoc """
  End-to-end party lifecycle across real, concurrent `PlayerSession`s (design
  "Testing", item 4): create -> invite -> accept -> same-map kill -> pooled,
  penalty-scaled EXP split, a different-map member excluded from the split,
  `exp_share` toggled off granting the killer the full penalized amount with
  no broadcast, and a level-up past `party_share_level` auto-disabling
  `exp_share` for every connected client.

  `Party.Manager`, `Party.ExpShare`, `Unit.Mob.KillExp` and the renewal
  level-gap penalty (`LevelPenalty`) all run for real against a live Horde
  entry and DB rows; only the usual integration-test I/O (map cache, spatial
  index) goes through the real ETS-backed implementations `IntegrationCase`
  already wires up, mirroring `warp_test.exs`/`cart_integration_test.exs`.
  `kill_mob/1` calls `KillExp.distribute/5` directly with the killer as the
  mob's sole (100%-damage) attacker -- the exact seam `MobSession` uses in
  production -- so the party pooling/eligibility logic under test is the real
  thing, not a hand-computed stand-in.

  `form_party/1` drives the real create/invite/accept protocol messages
  end to end, with no relog: `PartyHandler.handle_create_request/2` and the
  invite-accept path call `PlayerSession.attach_to_party/2` inline, which
  updates the requester's own live `game_state.party_id`, subscribes it to
  `"party:\#{party_id}"`, and sends the initial `PartyInfo` snapshot --
  exactly as a login would, but without needing one.
  """

  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Commons.ClusterTestHelper
  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Net.PartyActionResult
  alias Aesir.Net.PartyCreateRequest
  alias Aesir.Net.PartyInfo
  alias Aesir.Net.PartyInviteNotify
  alias Aesir.Net.PartyInviteRequest
  alias Aesir.Net.PartyInviteResponse
  alias Aesir.Net.PartyOptionsRequest
  alias Aesir.Repo
  alias Aesir.ZoneServer.Unit.Mob.KillExp

  # rAthena `level_penalty.yml` `Type: Exp` breakpoint: diff -31 -> 10%.
  @mob_level 19
  @killer_level 50
  @base_exp 100
  @job_exp 50

  setup do
    on_exit(&ClusterTestHelper.clear_all/0)
    :ok
  end

  describe "same-map even-share kill" do
    test "create -> invite -> accept -> both online same map splits penalty-scaled EXP" do
      %{sessions: [leader, ally]} =
        form_party([{"Leader", @killer_level, "prontera"}, {"Ally", @killer_level, "prontera"}])

      enable_exp_share(leader.pid)

      kill_mob(leader.pid)

      leader_state = get_player_state(leader.pid)
      ally_state = get_player_state(ally.pid)

      assert leader_state.stats.progression.base_exp == 5
      assert leader_state.stats.progression.job_exp == 2
      assert ally_state.stats.progression.base_exp == 5
      assert ally_state.stats.progression.job_exp == 2
    end

    test "a third member on a different map is excluded from the split" do
      %{sessions: [leader, ally, elsewhere]} =
        form_party([
          {"Leader", @killer_level, "prontera"},
          {"Ally", @killer_level, "prontera"},
          {"Elsewhere", @killer_level, "geffen"}
        ])

      enable_exp_share(leader.pid)

      kill_mob(leader.pid)

      leader_state = get_player_state(leader.pid)
      ally_state = get_player_state(ally.pid)
      elsewhere_state = get_player_state(elsewhere.pid)

      assert leader_state.stats.progression.base_exp == 5
      assert ally_state.stats.progression.base_exp == 5
      assert elsewhere_state.stats.progression.base_exp == 0
      assert elsewhere_state.stats.progression.job_exp == 0
    end
  end

  describe "exp_share disabled" do
    test "the killer takes the full penalized amount and nothing broadcasts to others" do
      %{sessions: [leader, ally]} =
        form_party([{"Leader", @killer_level, "prontera"}, {"Ally", @killer_level, "prontera"}])

      enable_exp_share(leader.pid)

      simulate_incoming_message(leader.pid, %PartyOptionsRequest{exp_share: false})

      assert_receive {:packet_sent, %PartyActionResult{action: "options", success: true}, _},
                     1_000

      kill_mob(leader.pid)

      leader_state = get_player_state(leader.pid)
      ally_state = get_player_state(ally.pid)

      assert leader_state.stats.progression.base_exp == 10
      assert leader_state.stats.progression.job_exp == 5
      assert ally_state.stats.progression.base_exp == 0
      assert ally_state.stats.progression.job_exp == 0
    end
  end

  describe "level-up past party_share_level" do
    test "auto-disables exp_share and both connected clients get the options-changed snapshot" do
      %{sessions: [leader, riser], party_id: party_id} =
        form_party([{"Leader", @killer_level, "prontera"}, {"Riser", @killer_level, "geffen"}])

      enable_exp_share(leader.pid)
      flush_packets()

      %{character_id: riser_char_id, map_name: riser_map} = get_player_state(riser.pid)
      KillExp.distribute(%{riser_char_id => 1}, 1_000_000_000, 0, 1, riser_map)

      leader_state = get_player_state(leader.pid)
      riser_state = get_player_state(riser.pid)

      assert riser_state.stats.progression.base_level > leader_state.stats.progression.base_level

      assert_receive {:packet_sent, %PartyInfo{party_id: ^party_id, exp_share: false}, _}, 1_000
      assert_receive {:packet_sent, %PartyInfo{party_id: ^party_id, exp_share: false}, _}, 1_000
    end
  end

  defp kill_mob(killer_pid) do
    %{character_id: char_id, map_name: map_name} = get_player_state(killer_pid)
    KillExp.distribute(%{char_id => 1}, @base_exp, @job_exp, @mob_level, map_name)
  end

  defp enable_exp_share(leader_pid) do
    simulate_incoming_message(leader_pid, %PartyOptionsRequest{exp_share: true})

    assert_receive {:packet_sent, %PartyActionResult{action: "options", success: true}, _}, 1_000
  end

  # Drives the real create/invite/accept protocol across one leader and each
  # `{name, base_level, map_name}` member spec; each session's live party
  # wiring (game_state.party_id, subscription, snapshot) is attached inline
  # by `PartyHandler` as it happens -- no relog needed (see moduledoc).
  defp form_party([{leader_name, leader_level, leader_map} | member_specs]) do
    leader_char =
      character_fixture(leader_name, %{
        base_level: leader_level,
        last_map: leader_map,
        last_x: 150,
        last_y: 150
      })

    leader_session =
      start_player_session(character: leader_char, map_name: leader_map, position: {150, 150})

    simulate_incoming_message(leader_session.pid, %PartyCreateRequest{name: "Vanguard"})

    assert_receive {:packet_sent, %PartyActionResult{action: "create", success: true}, _}, 1_000

    party_id = Repo.get(Character, leader_char.id).party_id

    assert get_player_state(leader_session.pid).party_id == party_id

    member_sessions = Enum.map(member_specs, &invite_and_accept(leader_session, party_id, &1))
    flush_packets()

    %{sessions: [leader_session | member_sessions], party_id: party_id}
  end

  defp invite_and_accept(leader_session, party_id, {name, level, map_name}) do
    member_char =
      character_fixture(name, %{
        base_level: level,
        last_map: map_name,
        last_x: 150,
        last_y: 150
      })

    session =
      start_player_session(character: member_char, map_name: map_name, position: {150, 150})

    simulate_incoming_message(leader_session.pid, %PartyInviteRequest{
      target_char_id: member_char.id,
      target_name: ""
    })

    assert_receive {:packet_sent, %PartyActionResult{action: "invite", success: true}, _}, 1_000
    assert_receive {:packet_sent, %PartyInviteNotify{party_id: ^party_id}, _}, 1_000

    simulate_incoming_message(session.pid, %PartyInviteResponse{party_id: party_id, accept: true})

    assert_receive {:packet_sent, %PartyActionResult{action: "invite_response", success: true},
                    _},
                   1_000

    assert get_player_state(session.pid).party_id == party_id

    session
  end

  defp account_fixture(userid) do
    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        userid: userid,
        user_pass: "password",
        sex: "M",
        email: "#{userid}@example.com"
      })
      |> Repo.insert()

    account
  end

  defp character_fixture(name, attrs) do
    account = account_fixture(name)

    {:ok, character} =
      attrs
      |> Enum.into(%{char_num: 0, class: 0, base_level: 1, account_id: account.id, name: name})
      |> Character.new()
      |> Repo.insert()

    character
  end
end
