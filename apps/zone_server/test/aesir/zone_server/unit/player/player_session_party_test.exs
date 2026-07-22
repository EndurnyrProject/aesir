defmodule Aesir.ZoneServer.Unit.Player.PlayerSessionPartyTest do
  @moduledoc """
  Party presence/snapshot wiring in `PlayerSession`: topic subscription and the
  initial `PartyInfo` snapshot on login, kicked-while-offline reconciliation,
  `{:social, {:party_updated, _}}`/`{:social, {:party_disbanded, _, _}}` relaying, presence pushes on
  disconnect, and the base-level push on level-up (Task 9).

  Most lifecycle callbacks are called directly in the test process (mirroring
  `player_session_test.exs`). The ordering test starts a real session and uses
  a separate connection probe to observe party packets exactly as sent.
  """
  use Aesir.DataCase, async: false

  import Aesir.TestEtsSetup

  alias Aesir.Commons.ClusterTestHelper
  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Net.PartyDisbanded
  alias Aesir.Net.PartyInfo
  alias Aesir.Net.PartyMemberUpdate
  alias Aesir.ZoneServer.Party.Manager, as: PartyManager
  alias Aesir.ZoneServer.Party.Member
  alias Aesir.ZoneServer.Unit.Player.Handlers.ExperienceHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.WarpHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry
  alias Phoenix.PubSub

  setup :setup_ets_tables

  setup do
    on_exit(&ClusterTestHelper.clear_all/0)

    # Run CharacterPersistence's fire-and-forget writes inline: they'd
    # otherwise race the DB sandbox owner exiting at the end of a fast test
    # (a background `Task` still holding the connection when the test
    # process -- the sandbox owner -- shuts down).
    prev_inline = Application.get_env(:zone_server, :inline_persistence)
    Application.put_env(:zone_server, :inline_persistence, true)

    on_exit(fn ->
      case prev_inline do
        nil -> Application.delete_env(:zone_server, :inline_persistence)
        value -> Application.put_env(:zone_server, :inline_persistence, value)
      end
    end)

    :ok
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
    account = account_fixture("#{name}_acct")

    {:ok, character} =
      attrs
      |> Enum.into(%{char_num: 0, class: 0, base_level: 1, account_id: account.id, name: name})
      |> Character.new()
      |> Repo.insert()

    character
  end

  defp party_fixture(leader_name) do
    leader = character_fixture(leader_name, %{})
    {:ok, party_state} = PartyManager.create("Party-#{leader_name}", leader)
    {leader, party_state}
  end

  defp start_connection_probe(test_pid) do
    spawn(fn -> connection_probe(test_pid, Process.monitor(test_pid), 0) end)
  end

  defp connection_probe(test_pid, test_ref, party_message_count) do
    receive do
      {:send, :gameplay, {tag, _message} = party_message}
      when tag in [:party_info, :party_member_update] ->
        next_count = party_message_count + 1
        send(test_pid, {:party_outbound, next_count, party_message})
        connection_probe(test_pid, test_ref, next_count)

      {:DOWN, ^test_ref, :process, ^test_pid, _reason} ->
        :ok

      _other ->
        connection_probe(test_pid, test_ref, party_message_count)
    end
  end

  describe "init/1 with a live party" do
    test "sends the enriched roster before processing the queued reconnect delta" do
      {_leader, party} = party_fixture("OrderedLeader")
      member = character_fixture("OrderedMember", %{})
      {:ok, _joined} = PartyManager.add_member(party.party_id, member)
      {:ok, _offline} = PartyManager.set_online(party.party_id, member.id, false)
      member = Repo.get(Character, member.id)
      connection_pid = start_connection_probe(self())

      session_pid =
        start_supervised!({
          PlayerSession,
          %{character: member, connection_pid: connection_pid}
        })

      assert_receive {:party_outbound, 1,
                      {:party_info, %PartyInfo{party_id: party_id, members: members}}}

      assert party_id == party.party_id
      roster_member = Enum.find(members, &(&1.char_id == member.id))
      game_state = PlayerSession.get_state(session_pid).game_state
      assert roster_member.online
      assert roster_member.job_id == game_state.stats.progression.job_id
      assert roster_member.base_level == game_state.stats.progression.base_level
      assert roster_member.hp == game_state.stats.current_state.hp
      assert roster_member.max_hp == game_state.stats.derived_stats.max_hp
      assert roster_member.sp == game_state.stats.current_state.sp
      assert roster_member.max_sp == game_state.stats.derived_stats.max_sp
      assert roster_member.ap == game_state.stats.current_state.ap
      assert roster_member.max_ap == game_state.stats.derived_stats.max_ap
      assert roster_member.map == game_state.map_name

      assert_receive {:party_outbound, 2,
                      {:party_member_update,
                       %PartyMemberUpdate{party_id: ^party_id, member: updated_member}}}

      assert updated_member == roster_member
      assert game_state.party_id == party.party_id
    end

    test "subscribes to the party topic and sends the initial PartyInfo snapshot" do
      {_leader, party} = party_fixture("Alice")
      member = character_fixture("Bobby", %{})
      {:ok, _joined} = PartyManager.add_member(party.party_id, member)
      {:ok, _offline} = PartyManager.set_online(party.party_id, member.id, false)
      member = Repo.get(Character, member.id)

      assert {:ok, state} =
               PlayerSession.init(%{character: member, connection_pid: self()})

      assert state.game_state.party_id == party.party_id

      assert_received {:send, :gameplay,
                       {:party_info, %PartyInfo{party_id: party_id, name: name, members: members}}}

      assert party_id == party.party_id
      assert name == party.name
      wire_member = Enum.find(members, &(&1.char_id == member.id))
      assert wire_member.job_id == state.game_state.stats.progression.job_id
      assert wire_member.base_level == state.game_state.stats.progression.base_level
      assert wire_member.hp == state.game_state.stats.current_state.hp
      assert wire_member.max_hp == state.game_state.stats.derived_stats.max_hp
      assert wire_member.sp == state.game_state.stats.current_state.sp
      assert wire_member.max_sp == state.game_state.stats.derived_stats.max_sp
      assert wire_member.ap == state.game_state.stats.current_state.ap
      assert wire_member.max_ap == state.game_state.stats.derived_stats.max_ap
      assert wire_member.online
      assert wire_member.map == state.game_state.map_name

      assert {:ok, live} = PartyManager.get(party.party_id)

      assert Map.fetch!(live.members, member.id).max_hp ==
               state.game_state.stats.derived_stats.max_hp

      assert_receive {:social, {:party_member_updated, ^party_id, updated_member}}
      assert updated_member.char_id == member.id

      PubSub.broadcast(Aesir.PubSub, "party:#{party.party_id}", :probe)
      assert_receive :probe
    end
  end

  describe "init/1 kicked-while-offline reconciliation" do
    test "silently resets party_id to 0 when the party row is gone" do
      character = character_fixture("Carol", %{party_id: 999_999})

      assert {:ok, state} =
               PlayerSession.init(%{character: character, connection_pid: self()})

      assert state.game_state.party_id == 0
      refute_received {:send, :gameplay, {:party_info, _}}
      assert Repo.get(Character, character.id).party_id == 0
    end

    test "silently resets party_id to 0 when the character is absent from the live party" do
      {_leader, party} = party_fixture("Dave")

      stray =
        character_fixture("Erin", %{party_id: party.party_id})

      assert {:ok, state} =
               PlayerSession.init(%{character: stray, connection_pid: self()})

      assert state.game_state.party_id == 0
      refute_received {:send, :gameplay, {:party_info, _}}
      assert Repo.get(Character, stray.id).party_id == 0
    end
  end

  describe "terminate/2" do
    test "marks the member offline and other members see the flip via get/1" do
      {leader, party} = party_fixture("Frank")
      member = character_fixture("Gina", %{})
      {:ok, joined} = PartyManager.add_member(party.party_id, member)
      assert Map.fetch!(joined.members, member.id).online == true

      game_state = PlayerState.new(Repo.get(Character, member.id))

      stats = %{
        game_state.stats
        | progression: %{game_state.stats.progression | job_id: 9, base_level: 44},
          current_state: %{game_state.stats.current_state | hp: 321, sp: 123, ap: 22},
          derived_stats: %{
            game_state.stats.derived_stats
            | max_hp: 987,
              max_sp: 456,
              max_ap: 88
          }
      }

      state = %{
        game_state: %{game_state | map_name: "aldebaran", stats: stats},
        connection_pid: self(),
        connection_monitor_ref: make_ref()
      }

      UnitRegistry.register_player(state.game_state, self())

      assert :ok = PlayerSession.terminate(:normal, state)

      assert {:ok, after_state} = PartyManager.get(party.party_id)
      offline_member = Map.fetch!(after_state.members, member.id)
      refute offline_member.online
      assert offline_member.job_id == 9
      assert offline_member.base_level == 44
      assert offline_member.hp == 321
      assert offline_member.max_hp == 987
      assert offline_member.sp == 123
      assert offline_member.max_sp == 456
      assert offline_member.ap == 22
      assert offline_member.max_ap == 88
      assert offline_member.map_name == "aldebaran"
      assert Map.fetch!(after_state.members, leader.id).online == true
    end
  end

  describe "handle_info({:social, {:party_updated, _}})" do
    test "relays a PartyInfo snapshot to the client when still a member" do
      {_leader, party} = party_fixture("Henry")
      member = character_fixture("Ivyx", %{})
      {:ok, joined} = PartyManager.add_member(party.party_id, member)

      state = %{
        game_state: PlayerState.new(%{Repo.get(Character, member.id) | party_id: party.party_id}),
        connection_pid: self()
      }

      assert {:noreply, _new_state} =
               PlayerSession.handle_info({:social, {:party_updated, joined}}, state)

      assert_received {:send, :gameplay, {:party_info, %PartyInfo{party_id: party_id}}}
      assert party_id == party.party_id
    end

    test "unsubscribes and clears party_id when this member was removed" do
      {_leader, party} = party_fixture("Jack")
      member = character_fixture("Kimmy", %{})
      {:ok, _joined} = PartyManager.add_member(party.party_id, member)

      PubSub.subscribe(Aesir.PubSub, "party:#{party.party_id}")

      {:ok, after_kick} = PartyManager.kick(party.party_id, party.leader_char_id, member.id)

      game_state = PlayerState.new(%{Repo.get(Character, member.id) | party_id: party.party_id})
      UnitRegistry.register_player(game_state, self())
      state = %{game_state: game_state, connection_pid: self()}

      assert {:noreply, new_state} =
               PlayerSession.handle_info({:social, {:party_updated, after_kick}}, state)

      assert new_state.game_state.party_id == 0

      PubSub.broadcast(Aesir.PubSub, "party:#{party.party_id}", :probe)
      refute_receive :probe

      stale_member = Map.fetch!(party.members, party.leader_char_id)

      assert {:noreply, ^new_state} =
               PlayerSession.handle_info(
                 {:social, {:party_member_updated, party.party_id, stale_member}},
                 new_state
               )

      refute_received {:send, :gameplay, {:party_member_update, _}}
    end
  end

  describe "handle_info({:social, {:party_member_updated, _, _}})" do
    test "relays a complete member update for the current party" do
      member = %Member{
        char_id: 42,
        name: "Remote",
        job_id: 7,
        base_level: 88,
        hp: 1_234,
        max_hp: 4_321,
        sp: 222,
        max_sp: 555,
        ap: 30,
        max_ap: 100,
        online: true,
        map_name: "geffen"
      }

      state = %{
        game_state: %PlayerState{party_id: 77},
        connection_pid: self()
      }

      assert {:noreply, ^state} =
               PlayerSession.handle_info({:social, {:party_member_updated, 77, member}}, state)

      assert_received {:send, :gameplay,
                       {:party_member_update,
                        %PartyMemberUpdate{party_id: 77, member: wire_member}}}

      assert wire_member.char_id == 42
      assert wire_member.job_id == 7
      assert wire_member.base_level == 88
      assert wire_member.hp == 1_234
      assert wire_member.max_hp == 4_321
      assert wire_member.sp == 222
      assert wire_member.max_sp == 555
      assert wire_member.ap == 30
      assert wire_member.max_ap == 100
      assert wire_member.online
      assert wire_member.map == "geffen"
    end

    test "ignores an update for another party" do
      state = %{
        game_state: %PlayerState{party_id: 77},
        connection_pid: self()
      }

      member = %Member{
        char_id: 42,
        name: "Remote",
        base_level: 1,
        online: true
      }

      assert {:noreply, ^state} =
               PlayerSession.handle_info({:social, {:party_member_updated, 88, member}}, state)

      refute_received {:send, :gameplay, {:party_member_update, _}}
    end
  end

  describe "handle_info({:social, {:party_disbanded, _, _}})" do
    test "sends PartyDisbanded, unsubscribes, and clears party_id" do
      {leader, party} = party_fixture("Liam")

      PubSub.subscribe(Aesir.PubSub, "party:#{party.party_id}")

      game_state = PlayerState.new(%{Repo.get(Character, leader.id) | party_id: party.party_id})
      UnitRegistry.register_player(game_state, self())
      state = %{game_state: game_state, connection_pid: self()}

      assert {:noreply, new_state} =
               PlayerSession.handle_info(
                 {:social, {:party_disbanded, party.party_id, "leader_left"}},
                 state
               )

      assert new_state.game_state.party_id == 0

      assert_received {:send, :gameplay,
                       {:party_disbanded,
                        %PartyDisbanded{party_id: party_id, reason: "leader_left"}}}

      assert party_id == party.party_id

      PubSub.broadcast(Aesir.PubSub, "party:#{party.party_id}", :probe)
      refute_receive :probe
    end
  end

  describe "handle_info({:social, :party_invite_expired})" do
    test "clears the pending invite" do
      state = %{pending_party_invite: %{party_id: 1, inviter_char_id: 2, expires_at: 0}}

      assert {:noreply, new_state} =
               PlayerSession.handle_info({:social, :party_invite_expired}, state)

      refute Map.has_key?(new_state, :pending_party_invite)
    end
  end

  describe "level-up pushes base_level to the party entry" do
    test "ExperienceHandler.handle_gain_exp/3 pushes the new base_level" do
      {leader, party} = party_fixture("Mona")

      character = Repo.get(Character, leader.id)
      game_state = %{PlayerState.new(character) | party_id: party.party_id}
      state = %{game_state: game_state, connection_pid: self()}

      assert {:noreply, new_state} =
               ExperienceHandler.handle_gain_exp(1_000_000_000, 0, state)

      new_base_level = new_state.game_state.stats.progression.base_level
      assert new_base_level > character.base_level

      assert {:ok, live} = PartyManager.get(party.party_id)
      assert Map.fetch!(live.members, leader.id).base_level == new_base_level
    end
  end

  describe "warp pushes map_change to the party entry" do
    test "WarpHandler.warp/4 pushes the destination map" do
      # Real MapCache/SpatialIndex/Broadcast collaborators on purpose: this
      # DataCase file runs `async: false` (Party.Manager's Horde entries are
      # process-global, not sandboxed per test), so a Mimic `stub/3` here
      # runs in Mimic's `:global` mode and would leak into any other,
      # concurrently-running `async: true` test that happens to call the
      # same function (e.g. a live `MobSession` tick) -- exactly the
      # narrowly-matched stubs a plain warp unit test would reach for.
      {leader, party} = party_fixture("Nora")

      character = Repo.get(Character, leader.id)

      game_state = %{
        PlayerState.new(character)
        | party_id: party.party_id,
          map_name: "prontera",
          x: 50,
          y: 50
      }

      state = %{game_state: game_state, connection_pid: self()}

      assert {:ok, _new_state} = WarpHandler.warp(state, "geffen", 100, 120)

      assert {:ok, live} = PartyManager.get(party.party_id)
      assert Map.fetch!(live.members, leader.id).map_name == "geffen"
    end
  end
end
