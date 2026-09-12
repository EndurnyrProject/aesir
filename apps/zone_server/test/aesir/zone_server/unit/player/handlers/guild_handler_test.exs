defmodule Aesir.ZoneServer.Unit.Player.Handlers.GuildHandlerTest do
  use Aesir.DataCase, async: false

  import Ecto.Query
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.ClusterTestHelper
  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.Guild, as: GuildModel
  alias Aesir.Commons.Models.GuildExpulsion
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Net.GuildActionResult
  alias Aesir.Net.GuildAllianceBreakRequest
  alias Aesir.Net.GuildAllianceRequest
  alias Aesir.Net.GuildAllianceRequestNotify
  alias Aesir.Net.GuildAllianceResponse
  alias Aesir.Net.GuildAntagonistRemoveRequest
  alias Aesir.Net.GuildAntagonistRequest
  alias Aesir.Net.GuildCreateRequest
  alias Aesir.Net.GuildEmblemData
  alias Aesir.Net.GuildEmblemRequest
  alias Aesir.Net.GuildEmblemUploadRequest
  alias Aesir.Net.GuildExpelRequest
  alias Aesir.Net.GuildInfo
  alias Aesir.Net.GuildInviteNotify
  alias Aesir.Net.GuildInviteRequest
  alias Aesir.Net.GuildInviteResponse
  alias Aesir.Net.GuildLeaveRequest
  alias Aesir.Net.GuildMemberPositionRequest
  alias Aesir.Net.GuildNoticeEditRequest
  alias Aesir.Net.GuildPositionEditRequest
  alias Aesir.Net.GuildSkillUpRequest
  alias Aesir.ZoneServer.Guild.Manager, as: GuildManager
  alias Aesir.ZoneServer.Guild.Relations
  alias Aesir.ZoneServer.Mmo.Woe.Server, as: WoeServer
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Player.Handlers.GuildHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Aesir.ZoneServer.Unit.Player.Handlers.PacketHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.SocialHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @emperium_id 714
  @newbie_position 19

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

  defp guild_fixture(master_name) do
    master = character_fixture(master_name, %{})
    {:ok, guild_state} = GuildManager.create("Guild-#{master_name}", master)
    {Repo.get(Character, master.id), guild_state}
  end

  defp add_member(guild_id, name) do
    member = character_fixture(name, %{})
    {:ok, _state} = GuildManager.add_member(guild_id, member)
    Repo.get(Character, member.id)
  end

  defp state_for(%Character{} = character, overrides \\ %{}) do
    game_state = PlayerState.new(character)

    %SessionState{
      connection_pid: self(),
      game_state: Map.merge(game_state, overrides)
    }
  end

  defp with_emperium(state) do
    inventory = %{
      0 => %InventoryItem{id: :rand.uniform(1_000_000), nameid: @emperium_id, amount: 1}
    }

    %{state | game_state: %{state.game_state | inventory: inventory}}
  end

  defp register_online(%Character{} = character, pid \\ self()) do
    UnitRegistry.register_player(PlayerState.new(character), pid)
  end

  defp bmp(width, height) do
    "BM" <> <<0::size(16 * 8)>> <> <<width::little-signed-32, height::little-signed-32>>
  end

  describe "handle_create_request/2" do
    test "a valid name consumes one Emperium, creates the guild, and sends GuildInfo" do
      master = character_fixture("Alice", %{})
      state = with_emperium(state_for(master))

      expect(InventoryOps, :remove, fn char_id, inventory, 0, 1 ->
        assert char_id == master.id
        {:ok, Map.delete(inventory, 0), {:removed, 0}}
      end)

      assert {:noreply, new_state} =
               GuildHandler.handle_create_request(%GuildCreateRequest{name: "Vanguard"}, state)

      assert new_state.game_state.inventory == %{}

      assert_received {:send, :gameplay, {:item_removed, _}}

      assert_received {:send, :gameplay,
                       {:guild_action_result,
                        %GuildActionResult{
                          action: "create",
                          success: true,
                          error: :GUILD_ERR_NONE
                        }}}

      assert_received {:send, :gameplay, {:guild_info, %GuildInfo{members: members}}}
      assert Enum.any?(members, &(&1.char_id == master.id and &1.position_index == 0))

      persisted = Repo.get(Character, master.id)
      assert persisted.guild_id > 0
      assert persisted.guild_position == 0
    end

    test "a duplicate name acks NAME_TAKEN and leaves the Emperium untouched" do
      {_master, _guild} = guild_fixture("Bobby")
      other = character_fixture("Carol", %{})
      state = with_emperium(state_for(other))

      reject(&InventoryOps.remove/4)

      assert {:noreply, _state} =
               GuildHandler.handle_create_request(%GuildCreateRequest{name: "Guild-Bobby"}, state)

      assert_received {:send, :gameplay,
                       {:guild_action_result,
                        %GuildActionResult{
                          action: "create",
                          success: false,
                          error: :GUILD_ERR_NAME_TAKEN
                        }}}

      refute_received {:send, :gameplay, {:item_removed, _}}
      assert Repo.get(Character, other.id).guild_id == 0
    end

    test "already being in a guild acks ALREADY_IN_GUILD and leaves the Emperium untouched" do
      {master, _guild} = guild_fixture("Dave")
      state = with_emperium(state_for(master))

      reject(&InventoryOps.remove/4)

      assert {:noreply, _state} =
               GuildHandler.handle_create_request(%GuildCreateRequest{name: "SecondGuild"}, state)

      assert_received {:send, :gameplay,
                       {:guild_action_result,
                        %GuildActionResult{
                          action: "create",
                          success: false,
                          error: :GUILD_ERR_ALREADY_IN_GUILD
                        }}}

      refute_received {:send, :gameplay, {:item_removed, _}}
    end

    test "a missing Emperium acks NO_EMPERIUM without creating the guild" do
      loner = character_fixture("Ellie", %{})
      state = state_for(loner)

      reject(&InventoryOps.remove/4)

      assert {:noreply, _state} =
               GuildHandler.handle_create_request(%GuildCreateRequest{name: "NoEmp"}, state)

      assert_received {:send, :gameplay,
                       {:guild_action_result,
                        %GuildActionResult{
                          action: "create",
                          success: false,
                          error: :GUILD_ERR_NO_EMPERIUM
                        }}}

      assert Repo.get(Character, loner.id).guild_id == 0
    end
  end

  describe "handle_invite_request/2" do
    test "the master invites an online target, delivers, and acks success" do
      {master, guild} = guild_fixture("Fiona")
      target = character_fixture("Gill", %{})
      register_online(target)

      expect(PlayerSession, :deliver_guild_invite, fn _pid, invite ->
        assert invite.guild_id == guild.guild_id
        assert invite.inviter_char_id == master.id
        :ok
      end)

      assert {:noreply, _state} =
               GuildHandler.handle_invite_request(
                 %GuildInviteRequest{target_char_id: target.id, target_name: ""},
                 state_for(master)
               )

      assert_received {:send, :gameplay,
                       {:guild_action_result,
                        %GuildActionResult{
                          action: "invite",
                          success: true,
                          error: :GUILD_ERR_NONE
                        }}}
    end

    test "a member without the INVITE flag acks NO_PERMISSION and delivers nothing" do
      {_master, guild} = guild_fixture("Hana")
      newbie = add_member(guild.guild_id, "Ivos")
      target = character_fixture("Josy", %{})
      register_online(target)

      reject(&PlayerSession.deliver_guild_invite/2)

      assert {:noreply, _state} =
               GuildHandler.handle_invite_request(
                 %GuildInviteRequest{target_char_id: target.id, target_name: ""},
                 state_for(newbie)
               )

      assert_received {:send, :gameplay,
                       {:guild_action_result,
                        %GuildActionResult{
                          action: "invite",
                          success: false,
                          error: :GUILD_ERR_NO_PERMISSION
                        }}}
    end

    test "an offline target acks TARGET_OFFLINE" do
      {master, _guild} = guild_fixture("Kira")
      target = character_fixture("Lios", %{})

      assert {:noreply, _state} =
               GuildHandler.handle_invite_request(
                 %GuildInviteRequest{target_char_id: target.id, target_name: ""},
                 state_for(master)
               )

      assert_received {:send, :gameplay,
                       {:guild_action_result,
                        %GuildActionResult{
                          action: "invite",
                          success: false,
                          error: :GUILD_ERR_TARGET_OFFLINE
                        }}}
    end

    test "a target already in a guild acks ALREADY_IN_GUILD" do
      {master, _guild} = guild_fixture("Mira")
      {other_master, _other} = guild_fixture("Nero")
      register_online(other_master)

      assert {:noreply, _state} =
               GuildHandler.handle_invite_request(
                 %GuildInviteRequest{target_char_id: other_master.id, target_name: ""},
                 state_for(master)
               )

      assert_received {:send, :gameplay,
                       {:guild_action_result,
                        %GuildActionResult{
                          action: "invite",
                          success: false,
                          error: :GUILD_ERR_ALREADY_IN_GUILD
                        }}}
    end
  end

  describe "handle_invite_delivery/2" do
    test "stores the pending invite, sends GuildInviteNotify, and rejects a duplicate" do
      invitee = character_fixture("Otto", %{})
      invite = %{guild_id: 42, guild_name: "Vanguard", inviter_char_id: 1, inviter_name: "Alice"}

      assert {:reply, :ok, state} =
               GuildHandler.handle_invite_delivery(invite, state_for(invitee))

      assert_received {:send, :gameplay,
                       {:guild_invite_notify,
                        %GuildInviteNotify{guild_id: 42, guild_name: "Vanguard"}}}

      assert %{guild_id: 42} = state.pending_guild_invite

      assert {:reply, {:error, :invite_pending}, ^state} =
               GuildHandler.handle_invite_delivery(invite, state)
    end
  end

  describe "handle_invite_response/2" do
    test "accept joins the target at the Newbie position and sends GuildInfo" do
      {_master, guild} = guild_fixture("Petra")
      invitee = character_fixture("Quinn", %{})

      pending = %{
        pending_guild_invite: %{
          guild_id: guild.guild_id,
          inviter_char_id: 1,
          expires_at: System.monotonic_time(:millisecond) + 30_000
        }
      }

      state = Map.merge(state_for(invitee), pending)

      assert {:noreply, new_state} =
               GuildHandler.handle_invite_response(
                 %GuildInviteResponse{guild_id: guild.guild_id, accept: true},
                 state
               )

      assert new_state.pending_guild_invite == nil
      assert new_state.game_state.guild_id == guild.guild_id

      assert_received {:send, :gameplay,
                       {:guild_action_result,
                        %GuildActionResult{
                          action: "invite_response",
                          success: true,
                          error: :GUILD_ERR_NONE
                        }}}

      assert_received {:send, :gameplay, {:guild_info, %GuildInfo{members: members}}}
      joined = Enum.find(members, &(&1.char_id == invitee.id))
      assert joined.position_index == @newbie_position

      persisted = Repo.get(Character, invitee.id)
      assert persisted.guild_id == guild.guild_id
      assert persisted.guild_position == @newbie_position
    end

    test "decline clears the pending invite and acks success without joining" do
      {_master, guild} = guild_fixture("Rhea")
      invitee = character_fixture("Sven", %{})

      pending = %{
        pending_guild_invite: %{
          guild_id: guild.guild_id,
          inviter_char_id: 1,
          expires_at: System.monotonic_time(:millisecond) + 30_000
        }
      }

      state = Map.merge(state_for(invitee), pending)

      assert {:noreply, new_state} =
               GuildHandler.handle_invite_response(
                 %GuildInviteResponse{guild_id: guild.guild_id, accept: false},
                 state
               )

      assert new_state.pending_guild_invite == nil
      assert Repo.get(Character, invitee.id).guild_id == 0

      assert_received {:send, :gameplay,
                       {:guild_action_result,
                        %GuildActionResult{action: "invite_response", success: true}}}
    end

    test "an expired pending invite acks a failure without crashing" do
      invitee = character_fixture("Tara", %{})

      pending = %{
        pending_guild_invite: %{
          guild_id: 42,
          inviter_char_id: 1,
          expires_at: System.monotonic_time(:millisecond) - 1
        }
      }

      state = Map.merge(state_for(invitee), pending)

      assert {:noreply, _new_state} =
               GuildHandler.handle_invite_response(
                 %GuildInviteResponse{guild_id: 42, accept: true},
                 state
               )

      assert_received {:send, :gameplay,
                       {:guild_action_result,
                        %GuildActionResult{action: "invite_response", success: false}}}
    end
  end

  describe "handle_alliance_request/2" do
    test "a non-master requester acks NO_PERMISSION and delivers nothing" do
      {_master, guild} = guild_fixture("Aria")
      newbie = add_member(guild.guild_id, "Milo")
      target = character_fixture("Nash", %{})

      reject(&PlayerSession.deliver_alliance_request/2)

      assert {:noreply, _state} =
               GuildHandler.handle_alliance_request(
                 %GuildAllianceRequest{target_char_id: target.id, target_name: ""},
                 state_for(newbie)
               )

      assert_received {:send, :gameplay,
                       {:guild_action_result,
                        %GuildActionResult{
                          action: "alliance_request",
                          success: false,
                          error: :GUILD_ERR_NO_PERMISSION
                        }}}
    end

    test "a target who is not their guild's master acks NO_PERMISSION" do
      {master, _guild} = guild_fixture("Bram")
      {_target_master, target_guild} = guild_fixture("Cleo")
      target_newbie = add_member(target_guild.guild_id, "Dorn")
      register_online(target_newbie)

      assert {:noreply, _state} =
               GuildHandler.handle_alliance_request(
                 %GuildAllianceRequest{target_char_id: target_newbie.id, target_name: ""},
                 state_for(master)
               )

      assert_received {:send, :gameplay,
                       {:guild_action_result,
                        %GuildActionResult{
                          action: "alliance_request",
                          success: false,
                          error: :GUILD_ERR_NO_PERMISSION
                        }}}
    end

    test "a target in the requester's own guild acks SAME_GUILD" do
      {master, guild} = guild_fixture("Egon")
      member = add_member(guild.guild_id, "Fira")
      register_online(member)

      assert {:noreply, _state} =
               GuildHandler.handle_alliance_request(
                 %GuildAllianceRequest{target_char_id: member.id, target_name: ""},
                 state_for(master)
               )

      assert_received {:send, :gameplay,
                       {:guild_action_result,
                        %GuildActionResult{
                          action: "alliance_request",
                          success: false,
                          error: :GUILD_ERR_SAME_GUILD
                        }}}
    end

    test "a guildless target acks NOT_MEMBER" do
      {master, _guild} = guild_fixture("Gwen")
      target = character_fixture("Hollis", %{})

      assert {:noreply, _state} =
               GuildHandler.handle_alliance_request(
                 %GuildAllianceRequest{target_char_id: target.id, target_name: ""},
                 state_for(master)
               )

      assert_received {:send, :gameplay,
                       {:guild_action_result,
                        %GuildActionResult{
                          action: "alliance_request",
                          success: false,
                          error: :GUILD_ERR_NOT_MEMBER
                        }}}
    end

    test "a valid request against an online target master delivers and acks success" do
      {master, guild} = guild_fixture("Lena")
      {target_master, _target_guild} = guild_fixture("Milo")
      register_online(target_master)

      expect(PlayerSession, :deliver_alliance_request, fn _pid, request ->
        assert request.from_guild_id == guild.guild_id
        assert request.from_guild_name == guild.name
        assert request.requester_char_id == master.id
        assert request.requester_name == master.name
        :ok
      end)

      assert {:noreply, _state} =
               GuildHandler.handle_alliance_request(
                 %GuildAllianceRequest{target_char_id: target_master.id, target_name: ""},
                 state_for(master)
               )

      assert_received {:send, :gameplay,
                       {:guild_action_result,
                        %GuildActionResult{
                          action: "alliance_request",
                          success: true,
                          error: :GUILD_ERR_NONE
                        }}}
    end

    test "a target with a request already pending acks REQUEST_PENDING" do
      {master, guild} = guild_fixture("Jora")
      {target_master, _target_guild} = guild_fixture("Kellan")
      register_online(target_master)

      expect(PlayerSession, :deliver_alliance_request, fn _pid, request ->
        assert request.from_guild_id == guild.guild_id
        {:error, :request_pending}
      end)

      assert {:noreply, _state} =
               GuildHandler.handle_alliance_request(
                 %GuildAllianceRequest{target_char_id: target_master.id, target_name: ""},
                 state_for(master)
               )

      assert_received {:send, :gameplay,
                       {:guild_action_result,
                        %GuildActionResult{
                          action: "alliance_request",
                          success: false,
                          error: :GUILD_ERR_REQUEST_PENDING
                        }}}
    end
  end

  describe "handle_alliance_delivery/2" do
    test "stores the pending request, sends GuildAllianceRequestNotify, and rejects a duplicate" do
      target_master = character_fixture("Ivor", %{})

      request = %{
        from_guild_id: 42,
        from_guild_name: "Vanguard",
        requester_char_id: 1,
        requester_name: "Alice"
      }

      assert {:reply, :ok, state} =
               GuildHandler.handle_alliance_delivery(request, state_for(target_master))

      assert_received {:send, :gameplay,
                       {:guild_alliance_request_notify,
                        %GuildAllianceRequestNotify{
                          guild_id: 42,
                          guild_name: "Vanguard",
                          requester_name: "Alice"
                        }}}

      assert %{from_guild_id: 42} = state.pending_alliance_request

      assert {:reply, {:error, :request_pending}, ^state} =
               GuildHandler.handle_alliance_delivery(request, state)
    end
  end

  describe "handle_alliance_response/2" do
    test "no pending request for guild_id acks NOT_MEMBER" do
      {master, _guild} = guild_fixture("Nadia")

      assert {:noreply, _state} =
               GuildHandler.handle_alliance_response(
                 %GuildAllianceResponse{guild_id: 999, accept: true},
                 state_for(master)
               )

      assert_received {:send, :gameplay,
                       {:guild_action_result,
                        %GuildActionResult{
                          action: "alliance_response",
                          success: false,
                          error: :GUILD_ERR_NOT_MEMBER
                        }}}
    end

    test "accept calls Relations.ally/2 with (responder_guild_id, from_guild_id) and clears the pending request" do
      {responder, responder_guild} = guild_fixture("Otis")

      pending = %{
        pending_alliance_request: %{
          from_guild_id: 77,
          from_guild_name: "Requesters",
          requester_char_id: 5,
          expires_at: System.monotonic_time(:millisecond) + 30_000
        }
      }

      state = Map.merge(state_for(responder), pending)

      expect(Relations, :ally, fn responder_guild_id, from_guild_id ->
        assert responder_guild_id == responder_guild.guild_id
        assert from_guild_id == 77
        :ok
      end)

      assert {:noreply, new_state} =
               GuildHandler.handle_alliance_response(
                 %GuildAllianceResponse{guild_id: 77, accept: true},
                 state
               )

      assert new_state.pending_alliance_request == nil

      assert_received {:send, :gameplay,
                       {:guild_action_result,
                        %GuildActionResult{
                          action: "alliance_response",
                          success: true,
                          error: :GUILD_ERR_NONE
                        }}}
    end

    test "decline notifies the requester with ALLIANCE_DECLINED and clears the pending request" do
      {responder, _guild} = guild_fixture("Petra")
      requester = character_fixture("Quill", %{})

      pending = %{
        pending_alliance_request: %{
          from_guild_id: 88,
          from_guild_name: "Requesters",
          requester_char_id: requester.id,
          expires_at: System.monotonic_time(:millisecond) + 30_000
        }
      }

      state = Map.merge(state_for(responder), pending)

      expect(Broadcast, :to_player, fn char_id, packet ->
        assert char_id == requester.id

        assert %GuildActionResult{
                 action: "alliance_request",
                 success: false,
                 error: :GUILD_ERR_ALLIANCE_DECLINED
               } = packet

        :ok
      end)

      assert {:noreply, new_state} =
               GuildHandler.handle_alliance_response(
                 %GuildAllianceResponse{guild_id: 88, accept: false},
                 state
               )

      assert new_state.pending_alliance_request == nil

      assert_received {:send, :gameplay,
                       {:guild_action_result,
                        %GuildActionResult{
                          action: "alliance_response",
                          success: true,
                          error: :GUILD_ERR_NONE
                        }}}
    end

    test "an already-expired pending request acks NOT_MEMBER and clears the pending request" do
      {responder, _guild} = guild_fixture("Renata")

      pending = %{
        pending_alliance_request: %{
          from_guild_id: 99,
          from_guild_name: "Requesters",
          requester_char_id: 5,
          expires_at: System.monotonic_time(:millisecond) - 1
        }
      }

      state = Map.merge(state_for(responder), pending)

      assert {:noreply, new_state} =
               GuildHandler.handle_alliance_response(
                 %GuildAllianceResponse{guild_id: 99, accept: true},
                 state
               )

      assert new_state.pending_alliance_request == nil

      assert_received {:send, :gameplay,
                       {:guild_action_result,
                        %GuildActionResult{
                          action: "alliance_response",
                          success: false,
                          error: :GUILD_ERR_NOT_MEMBER
                        }}}
    end
  end

  describe "handle_alliance_break_request/2" do
    test "the master breaks an existing alliance" do
      {master_a, guild_a} = guild_fixture("Rurik")
      {master_b, guild_b} = guild_fixture("Silas")
      register_online(master_b)
      assert :ok = Relations.ally(guild_a.guild_id, guild_b.guild_id)

      assert {:noreply, _state} =
               GuildHandler.handle_alliance_break_request(
                 %GuildAllianceBreakRequest{guild_id: guild_b.guild_id},
                 state_for(master_a)
               )

      assert_received {:send, :gameplay,
                       {:guild_action_result,
                        %GuildActionResult{
                          action: "alliance_break",
                          success: true,
                          error: :GUILD_ERR_NONE
                        }}}
    end

    test "an active siege refuses the break with SIEGE_ACTIVE" do
      {master_a, _guild_a} = guild_fixture("Tamsin")
      {_master_b, guild_b} = guild_fixture("Ulric")

      stub(WoeServer, :active?, fn -> true end)

      assert {:noreply, _state} =
               GuildHandler.handle_alliance_break_request(
                 %GuildAllianceBreakRequest{guild_id: guild_b.guild_id},
                 state_for(master_a)
               )

      assert_received {:send, :gameplay,
                       {:guild_action_result,
                        %GuildActionResult{
                          action: "alliance_break",
                          success: false,
                          error: :GUILD_ERR_SIEGE_ACTIVE
                        }}}
    end
  end

  describe "handle_antagonist_request/2" do
    test "the master declares an antagonist against an online target's guild" do
      {master, _guild} = guild_fixture("Vesna")
      {target_master, _target_guild} = guild_fixture("Wren")
      register_online(target_master)

      assert {:noreply, _state} =
               GuildHandler.handle_antagonist_request(
                 %GuildAntagonistRequest{target_char_id: target_master.id, target_name: ""},
                 state_for(master)
               )

      assert_received {:send, :gameplay,
                       {:guild_action_result,
                        %GuildActionResult{
                          action: "antagonist",
                          success: true,
                          error: :GUILD_ERR_NONE
                        }}}
    end

    test "the antagonist limit refuses a fourth declaration" do
      {master, guild} = guild_fixture("Xerxes")

      Enum.each(1..3, fn n ->
        {other_master, _other_guild} = guild_fixture("Yara#{n}")
        register_online(other_master)
        assert :ok = Relations.declare_antagonist(guild.guild_id, other_master.guild_id)
      end)

      {fourth_master, _fourth_guild} = guild_fixture("Zelah")
      register_online(fourth_master)

      assert {:noreply, _state} =
               GuildHandler.handle_antagonist_request(
                 %GuildAntagonistRequest{target_char_id: fourth_master.id, target_name: ""},
                 state_for(master)
               )

      assert_received {:send, :gameplay,
                       {:guild_action_result,
                        %GuildActionResult{
                          action: "antagonist",
                          success: false,
                          error: :GUILD_ERR_ANTAGONIST_LIMIT
                        }}}
    end
  end

  describe "handle_antagonist_remove_request/2" do
    test "the master removes an existing antagonist declaration" do
      {master, guild} = guild_fixture("Aldric")
      {other_master, other_guild} = guild_fixture("Bellamy")
      register_online(other_master)
      assert :ok = Relations.declare_antagonist(guild.guild_id, other_guild.guild_id)

      assert {:noreply, _state} =
               GuildHandler.handle_antagonist_remove_request(
                 %GuildAntagonistRemoveRequest{guild_id: other_guild.guild_id},
                 state_for(master)
               )

      assert_received {:send, :gameplay,
                       {:guild_action_result,
                        %GuildActionResult{
                          action: "antagonist_remove",
                          success: true,
                          error: :GUILD_ERR_NONE
                        }}}
    end

    test "a missing antagonist relation refuses with NOT_RELATED" do
      {master, _guild} = guild_fixture("Cadmus")
      {_other_master, other_guild} = guild_fixture("Delia")

      assert {:noreply, _state} =
               GuildHandler.handle_antagonist_remove_request(
                 %GuildAntagonistRemoveRequest{guild_id: other_guild.guild_id},
                 state_for(master)
               )

      assert_received {:send, :gameplay,
                       {:guild_action_result,
                        %GuildActionResult{
                          action: "antagonist_remove",
                          success: false,
                          error: :GUILD_ERR_NOT_RELATED
                        }}}
    end
  end

  describe "alliance_request_expired/1" do
    test "an expired pending request notifies the requester and clears itself" do
      requester = character_fixture("Finn", %{})

      pending = %{
        pending_alliance_request: %{
          from_guild_id: 5,
          from_guild_name: "Vanguard",
          requester_char_id: requester.id,
          expires_at: System.monotonic_time(:millisecond) - 1
        }
      }

      responder = character_fixture("Greer", %{})
      state = Map.merge(state_for(responder), pending)

      expect(Broadcast, :to_player, fn char_id, packet ->
        assert char_id == requester.id

        assert %GuildActionResult{
                 action: "alliance_request",
                 success: false,
                 error: :GUILD_ERR_ALLIANCE_DECLINED
               } = packet

        :ok
      end)

      assert {:noreply, new_state} = SocialHandler.alliance_request_expired(state)

      assert new_state.pending_alliance_request == nil
    end

    test "a not-yet-expired pending request is left untouched" do
      pending = %{
        pending_alliance_request: %{
          from_guild_id: 5,
          from_guild_name: "Vanguard",
          requester_char_id: 1,
          expires_at: System.monotonic_time(:millisecond) + 30_000
        }
      }

      responder = character_fixture("Halden", %{})
      state = Map.merge(state_for(responder), pending)

      assert {:noreply, ^state} = SocialHandler.alliance_request_expired(state)
      refute_received {:send, :gameplay, {:guild_action_result, _}}
    end

    test "no pending request is a no-op" do
      responder = character_fixture("Ilsa", %{})
      state = state_for(responder)

      assert {:noreply, ^state} = SocialHandler.alliance_request_expired(state)
    end
  end

  describe "handle_expel_request/2" do
    test "an EXPEL-holder removes the target and records an expulsion" do
      {master, guild} = guild_fixture("Umah")
      member = add_member(guild.guild_id, "Vlad")

      assert {:noreply, _state} =
               GuildHandler.handle_expel_request(
                 %GuildExpelRequest{target_char_id: member.id, reason: "afk"},
                 state_for(master)
               )

      assert_received {:send, :gameplay,
                       {:guild_action_result,
                        %GuildActionResult{action: "expel", success: true, error: :GUILD_ERR_NONE}}}

      assert Repo.get(Character, member.id).guild_id == 0
      assert Repo.get_by(GuildExpulsion, guild_id: guild.guild_id, char_id: member.id)
    end

    test "a member without the EXPEL flag is rejected with NO_PERMISSION" do
      {_master, guild} = guild_fixture("Wren")
      newbie = add_member(guild.guild_id, "Xander")
      victim = add_member(guild.guild_id, "Yuki")

      assert {:noreply, _state} =
               GuildHandler.handle_expel_request(
                 %GuildExpelRequest{target_char_id: victim.id, reason: ""},
                 state_for(newbie)
               )

      assert_received {:send, :gameplay,
                       {:guild_action_result,
                        %GuildActionResult{
                          action: "expel",
                          success: false,
                          error: :GUILD_ERR_NO_PERMISSION
                        }}}

      assert Repo.get(Character, victim.id).guild_id == guild.guild_id
    end

    test "targeting the master is rejected with CANNOT_TARGET_MASTER" do
      {master, _guild} = guild_fixture("Zeddy")

      assert {:noreply, _state} =
               GuildHandler.handle_expel_request(
                 %GuildExpelRequest{target_char_id: master.id, reason: ""},
                 state_for(master)
               )

      assert_received {:send, :gameplay,
                       {:guild_action_result,
                        %GuildActionResult{
                          action: "expel",
                          success: false,
                          error: :GUILD_ERR_CANNOT_TARGET_MASTER
                        }}}
    end
  end

  describe "handle_leave_request/2" do
    test "a member leaves and acks success" do
      {_master, guild} = guild_fixture("Abel")
      member = add_member(guild.guild_id, "Beah")

      assert {:noreply, _state} =
               GuildHandler.handle_leave_request(%GuildLeaveRequest{}, state_for(member))

      assert_received {:send, :gameplay,
                       {:guild_action_result,
                        %GuildActionResult{action: "leave", success: true, error: :GUILD_ERR_NONE}}}

      assert Repo.get(Character, member.id).guild_id == 0
    end

    test "the master leaving disbands the guild and clears every member's guild_id" do
      {master, guild} = guild_fixture("Cara")
      member = add_member(guild.guild_id, "Dorian")

      assert {:noreply, _state} =
               GuildHandler.handle_leave_request(%GuildLeaveRequest{}, state_for(master))

      assert_received {:send, :gameplay,
                       {:guild_action_result,
                        %GuildActionResult{action: "leave", success: true, error: :GUILD_ERR_NONE}}}

      assert {:error, :not_found} = GuildManager.get(guild.guild_id)
      assert Repo.get(Character, master.id).guild_id == 0
      assert Repo.get(Character, member.id).guild_id == 0
    end
  end

  describe "handle_position_edit_request/2" do
    test "the master edits a non-zero slot's flags" do
      {master, guild} = guild_fixture("Elsa")

      assert {:noreply, _state} =
               GuildHandler.handle_position_edit_request(
                 %GuildPositionEditRequest{
                   index: 5,
                   name: "Officer",
                   can_invite: true,
                   can_expel: true,
                   can_storage: true
                 },
                 state_for(master)
               )

      assert_received {:send, :gameplay,
                       {:guild_action_result,
                        %GuildActionResult{
                          action: "position_edit",
                          success: true,
                          error: :GUILD_ERR_NONE
                        }}}

      {:ok, live} = GuildManager.get(guild.guild_id)
      assert live.positions[5].can_invite
      assert live.positions[5].can_storage
    end

    test "an older client preserves can_storage by omitting it" do
      {master, guild} = guild_fixture("OlderClient")

      assert {:ok, _state} =
               GuildManager.edit_position(guild.guild_id, master.id, %{
                 index: 5,
                 name: "Storage Officer",
                 can_invite: false,
                 can_expel: false,
                 can_storage: true
               })

      assert {:noreply, _state} =
               GuildHandler.handle_position_edit_request(
                 %GuildPositionEditRequest{
                   index: 5,
                   name: "Officer",
                   can_invite: true,
                   can_expel: false
                 },
                 state_for(master)
               )

      assert_received {:send, :gameplay,
                       {:guild_action_result,
                        %GuildActionResult{action: "position_edit", success: true}}}

      {:ok, live} = GuildManager.get(guild.guild_id)
      assert live.positions[5].can_storage
    end

    test "a non-master member is rejected with NO_PERMISSION" do
      {_master, guild} = guild_fixture("Finn")
      newbie = add_member(guild.guild_id, "Gwen")

      assert {:noreply, _state} =
               GuildHandler.handle_position_edit_request(
                 %GuildPositionEditRequest{
                   index: 5,
                   name: "Officer",
                   can_invite: true,
                   can_expel: false
                 },
                 state_for(newbie)
               )

      assert_received {:send, :gameplay,
                       {:guild_action_result,
                        %GuildActionResult{
                          action: "position_edit",
                          success: false,
                          error: :GUILD_ERR_NO_PERMISSION
                        }}}
    end
  end

  describe "handle_notice_edit_request/2" do
    test "the master edits the guild notice" do
      {master, guild} = guild_fixture("Nadia")

      assert {:noreply, _state} =
               GuildHandler.handle_notice_edit_request(
                 %GuildNoticeEditRequest{subject: "Raid tonight", body: "Meet at 8pm"},
                 state_for(master)
               )

      assert_received {:send, :gameplay,
                       {:guild_action_result,
                        %GuildActionResult{
                          action: "notice_edit",
                          success: true,
                          error: :GUILD_ERR_NONE
                        }}}

      {:ok, live} = GuildManager.get(guild.guild_id)
      assert live.notice.subject == "Raid tonight"
      assert live.notice.body == "Meet at 8pm"
    end

    test "a non-master member is rejected with NO_PERMISSION" do
      {_master, guild} = guild_fixture("Oscar")
      newbie = add_member(guild.guild_id, "Petra")

      assert {:noreply, _state} =
               GuildHandler.handle_notice_edit_request(
                 %GuildNoticeEditRequest{subject: "Nope", body: "Denied"},
                 state_for(newbie)
               )

      assert_received {:send, :gameplay,
                       {:guild_action_result,
                        %GuildActionResult{
                          action: "notice_edit",
                          success: false,
                          error: :GUILD_ERR_NO_PERMISSION
                        }}}
    end
  end

  describe "handle_skill_up_request/2" do
    defp grant_points(guild_id, points) do
      {1, nil} =
        from(g in GuildModel, where: g.id == ^guild_id)
        |> Repo.update_all(set: [skill_points: points])

      ClusterTestHelper.clear_all()
      {:ok, _} = GuildManager.ensure_started(guild_id)
      :ok
    end

    test "the master learns a guild skill and gets a success ack" do
      {master, guild} = guild_fixture("SkillMaster")
      :ok = grant_points(guild.guild_id, 1)

      assert {:noreply, _state} =
               GuildHandler.handle_skill_up_request(
                 %GuildSkillUpRequest{skill_id: 10_000},
                 state_for(master)
               )

      assert_received {:send, :gameplay,
                       {:guild_action_result,
                        %GuildActionResult{
                          action: "skill_up",
                          success: true,
                          error: :GUILD_ERR_NONE
                        }}}

      {:ok, live} = GuildManager.get(guild.guild_id)
      assert live.learned_skills == %{10_000 => 1}
      assert live.skill_points == 0
    end

    test "a non-master member is rejected without mutation" do
      {_master, guild} = guild_fixture("SkillBoss")
      newbie = add_member(guild.guild_id, "SkillPeon")
      :ok = grant_points(guild.guild_id, 1)

      assert {:noreply, _state} =
               GuildHandler.handle_skill_up_request(
                 %GuildSkillUpRequest{skill_id: 10_000},
                 state_for(newbie)
               )

      assert_received {:send, :gameplay,
                       {:guild_action_result,
                        %GuildActionResult{
                          action: "skill_up",
                          success: false,
                          error: :GUILD_ERR_NO_PERMISSION
                        }}}

      {:ok, live} = GuildManager.get(guild.guild_id)
      assert live.learned_skills == %{}
    end

    test "spending without points reports NO_SKILL_POINTS" do
      {master, guild} = guild_fixture("SkillBroke")

      assert {:noreply, _state} =
               GuildHandler.handle_skill_up_request(
                 %GuildSkillUpRequest{skill_id: 10_000},
                 state_for(master)
               )

      assert_received {:send, :gameplay,
                       {:guild_action_result,
                        %GuildActionResult{
                          action: "skill_up",
                          success: false,
                          error: :GUILD_ERR_NO_SKILL_POINTS
                        }}}

      {:ok, live} = GuildManager.get(guild.guild_id)
      assert live.learned_skills == %{}
    end
  end

  describe "handle_member_position_request/2" do
    test "the master assigns a member to a position slot" do
      {master, guild} = guild_fixture("Hugo")
      member = add_member(guild.guild_id, "Idah")

      assert {:noreply, _state} =
               GuildHandler.handle_member_position_request(
                 %GuildMemberPositionRequest{target_char_id: member.id, index: 5},
                 state_for(master)
               )

      assert_received {:send, :gameplay,
                       {:guild_action_result,
                        %GuildActionResult{
                          action: "member_position",
                          success: true,
                          error: :GUILD_ERR_NONE
                        }}}

      assert Repo.get(Character, member.id).guild_position == 5
    end

    test "a non-master member is rejected with NO_PERMISSION" do
      {_master, guild} = guild_fixture("Jaey")
      newbie = add_member(guild.guild_id, "Kaii")
      other = add_member(guild.guild_id, "Lena")

      assert {:noreply, _state} =
               GuildHandler.handle_member_position_request(
                 %GuildMemberPositionRequest{target_char_id: other.id, index: 5},
                 state_for(newbie)
               )

      assert_received {:send, :gameplay,
                       {:guild_action_result,
                        %GuildActionResult{
                          action: "member_position",
                          success: false,
                          error: :GUILD_ERR_NO_PERMISSION
                        }}}

      assert Repo.get(Character, other.id).guild_position == @newbie_position
    end
  end

  describe "handle_emblem_upload_request/2" do
    test "the master uploads a valid emblem, bumping emblem_id and persisting the blob" do
      {master, guild} = guild_fixture("Emil")
      Phoenix.PubSub.subscribe(Aesir.PubSub, "guild:#{guild.guild_id}")
      emblem = bmp(24, 24)

      assert {:noreply, _state} =
               GuildHandler.handle_emblem_upload_request(
                 %GuildEmblemUploadRequest{data: emblem},
                 state_for(master)
               )

      assert_received {:send, :gameplay,
                       {:guild_action_result,
                        %GuildActionResult{
                          action: "emblem_upload",
                          success: true,
                          error: :GUILD_ERR_NONE
                        }}}

      assert_receive {:social, {:guild_emblem_changed, guild_id, 1}}
      assert guild_id == guild.guild_id

      persisted = Repo.get(GuildModel, guild.guild_id)
      assert persisted.emblem_id == 1
      assert persisted.emblem_data == emblem
    end

    test "a non-master upload is rejected with NO_PERMISSION and leaves the emblem unchanged" do
      {_master, guild} = guild_fixture("Fabio")
      newbie = add_member(guild.guild_id, "Gina")

      assert {:noreply, _state} =
               GuildHandler.handle_emblem_upload_request(
                 %GuildEmblemUploadRequest{data: bmp(24, 24)},
                 state_for(newbie)
               )

      assert_received {:send, :gameplay,
                       {:guild_action_result,
                        %GuildActionResult{
                          action: "emblem_upload",
                          success: false,
                          error: :GUILD_ERR_NO_PERMISSION
                        }}}

      persisted = Repo.get(GuildModel, guild.guild_id)
      assert persisted.emblem_id == 0
      assert is_nil(persisted.emblem_data)
    end

    test "an invalid emblem is rejected with INVALID_EMBLEM and leaves the emblem unchanged" do
      {master, guild} = guild_fixture("Hilda")

      assert {:noreply, _state} =
               GuildHandler.handle_emblem_upload_request(
                 %GuildEmblemUploadRequest{data: bmp(32, 32)},
                 state_for(master)
               )

      assert_received {:send, :gameplay,
                       {:guild_action_result,
                        %GuildActionResult{
                          action: "emblem_upload",
                          success: false,
                          error: :GUILD_ERR_INVALID_EMBLEM
                        }}}

      persisted = Repo.get(GuildModel, guild.guild_id)
      assert persisted.emblem_id == 0
      assert is_nil(persisted.emblem_data)
    end
  end

  describe "handle_emblem_request/2" do
    test "returns the stored emblem blob for an existing guild" do
      {master, guild} = guild_fixture("Iris")
      emblem = bmp(24, 24)

      {:ok, emblem_id} = GuildManager.change_emblem(guild.guild_id, master.id, emblem)

      assert {:noreply, _state} =
               GuildHandler.handle_emblem_request(
                 %GuildEmblemRequest{guild_id: guild.guild_id, emblem_id: emblem_id},
                 state_for(master)
               )

      assert_received {:send, :gameplay,
                       {:guild_emblem_data,
                        %GuildEmblemData{
                          guild_id: guild_id,
                          emblem_id: ^emblem_id,
                          data: ^emblem
                        }}}

      assert guild_id == guild.guild_id
    end

    test "a request for a nonexistent guild acks an error without crashing" do
      loner = character_fixture("Jonas", %{})

      assert {:noreply, _state} =
               GuildHandler.handle_emblem_request(
                 %GuildEmblemRequest{guild_id: 999_999, emblem_id: 0},
                 state_for(loner)
               )

      assert_received {:send, :gameplay,
                       {:guild_action_result,
                        %GuildActionResult{action: "emblem_request", success: false}}}
    end

    test "a guild without an emblem acks an error without crashing" do
      {master, guild} = guild_fixture("Klaus")

      assert {:noreply, _state} =
               GuildHandler.handle_emblem_request(
                 %GuildEmblemRequest{guild_id: guild.guild_id, emblem_id: 0},
                 state_for(master)
               )

      assert_received {:send, :gameplay,
                       {:guild_action_result,
                        %GuildActionResult{action: "emblem_request", success: false}}}
    end
  end

  describe "PacketHandler routing" do
    setup do
      base = %{game_state: %PlayerState{character_id: 1}}
      {:ok, base: base}
    end

    test "GuildCreateRequest dispatches to GuildHandler.handle_create_request/2", %{base: base} do
      expect(GuildHandler, :handle_create_request, fn %GuildCreateRequest{}, ^base ->
        {:noreply, base}
      end)

      assert {:noreply, ^base} =
               PacketHandler.handle_message(%GuildCreateRequest{name: "x"}, base)
    end

    test "GuildInviteRequest dispatches to GuildHandler.handle_invite_request/2", %{base: base} do
      expect(GuildHandler, :handle_invite_request, fn %GuildInviteRequest{}, ^base ->
        {:noreply, base}
      end)

      assert {:noreply, ^base} =
               PacketHandler.handle_message(
                 %GuildInviteRequest{target_char_id: 1, target_name: ""},
                 base
               )
    end

    test "GuildInviteResponse dispatches to GuildHandler.handle_invite_response/2", %{base: base} do
      expect(GuildHandler, :handle_invite_response, fn %GuildInviteResponse{}, ^base ->
        {:noreply, base}
      end)

      assert {:noreply, ^base} =
               PacketHandler.handle_message(
                 %GuildInviteResponse{guild_id: 1, accept: true},
                 base
               )
    end

    test "GuildLeaveRequest dispatches to GuildHandler.handle_leave_request/2", %{base: base} do
      expect(GuildHandler, :handle_leave_request, fn %GuildLeaveRequest{}, ^base ->
        {:noreply, base}
      end)

      assert {:noreply, ^base} = PacketHandler.handle_message(%GuildLeaveRequest{}, base)
    end

    test "GuildExpelRequest dispatches to GuildHandler.handle_expel_request/2", %{base: base} do
      expect(GuildHandler, :handle_expel_request, fn %GuildExpelRequest{}, ^base ->
        {:noreply, base}
      end)

      assert {:noreply, ^base} =
               PacketHandler.handle_message(
                 %GuildExpelRequest{target_char_id: 2, reason: ""},
                 base
               )
    end

    test "GuildPositionEditRequest dispatches to GuildHandler.handle_position_edit_request/2", %{
      base: base
    } do
      expect(GuildHandler, :handle_position_edit_request, fn %GuildPositionEditRequest{}, ^base ->
        {:noreply, base}
      end)

      assert {:noreply, ^base} =
               PacketHandler.handle_message(
                 %GuildPositionEditRequest{
                   index: 5,
                   name: "x",
                   can_invite: true,
                   can_expel: false
                 },
                 base
               )
    end

    test "GuildNoticeEditRequest dispatches to GuildHandler.handle_notice_edit_request/2", %{
      base: base
    } do
      expect(GuildHandler, :handle_notice_edit_request, fn %GuildNoticeEditRequest{}, ^base ->
        {:noreply, base}
      end)

      assert {:noreply, ^base} =
               PacketHandler.handle_message(
                 %GuildNoticeEditRequest{subject: "s", body: "b"},
                 base
               )
    end

    test "GuildMemberPositionRequest dispatches to GuildHandler.handle_member_position_request/2",
         %{base: base} do
      expect(GuildHandler, :handle_member_position_request, fn %GuildMemberPositionRequest{},
                                                               ^base ->
        {:noreply, base}
      end)

      assert {:noreply, ^base} =
               PacketHandler.handle_message(
                 %GuildMemberPositionRequest{target_char_id: 2, index: 5},
                 base
               )
    end

    test "GuildEmblemUploadRequest dispatches to GuildHandler.handle_emblem_upload_request/2", %{
      base: base
    } do
      expect(GuildHandler, :handle_emblem_upload_request, fn %GuildEmblemUploadRequest{}, ^base ->
        {:noreply, base}
      end)

      assert {:noreply, ^base} =
               PacketHandler.handle_message(%GuildEmblemUploadRequest{data: "BM"}, base)
    end

    test "GuildEmblemRequest dispatches to GuildHandler.handle_emblem_request/2", %{base: base} do
      expect(GuildHandler, :handle_emblem_request, fn %GuildEmblemRequest{}, ^base ->
        {:noreply, base}
      end)

      assert {:noreply, ^base} =
               PacketHandler.handle_message(
                 %GuildEmblemRequest{guild_id: 1, emblem_id: 0},
                 base
               )
    end

    test "GuildAllianceRequest dispatches to GuildHandler.handle_alliance_request/2", %{
      base: base
    } do
      expect(GuildHandler, :handle_alliance_request, fn %GuildAllianceRequest{}, ^base ->
        {:noreply, base}
      end)

      assert {:noreply, ^base} =
               PacketHandler.handle_message(
                 %GuildAllianceRequest{target_char_id: 2, target_name: ""},
                 base
               )
    end

    test "GuildAllianceResponse dispatches to GuildHandler.handle_alliance_response/2", %{
      base: base
    } do
      expect(GuildHandler, :handle_alliance_response, fn %GuildAllianceResponse{}, ^base ->
        {:noreply, base}
      end)

      assert {:noreply, ^base} =
               PacketHandler.handle_message(
                 %GuildAllianceResponse{guild_id: 1, accept: true},
                 base
               )
    end

    test "GuildAllianceBreakRequest dispatches to GuildHandler.handle_alliance_break_request/2",
         %{base: base} do
      expect(GuildHandler, :handle_alliance_break_request, fn %GuildAllianceBreakRequest{},
                                                              ^base ->
        {:noreply, base}
      end)

      assert {:noreply, ^base} =
               PacketHandler.handle_message(%GuildAllianceBreakRequest{guild_id: 1}, base)
    end

    test "GuildAntagonistRequest dispatches to GuildHandler.handle_antagonist_request/2", %{
      base: base
    } do
      expect(GuildHandler, :handle_antagonist_request, fn %GuildAntagonistRequest{}, ^base ->
        {:noreply, base}
      end)

      assert {:noreply, ^base} =
               PacketHandler.handle_message(
                 %GuildAntagonistRequest{target_char_id: 2, target_name: ""},
                 base
               )
    end

    test "GuildAntagonistRemoveRequest dispatches to GuildHandler.handle_antagonist_remove_request/2",
         %{base: base} do
      expect(GuildHandler, :handle_antagonist_remove_request, fn %GuildAntagonistRemoveRequest{},
                                                                 ^base ->
        {:noreply, base}
      end)

      assert {:noreply, ^base} =
               PacketHandler.handle_message(%GuildAntagonistRemoveRequest{guild_id: 1}, base)
    end
  end
end
