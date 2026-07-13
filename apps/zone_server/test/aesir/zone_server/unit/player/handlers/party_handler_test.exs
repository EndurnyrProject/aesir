defmodule Aesir.ZoneServer.Unit.Player.Handlers.PartyHandlerTest do
  use Aesir.DataCase, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.ClusterTestHelper
  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Net.PartyActionResult
  alias Aesir.Net.PartyCreateRequest
  alias Aesir.Net.PartyInfo
  alias Aesir.Net.PartyInviteRequest
  alias Aesir.Net.PartyInviteResponse
  alias Aesir.Net.PartyKickRequest
  alias Aesir.Net.PartyLeaderRequest
  alias Aesir.Net.PartyLeaveRequest
  alias Aesir.Net.PartyOptionsRequest
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Party.Manager, as: PartyManager
  alias Aesir.ZoneServer.Party.State, as: PartyState
  alias Aesir.ZoneServer.Unit.Player.Handlers.PacketHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.PartyHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry
  alias Phoenix.PubSub

  setup :verify_on_exit!
  setup :set_mimic_from_context
  setup :setup_ets_tables

  setup do
    on_exit(&ClusterTestHelper.clear_all/0)
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

  defp character_fixture(attrs) do
    {:ok, character} =
      attrs
      |> Enum.into(%{char_num: 0, class: 0, base_level: 1})
      |> Character.new()
      |> Repo.insert()

    character
  end

  defp character_fixture(name, attrs) do
    account = account_fixture(name)
    character_fixture(Map.merge(%{account_id: account.id, name: name}, attrs))
  end

  defp party_fixture(leader_name) do
    leader = character_fixture(leader_name, %{})
    {:ok, party_state} = PartyManager.create("Party-#{leader_name}", leader)
    {leader, party_state}
  end

  defp state_for(%Character{} = character) do
    %{
      connection_pid: self(),
      game_state: PlayerState.new(character),
      interaction_lock: nil
    }
  end

  defp register_online(%Character{} = character, pid \\ self()) do
    UnitRegistry.register_player(PlayerState.new(character), pid)
  end

  describe "handle_create_request/2" do
    test "a valid name creates a party and acks success" do
      leader = character_fixture("Alice", %{})

      assert {:noreply, _state} =
               PartyHandler.handle_create_request(
                 %PartyCreateRequest{name: "Vanguard"},
                 state_for(leader)
               )

      assert_received {:send, :gameplay,
                       {:party_action_result,
                        %PartyActionResult{action: "create", success: true, error: :NONE}}}

      assert Repo.get(Character, leader.id).party_id > 0
    end

    test "a valid name attaches the requester's own session to the new party" do
      leader = character_fixture("Alice2", %{})
      state = state_for(leader)

      stats = %{
        state.game_state.stats
        | progression: %{state.game_state.stats.progression | job_id: 12, base_level: 33},
          current_state: %{state.game_state.stats.current_state | hp: 333, sp: 222, ap: 11},
          derived_stats: %{
            state.game_state.stats.derived_stats
            | max_hp: 999,
              max_sp: 777,
              max_ap: 55
          }
      }

      state = %{state | game_state: %{state.game_state | map_name: "payon", stats: stats}}

      assert {:noreply, new_state} =
               PartyHandler.handle_create_request(
                 %PartyCreateRequest{name: "Vanguard2"},
                 state
               )

      party_id = Repo.get(Character, leader.id).party_id
      assert new_state.game_state.party_id == party_id

      assert_receive {:send, :gameplay,
                      {:party_info, %PartyInfo{party_id: ^party_id, members: members}}}

      wire_member = Enum.find(members, &(&1.char_id == leader.id))
      assert wire_member.job_id == 12
      assert wire_member.base_level == 33
      assert wire_member.hp == 333
      assert wire_member.max_hp == 999
      assert wire_member.sp == 222
      assert wire_member.max_sp == 777
      assert wire_member.ap == 11
      assert wire_member.max_ap == 55
      assert wire_member.online
      assert wire_member.map == "payon"

      assert_receive {:send, :gameplay,
                      {:party_action_result, %PartyActionResult{action: "create", success: true}}}

      assert {:ok, live} = PartyManager.get(party_id)
      assert Map.fetch!(live.members, leader.id).max_hp == 999

      PubSub.broadcast(Aesir.PubSub, "party:#{party_id}", :probe)
      assert_receive :probe
    end

    test "a duplicate name acks NAME_TAKEN" do
      {_leader, _party} = party_fixture("Bobby")
      other = character_fixture("Carol", %{})

      assert {:noreply, _state} =
               PartyHandler.handle_create_request(
                 %PartyCreateRequest{name: "Party-Bobby"},
                 state_for(other)
               )

      assert_received {:send, :gameplay,
                       {:party_action_result,
                        %PartyActionResult{action: "create", success: false, error: :NAME_TAKEN}}}
    end

    test "already being in a party acks ALREADY_IN_PARTY" do
      {leader, _party} = party_fixture("Dave")

      assert {:noreply, _state} =
               PartyHandler.handle_create_request(
                 %PartyCreateRequest{name: "SecondParty"},
                 state_for(leader)
               )

      assert_received {:send, :gameplay,
                       {:party_action_result,
                        %PartyActionResult{
                          action: "create",
                          success: false,
                          error: :ALREADY_IN_PARTY
                        }}}
    end
  end

  describe "handle_invite_request/2" do
    test "a non-leader acks NOT_LEADER and sends no notify" do
      {_leader, party} = party_fixture("Erin")
      member = character_fixture("Frank", %{})
      {:ok, _joined} = PartyManager.add_member(party.party_id, member)

      assert {:noreply, _state} =
               PartyHandler.handle_invite_request(
                 %PartyInviteRequest{target_char_id: 999_999, target_name: ""},
                 state_for(member)
               )

      assert_received {:send, :gameplay,
                       {:party_action_result,
                        %PartyActionResult{action: "invite", success: false, error: :NOT_LEADER}}}

      refute_received {:send, :gameplay, {:party_invite_notify, _}}
    end

    test "a requester with no party acks NOT_LEADER" do
      loner = character_fixture("Gina", %{})

      assert {:noreply, _state} =
               PartyHandler.handle_invite_request(
                 %PartyInviteRequest{target_char_id: 1, target_name: ""},
                 state_for(loner)
               )

      assert_received {:send, :gameplay,
                       {:party_action_result,
                        %PartyActionResult{action: "invite", success: false, error: :NOT_LEADER}}}
    end

    test "an offline target acks TARGET_OFFLINE" do
      {leader, _party} = party_fixture("Heidi")
      target = character_fixture("Ivan", %{})

      assert {:noreply, _state} =
               PartyHandler.handle_invite_request(
                 %PartyInviteRequest{target_char_id: target.id, target_name: ""},
                 state_for(leader)
               )

      assert_received {:send, :gameplay,
                       {:party_action_result,
                        %PartyActionResult{
                          action: "invite",
                          success: false,
                          error: :TARGET_OFFLINE
                        }}}
    end

    test "a target already in a party acks ALREADY_IN_PARTY" do
      {leader, _party} = party_fixture("Judy")
      {target, _other_party} = party_fixture("Karl")
      register_online(target)

      assert {:noreply, _state} =
               PartyHandler.handle_invite_request(
                 %PartyInviteRequest{target_char_id: target.id, target_name: ""},
                 state_for(leader)
               )

      assert_received {:send, :gameplay,
                       {:party_action_result,
                        %PartyActionResult{
                          action: "invite",
                          success: false,
                          error: :ALREADY_IN_PARTY
                        }}}
    end

    test "a full party acks PARTY_FULL and sends no notify" do
      {leader, party} = party_fixture("Liam")

      filled =
        Enum.reduce(2..Config.max_party(), party, fn n, acc ->
          joiner = character_fixture("Liam#{n}", %{})
          {:ok, joined_state} = PartyManager.add_member(acc.party_id, joiner)
          joined_state
        end)

      assert PartyState.full?(filled)

      overflow_target = character_fixture("Overflow", %{})
      register_online(overflow_target)

      assert {:noreply, _state} =
               PartyHandler.handle_invite_request(
                 %PartyInviteRequest{target_char_id: overflow_target.id, target_name: ""},
                 state_for(leader)
               )

      assert_received {:send, :gameplay,
                       {:party_action_result,
                        %PartyActionResult{action: "invite", success: false, error: :PARTY_FULL}}}

      refute_received {:send, :gameplay, {:party_invite_notify, _}}
    end

    test "a valid invite by target_char_id resolves the target, delivers, and acks success" do
      {leader, party} = party_fixture("Nora")
      target = character_fixture("Otto", %{})
      register_online(target)

      expect(PlayerSession, :deliver_party_invite, fn _pid, invite ->
        assert invite.party_id == party.party_id
        assert invite.inviter_char_id == leader.id
        :ok
      end)

      assert {:noreply, _state} =
               PartyHandler.handle_invite_request(
                 %PartyInviteRequest{target_char_id: target.id, target_name: ""},
                 state_for(leader)
               )

      assert_received {:send, :gameplay,
                       {:party_action_result,
                        %PartyActionResult{action: "invite", success: true, error: :NONE}}}
    end

    test "a valid invite resolves the target by name via the UnitRegistry reverse lookup" do
      {leader, _party} = party_fixture("Petra")
      target = character_fixture("Quinn", %{})
      register_online(target)

      expect(PlayerSession, :deliver_party_invite, fn _pid, _invite -> :ok end)

      assert {:noreply, _state} =
               PartyHandler.handle_invite_request(
                 %PartyInviteRequest{target_char_id: 0, target_name: "Quinn"},
                 state_for(leader)
               )

      assert_received {:send, :gameplay,
                       {:party_action_result,
                        %PartyActionResult{action: "invite", success: true, error: :NONE}}}
    end
  end

  describe "handle_invite_response/2" do
    test "accept with a live pending invite calls add_member and acks success" do
      {_leader, party} = party_fixture("Randy")
      invitee = character_fixture("Sybil", %{})

      pending = %{
        pending_party_invite: %{
          party_id: party.party_id,
          inviter_char_id: 1,
          expires_at: System.monotonic_time(:millisecond) + 30_000
        }
      }

      state = Map.merge(state_for(invitee), pending)

      assert {:noreply, new_state} =
               PartyHandler.handle_invite_response(
                 %PartyInviteResponse{party_id: party.party_id, accept: true},
                 state
               )

      refute Map.has_key?(new_state, :pending_party_invite)

      assert_received {:send, :gameplay,
                       {:party_action_result,
                        %PartyActionResult{
                          action: "invite_response",
                          success: true,
                          error: :NONE
                        }}}

      assert Repo.get(Character, invitee.id).party_id == party.party_id
    end

    test "accept attaches the invitee's own session to the joined party" do
      {_leader, party} = party_fixture("Randy2")
      invitee = character_fixture("Sybil2", %{})

      pending = %{
        pending_party_invite: %{
          party_id: party.party_id,
          inviter_char_id: 1,
          expires_at: System.monotonic_time(:millisecond) + 30_000
        }
      }

      state = Map.merge(state_for(invitee), pending)

      assert {:noreply, new_state} =
               PartyHandler.handle_invite_response(
                 %PartyInviteResponse{party_id: party.party_id, accept: true},
                 state
               )

      assert new_state.game_state.party_id == party.party_id

      assert_received {:send, :gameplay,
                       {:party_info, %PartyInfo{party_id: party_id, members: members}}}

      assert party_id == party.party_id

      wire_member = Enum.find(members, &(&1.char_id == invitee.id))
      assert wire_member.job_id == new_state.game_state.stats.progression.job_id
      assert wire_member.base_level == new_state.game_state.stats.progression.base_level
      assert wire_member.hp == new_state.game_state.stats.current_state.hp
      assert wire_member.max_hp == new_state.game_state.stats.derived_stats.max_hp
      assert wire_member.sp == new_state.game_state.stats.current_state.sp
      assert wire_member.max_sp == new_state.game_state.stats.derived_stats.max_sp
      assert wire_member.ap == new_state.game_state.stats.current_state.ap
      assert wire_member.max_ap == new_state.game_state.stats.derived_stats.max_ap
      assert wire_member.online
      assert wire_member.map == new_state.game_state.map_name

      PubSub.broadcast(Aesir.PubSub, "party:#{party.party_id}", :probe)
      assert_receive :probe
    end

    test "accept with an expired pending invite acks a failure without crashing" do
      invitee = character_fixture("Trent", %{})

      pending = %{
        pending_party_invite: %{
          party_id: 42,
          inviter_char_id: 1,
          expires_at: System.monotonic_time(:millisecond) - 1
        }
      }

      state = Map.merge(state_for(invitee), pending)

      assert {:noreply, _new_state} =
               PartyHandler.handle_invite_response(
                 %PartyInviteResponse{party_id: 42, accept: true},
                 state
               )

      assert_received {:send, :gameplay,
                       {:party_action_result,
                        %PartyActionResult{action: "invite_response", success: false}}}
    end

    test "accept with no pending invite acks a failure without crashing" do
      invitee = character_fixture("Ursula", %{})

      assert {:noreply, _new_state} =
               PartyHandler.handle_invite_response(
                 %PartyInviteResponse{party_id: 42, accept: true},
                 state_for(invitee)
               )

      assert_received {:send, :gameplay,
                       {:party_action_result,
                        %PartyActionResult{action: "invite_response", success: false}}}
    end

    test "decline clears the pending invite and acks success without joining" do
      {_leader, party} = party_fixture("Victor")
      invitee = character_fixture("Wendy", %{})

      pending = %{
        pending_party_invite: %{
          party_id: party.party_id,
          inviter_char_id: 1,
          expires_at: System.monotonic_time(:millisecond) + 30_000
        }
      }

      state = Map.merge(state_for(invitee), pending)

      assert {:noreply, new_state} =
               PartyHandler.handle_invite_response(
                 %PartyInviteResponse{party_id: party.party_id, accept: false},
                 state
               )

      refute Map.has_key?(new_state, :pending_party_invite)
      assert Repo.get(Character, invitee.id).party_id == 0

      assert_received {:send, :gameplay,
                       {:party_action_result,
                        %PartyActionResult{
                          action: "invite_response",
                          success: true,
                          error: :NONE
                        }}}
    end
  end

  describe "handle_kick_request/2" do
    test "the leader kicks a member and acks success" do
      {leader, party} = party_fixture("Xena")
      member = character_fixture("Yusuf", %{})
      {:ok, _joined} = PartyManager.add_member(party.party_id, member)

      assert {:noreply, _state} =
               PartyHandler.handle_kick_request(
                 %PartyKickRequest{target_char_id: member.id},
                 state_for(leader)
               )

      assert_received {:send, :gameplay,
                       {:party_action_result,
                        %PartyActionResult{action: "kick", success: true, error: :NONE}}}

      assert Repo.get(Character, member.id).party_id == 0
    end

    test "a non-leader is rejected with NOT_LEADER" do
      {_leader, party} = party_fixture("Zane")
      member = character_fixture("Abel", %{})
      {:ok, _joined} = PartyManager.add_member(party.party_id, member)

      assert {:noreply, _state} =
               PartyHandler.handle_kick_request(
                 %PartyKickRequest{target_char_id: member.id},
                 state_for(member)
               )

      assert_received {:send, :gameplay,
                       {:party_action_result,
                        %PartyActionResult{action: "kick", success: false, error: :NOT_LEADER}}}
    end
  end

  describe "handle_leader_request/2" do
    test "the leader transfers leadership to an online, same-map member" do
      {leader, party} = party_fixture("Beth")
      target = character_fixture("Cleo", %{})
      {:ok, _joined} = PartyManager.add_member(party.party_id, target)

      assert {:noreply, _state} =
               PartyHandler.handle_leader_request(
                 %PartyLeaderRequest{target_char_id: target.id},
                 state_for(leader)
               )

      assert_received {:send, :gameplay,
                       {:party_action_result,
                        %PartyActionResult{action: "leader", success: true, error: :NONE}}}

      assert Repo.get(Aesir.Commons.Models.Party, party.party_id).leader_char_id == target.id
    end
  end

  describe "handle_options_request/2" do
    test "the leader enables even-share within the level-spread boundary" do
      {leader, party} = party_fixture("Dagny")

      assert {:noreply, _state} =
               PartyHandler.handle_options_request(
                 %PartyOptionsRequest{exp_share: true},
                 state_for(leader)
               )

      assert_received {:send, :gameplay,
                       {:party_action_result,
                        %PartyActionResult{action: "options", success: true, error: :NONE}}}

      assert Repo.get(Aesir.Commons.Models.Party, party.party_id).exp_share == true
    end
  end

  describe "handle_leave_request/2" do
    test "a non-leader member leaves and acks success" do
      {_leader, party} = party_fixture("Elke")
      member = character_fixture("Felix", %{})
      {:ok, _joined} = PartyManager.add_member(party.party_id, member)

      assert {:noreply, _state} =
               PartyHandler.handle_leave_request(%PartyLeaveRequest{}, state_for(member))

      assert_received {:send, :gameplay,
                       {:party_action_result,
                        %PartyActionResult{action: "leave", success: true, error: :NONE}}}

      assert Repo.get(Character, member.id).party_id == 0
    end

    test "the leader leaving disbands the party" do
      {leader, party} = party_fixture("Greta")

      assert {:noreply, _state} =
               PartyHandler.handle_leave_request(%PartyLeaveRequest{}, state_for(leader))

      assert_received {:send, :gameplay,
                       {:party_action_result,
                        %PartyActionResult{action: "leave", success: true, error: :NONE}}}

      assert {:error, :not_found} = PartyManager.get(party.party_id)
    end
  end

  describe "PacketHandler routing" do
    setup do
      base = %{game_state: %PlayerState{character_id: 1}}
      {:ok, base: base}
    end

    test "PartyCreateRequest dispatches to PartyHandler.handle_create_request/2", %{base: base} do
      expect(PartyHandler, :handle_create_request, fn %PartyCreateRequest{}, ^base ->
        {:noreply, base}
      end)

      assert {:noreply, ^base} =
               PacketHandler.handle_message(%PartyCreateRequest{name: "x"}, base)
    end

    test "PartyInviteRequest dispatches to PartyHandler.handle_invite_request/2", %{base: base} do
      expect(PartyHandler, :handle_invite_request, fn %PartyInviteRequest{}, ^base ->
        {:noreply, base}
      end)

      assert {:noreply, ^base} =
               PacketHandler.handle_message(
                 %PartyInviteRequest{target_char_id: 1, target_name: ""},
                 base
               )
    end

    test "PartyInviteResponse dispatches to PartyHandler.handle_invite_response/2", %{base: base} do
      expect(PartyHandler, :handle_invite_response, fn %PartyInviteResponse{}, ^base ->
        {:noreply, base}
      end)

      assert {:noreply, ^base} =
               PacketHandler.handle_message(
                 %PartyInviteResponse{party_id: 1, accept: true},
                 base
               )
    end

    test "PartyLeaveRequest dispatches to PartyHandler.handle_leave_request/2", %{base: base} do
      expect(PartyHandler, :handle_leave_request, fn %PartyLeaveRequest{}, ^base ->
        {:noreply, base}
      end)

      assert {:noreply, ^base} = PacketHandler.handle_message(%PartyLeaveRequest{}, base)
    end

    test "PartyKickRequest dispatches to PartyHandler.handle_kick_request/2", %{base: base} do
      expect(PartyHandler, :handle_kick_request, fn %PartyKickRequest{}, ^base ->
        {:noreply, base}
      end)

      assert {:noreply, ^base} =
               PacketHandler.handle_message(%PartyKickRequest{target_char_id: 2}, base)
    end

    test "PartyOptionsRequest dispatches to PartyHandler.handle_options_request/2", %{base: base} do
      expect(PartyHandler, :handle_options_request, fn %PartyOptionsRequest{}, ^base ->
        {:noreply, base}
      end)

      assert {:noreply, ^base} =
               PacketHandler.handle_message(%PartyOptionsRequest{exp_share: true}, base)
    end

    test "PartyLeaderRequest dispatches to PartyHandler.handle_leader_request/2", %{base: base} do
      expect(PartyHandler, :handle_leader_request, fn %PartyLeaderRequest{}, ^base ->
        {:noreply, base}
      end)

      assert {:noreply, ^base} =
               PacketHandler.handle_message(%PartyLeaderRequest{target_char_id: 2}, base)
    end
  end
end
