defmodule Aesir.ZoneServer.Integration.GuildIntegrationTest do
  @moduledoc """
  End-to-end guild lifecycle across real, concurrent `PlayerSession`s (design
  "Testing Strategy", integration item): create (consuming exactly one Emperium
  and rejecting duplicate-name/no-Emperium/already-in-guild), a cross-session
  invite -> accept joining at the Newbie position, expel (removal + a
  `GuildExpulsion` history row + re-invite), an emblem upload -> fetch round-trip
  that bumps `emblem_id`, position-flag edits and member->position assignment
  gating a subsequent invite, master-leave disbanding and clearing every
  member's `guild_id`, and a nearby player's `UnitSpawn` carrying the member's
  live guild identity.

  `Guild.Manager` and `GuildHandler` run for real against a live Horde entry and
  DB rows; only the usual integration-test I/O (unit registry, spatial index)
  goes through the ETS-backed implementations `IntegrationCase` wires up,
  mirroring `party_integration_test.exs`. Every flow is driven through the real
  `Guild*Request` protocol messages fed to the owning session with no relog:
  `GuildHandler` calls `SocialHandler.attach_to_guild/2` inline during dispatch,
  which updates the requester's live `game_state.guild_id`, subscribes it to
  `"guild:\#{guild_id}"`, and pushes the initial snapshot -- exactly as a login
  would, but without needing one.
  """

  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Commons.ClusterTestHelper
  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.Guild, as: GuildModel
  alias Aesir.Commons.Models.GuildExpulsion
  alias Aesir.Net.GuildActionResult
  alias Aesir.Net.GuildCreateRequest
  alias Aesir.Net.GuildDisbanded
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
  alias Aesir.Net.GuildPositionEditRequest
  alias Aesir.Net.UnitSpawn
  alias Aesir.Repo
  alias Aesir.ZoneServer.Guild.Manager, as: GuildManager
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Inventory.Persistence, as: InventoryPersistence

  @emperium_id 714
  @newbie_position 19

  setup do
    on_exit(&ClusterTestHelper.clear_all/0)
    :ok
  end

  describe "create with Emperium" do
    test "a valid create consumes exactly one Emperium and masters the requester" do
      master = character_fixture("Founder", %{base_level: 50})
      seed_emperium(master.id, 2)
      session = start_session(master)

      simulate_incoming_message(session.pid, %GuildCreateRequest{name: "Vanguard"})

      assert_receive {:packet_sent,
                      %GuildActionResult{action: "create", success: true, error: :GUILD_ERR_NONE},
                      _},
                     1_000

      persisted = Repo.get(Character, master.id)
      assert persisted.guild_id > 0
      assert persisted.guild_position == 0

      assert Inventory.held_amount(get_player_state(session.pid).inventory, @emperium_id) == 1
    end

    test "a duplicate name is rejected and the Emperium is left untouched" do
      {_first, _guild_id} = create_guild("Dup", "Owner1")

      other = character_fixture("Owner2", %{})
      seed_emperium(other.id, 2)
      session = start_session(other)

      simulate_incoming_message(session.pid, %GuildCreateRequest{name: "Dup"})

      assert_receive {:packet_sent,
                      %GuildActionResult{
                        action: "create",
                        success: false,
                        error: :GUILD_ERR_NAME_TAKEN
                      }, _},
                     1_000

      assert Repo.get(Character, other.id).guild_id == 0
      assert Inventory.held_amount(get_player_state(session.pid).inventory, @emperium_id) == 2
    end

    test "a missing Emperium is rejected without creating the guild" do
      loner = character_fixture("Empty", %{})
      session = start_session(loner)

      simulate_incoming_message(session.pid, %GuildCreateRequest{name: "NoEmp"})

      assert_receive {:packet_sent,
                      %GuildActionResult{
                        action: "create",
                        success: false,
                        error: :GUILD_ERR_NO_EMPERIUM
                      }, _},
                     1_000

      assert Repo.get(Character, loner.id).guild_id == 0
    end

    test "already being in a guild is rejected and the Emperium is left untouched" do
      {session, _guild_id} = create_guild("First", "Dave")

      simulate_incoming_message(session.pid, %GuildCreateRequest{name: "Second"})

      assert_receive {:packet_sent,
                      %GuildActionResult{
                        action: "create",
                        success: false,
                        error: :GUILD_ERR_ALREADY_IN_GUILD
                      }, _},
                     1_000

      assert Inventory.held_amount(get_player_state(session.pid).inventory, @emperium_id) == 1
    end
  end

  describe "invite, expel, re-invite" do
    test "cross-session invite -> accept joins at Newbie; expel records history and allows re-invite" do
      {master_session, guild_id} = create_guild("Roster", "Master")

      member = character_fixture("Recruit", %{})
      member_session = start_session(member)

      invite_and_accept(master_session, member_session, member, guild_id)

      joined = Repo.get(Character, member.id)
      assert joined.guild_id == guild_id
      assert joined.guild_position == @newbie_position
      assert get_player_state(member_session.pid).guild_id == guild_id

      simulate_incoming_message(master_session.pid, %GuildExpelRequest{
        target_char_id: member.id,
        reason: "griefing"
      })

      assert_receive {:packet_sent,
                      %GuildActionResult{action: "expel", success: true, error: :GUILD_ERR_NONE},
                      _},
                     1_000

      assert Repo.get(Character, member.id).guild_id == 0

      # The expelled member is a subscribed bystander: the removal broadcast on
      # "guild:{id}" drives its own PlayerSession to clear its live guild_id,
      # not just the DB row.
      assert get_player_state(member_session.pid).guild_id == 0

      expulsion = Repo.get_by(GuildExpulsion, guild_id: guild_id, char_id: member.id)
      assert expulsion.reason == "griefing"
      assert expulsion.name == "Recruit"

      flush_packets()

      invite_and_accept(master_session, member_session, member, guild_id)
      assert Repo.get(Character, member.id).guild_id == guild_id
    end
  end

  describe "emblem upload and fetch" do
    test "upload -> fetch round-trips the blob and bumps emblem_id on each upload" do
      {master_session, guild_id} = create_guild("Emblazoned", "Painter")
      emblem = bmp(24, 24)

      simulate_incoming_message(master_session.pid, %GuildEmblemUploadRequest{data: emblem})

      assert_receive {:packet_sent,
                      %GuildActionResult{
                        action: "emblem_upload",
                        success: true,
                        error: :GUILD_ERR_NONE
                      }, _},
                     1_000

      assert Repo.get(GuildModel, guild_id).emblem_id == 1

      simulate_incoming_message(master_session.pid, %GuildEmblemRequest{
        guild_id: guild_id,
        emblem_id: 1
      })

      assert_receive {:packet_sent,
                      %GuildEmblemData{guild_id: ^guild_id, emblem_id: 1, data: ^emblem}, _},
                     1_000

      simulate_incoming_message(master_session.pid, %GuildEmblemUploadRequest{data: emblem})

      assert_receive {:packet_sent, %GuildActionResult{action: "emblem_upload", success: true},
                      _},
                     1_000

      assert Repo.get(GuildModel, guild_id).emblem_id == 2
    end
  end

  describe "position flags gate actions" do
    test "granting/revoking can_invite and member->position assignment change effective permissions" do
      {master_session, guild_id} = create_guild("Ranks", "Chief")

      officer = character_fixture("Officer", %{})
      officer_session = start_session(officer)
      invite_and_accept(master_session, officer_session, officer, guild_id)

      recruit = character_fixture("Recruit", %{})
      _recruit_session = start_session(recruit)

      # Baseline: a Newbie has no invite flag.
      simulate_incoming_message(officer_session.pid, %GuildInviteRequest{
        target_char_id: recruit.id,
        target_name: ""
      })

      assert_invite_denied()

      # Granting the flag on a slot the officer is not in changes nothing.
      simulate_incoming_message(master_session.pid, %GuildPositionEditRequest{
        index: 5,
        name: "Officer",
        can_invite: true,
        can_expel: false
      })

      assert_position_edit_ok()

      # The edit broadcasts {:social, {:guild_updated, _}} on "guild:{id}"; the
      # officer, a subscribed bystander that did not initiate the edit, gets a
      # fresh GuildInfo push -- exercising SocialHandler's guild pub/sub relay.
      assert_receive {:packet_sent, %GuildInfo{guild_id: ^guild_id}, _}, 1_000

      simulate_incoming_message(officer_session.pid, %GuildInviteRequest{
        target_char_id: recruit.id,
        target_name: ""
      })

      assert_invite_denied()

      # Assigning the officer into the granted slot flips the effective permission.
      simulate_incoming_message(master_session.pid, %GuildMemberPositionRequest{
        target_char_id: officer.id,
        index: 5
      })

      assert_receive {:packet_sent,
                      %GuildActionResult{
                        action: "member_position",
                        success: true,
                        error: :GUILD_ERR_NONE
                      }, _},
                     1_000

      assert Repo.get(Character, officer.id).guild_position == 5

      simulate_incoming_message(officer_session.pid, %GuildInviteRequest{
        target_char_id: recruit.id,
        target_name: ""
      })

      assert_receive {:packet_sent,
                      %GuildActionResult{action: "invite", success: true, error: :GUILD_ERR_NONE},
                      _},
                     1_000

      assert_receive {:packet_sent, %GuildInviteNotify{guild_id: ^guild_id}, _}, 1_000

      # Revoking the flag blocks the officer again.
      simulate_incoming_message(master_session.pid, %GuildPositionEditRequest{
        index: 5,
        name: "Officer",
        can_invite: false,
        can_expel: false
      })

      assert_position_edit_ok()

      other_recruit = character_fixture("Recruit2", %{})
      start_session(other_recruit)

      simulate_incoming_message(officer_session.pid, %GuildInviteRequest{
        target_char_id: other_recruit.id,
        target_name: ""
      })

      assert_invite_denied()
    end
  end

  describe "master leave disbands" do
    test "the master leaving disbands the guild and clears every member's guild_id" do
      {master_session, guild_id} = create_guild("Doomed", "Chieftain")

      member = character_fixture("Follower", %{})
      member_session = start_session(member)
      invite_and_accept(master_session, member_session, member, guild_id)

      master_char_id = master_session.character.id

      simulate_incoming_message(master_session.pid, %GuildLeaveRequest{})

      assert_receive {:packet_sent,
                      %GuildActionResult{action: "leave", success: true, error: :GUILD_ERR_NONE},
                      _},
                     1_000

      assert {:error, :not_found} = GuildManager.get(guild_id)
      assert Repo.get(GuildModel, guild_id) == nil
      assert Repo.get(Character, master_char_id).guild_id == 0
      assert Repo.get(Character, member.id).guild_id == 0

      # The still-subscribed member session receives the disband broadcast on
      # "guild:{id}", pushes GuildDisbanded to its client, and clears its live
      # guild_id -- proving the pub/sub -> PlayerSession relay, not just the DB.
      assert_receive {:packet_sent, %GuildDisbanded{guild_id: ^guild_id}, _}, 1_000
      assert get_player_state(member_session.pid).guild_id == 0
    end
  end

  describe "guild pub/sub reaches subscribed sessions" do
    test "a member joining broadcasts a GuildInfo to a subscribed bystander session" do
      {master_session, guild_id} = create_guild("Broadcasters", "Warden")

      member = character_fixture("Joiner", %{})
      member_session = start_session(member)

      simulate_incoming_message(master_session.pid, %GuildInviteRequest{
        target_char_id: member.id,
        target_name: ""
      })

      assert_receive {:packet_sent, %GuildActionResult{action: "invite", success: true}, _}, 1_000
      assert_receive {:packet_sent, %GuildInviteNotify{guild_id: ^guild_id}, _}, 1_000

      simulate_incoming_message(member_session.pid, %GuildInviteResponse{
        guild_id: guild_id,
        accept: true
      })

      assert_receive {:packet_sent, %GuildActionResult{action: "invite_response", success: true},
                      _},
                     1_000

      # add_member broadcasts {:social, {:guild_updated, _}} on "guild:{id}";
      # the master -- a bystander subscribed since creation -- relays a fresh
      # GuildInfo listing the joiner, alongside the invitee's own attach
      # snapshot, so two arrive. Only the master's requires a live guild
      # pub/sub -> SocialHandler relay.
      infos =
        GuildInfo
        |> collect_packets_of_type(500)
        |> Enum.filter(&(&1.guild_id == guild_id))

      assert length(infos) >= 2

      assert Enum.all?(infos, fn info ->
               Enum.any?(info.members, &(&1.char_id == member.id))
             end)
    end
  end

  describe "nearby snapshot carries guild identity" do
    test "a nearby player's UnitSpawn reflects the member's guild_id, name and emblem_id" do
      {master_session, guild_id} = create_guild("Heraldry", "Bannerman")

      simulate_incoming_message(master_session.pid, %GuildEmblemUploadRequest{data: bmp(24, 24)})

      assert_receive {:packet_sent, %GuildActionResult{action: "emblem_upload", success: true},
                      _},
                     1_000

      observer = character_fixture("Observer", %{})
      observer_session = start_session(observer)

      master_char_id = master_session.character.id

      flush_packets()

      GenServer.cast(observer_session.pid, {:visibility, {:player_entered_view, master_char_id}})

      assert_receive {:packet_sent,
                      %UnitSpawn{
                        gid: ^master_char_id,
                        guild_id: ^guild_id,
                        guild_name: "Heraldry",
                        emblem_id: 1
                      }, _},
                     1_000
    end
  end

  defp create_guild(name, master_name) do
    master = character_fixture(master_name, %{base_level: 50})
    seed_emperium(master.id, 2)
    session = start_session(master)

    simulate_incoming_message(session.pid, %GuildCreateRequest{name: name})

    assert_receive {:packet_sent, %GuildActionResult{action: "create", success: true}, _}, 1_000

    guild_id = Repo.get(Character, master.id).guild_id
    assert guild_id > 0

    flush_packets()

    {session, guild_id}
  end

  defp invite_and_accept(inviter_session, invitee_session, %Character{} = invitee, guild_id) do
    simulate_incoming_message(inviter_session.pid, %GuildInviteRequest{
      target_char_id: invitee.id,
      target_name: ""
    })

    assert_receive {:packet_sent, %GuildActionResult{action: "invite", success: true}, _}, 1_000
    assert_receive {:packet_sent, %GuildInviteNotify{guild_id: ^guild_id}, _}, 1_000

    simulate_incoming_message(invitee_session.pid, %GuildInviteResponse{
      guild_id: guild_id,
      accept: true
    })

    assert_receive {:packet_sent, %GuildActionResult{action: "invite_response", success: true},
                    _},
                   1_000

    flush_packets()
    :ok
  end

  defp assert_invite_denied do
    assert_receive {:packet_sent,
                    %GuildActionResult{
                      action: "invite",
                      success: false,
                      error: :GUILD_ERR_NO_PERMISSION
                    }, _},
                   1_000
  end

  defp assert_position_edit_ok do
    assert_receive {:packet_sent, %GuildActionResult{action: "position_edit", success: true}, _},
                   1_000
  end

  defp start_session(%Character{} = character) do
    start_player_session(character: character, map_name: "prontera", position: {150, 150})
  end

  defp seed_emperium(char_id, amount) do
    {:ok, _item} =
      InventoryPersistence.insert_item(char_id, %{
        nameid: @emperium_id,
        amount: amount,
        identify: 1
      })

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
    account = account_fixture(name)

    {:ok, character} =
      attrs
      |> Enum.into(%{
        char_num: 0,
        class: 0,
        base_level: 1,
        account_id: account.id,
        name: name,
        last_map: "prontera",
        last_x: 150,
        last_y: 150
      })
      |> Character.new()
      |> Repo.insert()

    character
  end

  defp bmp(width, height) do
    "BM" <> <<0::size(16 * 8)>> <> <<width::little-signed-32, height::little-signed-32>>
  end
end
