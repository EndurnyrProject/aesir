defmodule Aesir.ZoneServer.Unit.Player.PlayerSessionPartyTest do
  @moduledoc """
  Party presence/snapshot wiring in `PlayerSession`: topic subscription and the
  initial `PartyInfo` snapshot on login, kicked-while-offline reconciliation,
  `{:party_updated, _}`/`{:party_disbanded, _, _}` relaying, presence pushes on
  disconnect, and the base-level push on level-up (Task 9).

  `PlayerSession.init/1`/`terminate/2` are called directly in the test process
  (mirroring `player_session_test.exs`), so PubSub subscriptions made inside
  land in this process's mailbox and can be asserted on directly.
  """
  use Aesir.DataCase, async: false

  import Aesir.TestEtsSetup

  alias Aesir.Commons.ClusterTestHelper
  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Net.PartyDisbanded
  alias Aesir.Net.PartyInfo
  alias Aesir.ZoneServer.Party.Manager, as: PartyManager
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

  describe "init/1 with a live party" do
    test "subscribes to the party topic and sends the initial PartyInfo snapshot" do
      {_leader, party} = party_fixture("Alice")
      member = character_fixture("Bobby", %{})
      {:ok, _joined} = PartyManager.add_member(party.party_id, member)
      member = Repo.get(Character, member.id)

      assert {:ok, state} =
               PlayerSession.init(%{character: member, connection_pid: self()})

      assert state.game_state.party_id == party.party_id

      assert_received {:send, :gameplay,
                       {:party_info, %PartyInfo{party_id: party_id, name: name, members: members}}}

      assert party_id == party.party_id
      assert name == party.name
      assert Enum.any?(members, &(&1.char_id == member.id))

      assert {:ok, live} = PartyManager.get(party.party_id)
      assert Map.fetch!(live.members, member.id).online == true

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

      state = %{
        game_state: PlayerState.new(Repo.get(Character, member.id)),
        connection_pid: self(),
        connection_monitor_ref: make_ref()
      }

      UnitRegistry.register_player(state.game_state, self())

      assert :ok = PlayerSession.terminate(:normal, state)

      assert {:ok, after_state} = PartyManager.get(party.party_id)
      assert Map.fetch!(after_state.members, member.id).online == false
      assert Map.fetch!(after_state.members, leader.id).online == true
    end
  end

  describe "handle_info({:party_updated, _})" do
    test "relays a PartyInfo snapshot to the client when still a member" do
      {_leader, party} = party_fixture("Henry")
      member = character_fixture("Ivyx", %{})
      {:ok, joined} = PartyManager.add_member(party.party_id, member)

      state = %{
        game_state: PlayerState.new(%{Repo.get(Character, member.id) | party_id: party.party_id}),
        connection_pid: self()
      }

      assert {:noreply, _new_state} = PlayerSession.handle_info({:party_updated, joined}, state)

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
               PlayerSession.handle_info({:party_updated, after_kick}, state)

      assert new_state.game_state.party_id == 0

      PubSub.broadcast(Aesir.PubSub, "party:#{party.party_id}", :probe)
      refute_receive :probe
    end
  end

  describe "handle_info({:party_disbanded, _, _})" do
    test "sends PartyDisbanded, unsubscribes, and clears party_id" do
      {leader, party} = party_fixture("Liam")

      PubSub.subscribe(Aesir.PubSub, "party:#{party.party_id}")

      game_state = PlayerState.new(%{Repo.get(Character, leader.id) | party_id: party.party_id})
      UnitRegistry.register_player(game_state, self())
      state = %{game_state: game_state, connection_pid: self()}

      assert {:noreply, new_state} =
               PlayerSession.handle_info(
                 {:party_disbanded, party.party_id, "leader_left"},
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

  describe "handle_info(:party_invite_expired)" do
    test "clears the pending invite" do
      state = %{pending_party_invite: %{party_id: 1, inviter_char_id: 2, expires_at: 0}}

      assert {:noreply, new_state} = PlayerSession.handle_info(:party_invite_expired, state)

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
