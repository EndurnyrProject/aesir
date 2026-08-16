defmodule Aesir.ZoneServer.Integration.GuildProgressionIntegrationTest do
  @moduledoc """
  End-to-end guild progression across real `PlayerSession`s: member EXP
  taxation feeding guild level-ups with client notification, skill point
  allocation through the wire raising Guild Extension capacity on a live
  invite, and a guild-scoped cast cooldown surviving the master's relog.

  Mirrors `guild_integration_test.exs`: `Guild.Manager`, `GuildHandler`, and
  the skill Interpreter run for real against a live Horde entry and DB rows;
  flows are driven through real protocol messages fed to the owning session.
  """

  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  import Ecto.Query

  alias Aesir.Commons.ClusterTestHelper
  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.Guild, as: GuildModel
  alias Aesir.Net.GuildActionResult
  alias Aesir.Net.GuildCreateRequest
  alias Aesir.Net.GuildInfo
  alias Aesir.Net.GuildInviteNotify
  alias Aesir.Net.GuildInviteRequest
  alias Aesir.Net.GuildInviteResponse
  alias Aesir.Net.GuildLevelUp
  alias Aesir.Net.GuildPositionEditRequest
  alias Aesir.Net.GuildSkillUpRequest
  alias Aesir.Net.SkillCast
  alias Aesir.Net.SkillCastFailed
  alias Aesir.Repo
  alias Aesir.ZoneServer.Guild.Manager, as: GuildManager
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Inventory.Persistence, as: InventoryPersistence

  @emperium_id 714
  @newbie_position 19
  @gd_approval 10_000
  @gd_extension 10_004
  @gd_battleorder 10_010
  @gd_leadership 10_006

  setup do
    on_exit(&ClusterTestHelper.clear_all/0)
    :ok
  end

  describe "taxation and leveling" do
    test "a taxed member kill levels the guild and notifies online members" do
      {master_session, guild_id} = create_guild("TaxLevelers", "TaxMaster")

      member = character_fixture("TaxedMember", %{base_level: 98})
      member_session = start_session(member)
      invite_and_accept(master_session, member_session, member, guild_id)

      simulate_incoming_message(master_session.pid, %GuildPositionEditRequest{
        index: @newbie_position,
        name: "Taxed Newbie",
        can_invite: false,
        can_expel: false,
        tax: 50
      })

      assert_receive {:packet_sent, %GuildActionResult{action: "position_edit", success: true},
                      _},
                     1_000

      assert eventually(fn -> get_player_state(member_session.pid).guild_tax == 50 end)
      flush_packets()

      # The real kill-exp ingress: 200_002 base -> 100_001 taxed to the guild
      # (crossing the level-2 threshold of 100_000), 100_001 kept by the member.
      send(member_session.pid, {:progression, {:mob_kill_exp, 200_002, 0, nil, nil}})

      assert eventually(fn ->
               case GuildManager.get(guild_id) do
                 {:ok, state} -> state.level == 2
                 _ -> false
               end
             end)

      {:ok, guild_state} = GuildManager.get(guild_id)
      assert guild_state.exp == 1
      assert guild_state.skill_points == 1

      row = Repo.get!(GuildModel, guild_id)
      assert row.level == 2
      assert row.exp == 1
      assert row.skill_points == 1

      # The member kept exactly the untaxed remainder (level 98 -> threshold far above).
      member_progression = get_player_state(member_session.pid).stats.progression
      assert member_progression.base_exp == 100_001

      # Both online sessions hear about it (their packets share this mailbox):
      # one GuildLevelUp each, plus the refreshed snapshot.
      assert_receive {:packet_sent, %GuildLevelUp{guild_id: ^guild_id, level: 2}, _}, 1_000
      assert_receive {:packet_sent, %GuildLevelUp{guild_id: ^guild_id, level: 2}, _}, 1_000
      assert_receive {:packet_sent, %GuildInfo{guild_id: ^guild_id, level: 2}, _}, 1_000
    end
  end

  describe "skill allocation through the wire" do
    test "allocating Guild Extension raises invite capacity for the 17th member" do
      {master_session, guild_id} = create_guild("Extenders", "ExtMaster")

      # Fill the base 16-member capacity (master + 15 offline members).
      for n <- 1..15 do
        filler = character_fixture("ExtFiller#{n}", %{})
        {:ok, _} = GuildManager.add_member(guild_id, filler)
      end

      seventeenth = character_fixture("ExtSeventeenth", %{})
      seventeenth_session = start_session(seventeenth)

      # At capacity the invite is refused outright.
      simulate_incoming_message(master_session.pid, %GuildInviteRequest{
        target_char_id: seventeenth.id,
        target_name: ""
      })

      assert_receive {:packet_sent,
                      %GuildActionResult{
                        action: "invite",
                        success: false,
                        error: :GUILD_ERR_GUILD_FULL
                      }, _},
                     1_000

      grant_skill_points(guild_id, 1)
      flush_packets()

      simulate_incoming_message(master_session.pid, %GuildSkillUpRequest{
        skill_id: @gd_extension
      })

      assert_receive {:packet_sent, %GuildActionResult{action: "skill_up", success: true}, _},
                     1_000

      {:ok, extended} = GuildManager.get(guild_id)
      assert extended.learned_skills == %{@gd_extension => 1}
      assert Aesir.ZoneServer.Guild.State.max_members(extended) == 22

      invite_and_accept(master_session, seventeenth_session, seventeenth, guild_id)

      {:ok, final} = GuildManager.get(guild_id)
      assert map_size(final.members) == 17
    end

    test "a non-master skill-up request is refused without spending the point" do
      {master_session, guild_id} = create_guild("NoPeons", "PeonMaster")
      member = character_fixture("PeonMember", %{})
      member_session = start_session(member)
      invite_and_accept(master_session, member_session, member, guild_id)

      grant_skill_points(guild_id, 1)

      simulate_incoming_message(member_session.pid, %GuildSkillUpRequest{
        skill_id: @gd_approval
      })

      assert_receive {:packet_sent,
                      %GuildActionResult{
                        action: "skill_up",
                        success: false,
                        error: :GUILD_ERR_NO_PERMISSION
                      }, _},
                     1_000

      {:ok, state} = GuildManager.get(guild_id)
      assert state.skill_points == 1
      assert state.learned_skills == %{}

      row = Repo.get!(GuildModel, guild_id)
      assert row.skill_points == 1
      assert row.learned_skills == %{}
    end
  end

  describe "guild-scoped cast cooldowns" do
    test "a Battle Orders cooldown survives the master's relog" do
      {master_session, guild_id} = create_guild("Orderers", "OrderMaster")
      seed_learned_skills(guild_id, %{"10010" => 1})

      simulate_incoming_message(master_session.pid, %SkillCast{
        skill_id: @gd_battleorder,
        level: 1,
        target_id: master_session.character.id
      })

      master_id = master_session.character.id

      assert eventually(fn ->
               StatusStorage.has_status?(:player, master_id, :sc_battleorder)
             end)

      {:ok, armed} = GuildManager.get(guild_id)
      assert is_integer(armed.skill_cooldowns[@gd_battleorder])

      # Relog: a fresh session must still be blocked by the guild cooldown.
      end_player_session(master_session)
      StatusStorage.remove_status(:player, master_id, :sc_battleorder)

      relog =
        start_player_session(
          character: Repo.get(Character, master_id),
          map_name: "prontera",
          position: {150, 150}
        )

      on_exit(fn -> end_player_session(relog) end)
      flush_packets()

      simulate_incoming_message(relog.pid, %SkillCast{
        skill_id: @gd_battleorder,
        level: 1,
        target_id: master_id
      })

      assert_receive {:packet_sent,
                      %SkillCastFailed{
                        skill_id: @gd_battleorder,
                        reason: :SKILL_CAST_FAILURE_REASON_ON_COOLDOWN
                      }, _},
                     1_000

      refute StatusStorage.has_status?(:player, master_id, :sc_battleorder)

      {:ok, still_armed} = GuildManager.get(guild_id)
      assert is_integer(still_armed.skill_cooldowns[@gd_battleorder])
    end

    test "a non-master member's guild cast is refused end-to-end" do
      {master_session, guild_id} = create_guild("NoCastPeons", "NoCastMaster")
      seed_learned_skills(guild_id, %{"10010" => 1})

      member = character_fixture("NoCastMember", %{})
      member_session = start_session(member)
      invite_and_accept(master_session, member_session, member, guild_id)

      simulate_incoming_message(member_session.pid, %SkillCast{
        skill_id: @gd_battleorder,
        level: 1,
        target_id: member.id
      })

      assert_receive {:packet_sent, %SkillCastFailed{skill_id: @gd_battleorder}, _}, 1_000
      refute StatusStorage.has_status?(:player, member.id, :sc_battleorder)
    end
  end

  describe "aura interplay after allocation" do
    test "wire-allocating an aura skill starts buffing a nearby guildmate" do
      {master_session, guild_id} = create_guild("AuraGuild", "AuraMaster")

      member = character_fixture("AuraMember", %{})
      member_session = start_session(member)
      invite_and_accept(master_session, member_session, member, guild_id)

      grant_skill_points(guild_id, 1)
      flush_packets()

      simulate_incoming_message(master_session.pid, %GuildSkillUpRequest{
        skill_id: @gd_leadership
      })

      assert_receive {:packet_sent, %GuildActionResult{action: "skill_up", success: true}, _},
                     1_000

      master_id = master_session.character.id

      # The guild_skill_update broadcast re-applies the aura source on the
      # master; the 1s tick then buffs the adjacent guildmate (both spawn at
      # {150, 150}), while the master stays excluded by default.
      assert eventually(fn ->
               StatusStorage.has_status?(:player, master_id, :sc_guild_aura_source)
             end)

      assert eventually(fn ->
               StatusStorage.has_status?(:player, member.id, :sc_gd_leadership)
             end)

      refute StatusStorage.has_status?(:player, master_id, :sc_gd_leadership)
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

    assert eventually(fn -> get_player_state(invitee_session.pid).guild_id == guild_id end)
    flush_packets()
    :ok
  end

  defp grant_skill_points(guild_id, points) do
    {1, nil} =
      from(g in GuildModel, where: g.id == ^guild_id)
      |> Repo.update_all(set: [skill_points: points])

    refresh_entry(guild_id)
  end

  defp seed_learned_skills(guild_id, learned_skills) do
    {1, nil} =
      from(g in GuildModel, where: g.id == ^guild_id)
      |> Repo.update_all(set: [learned_skills: learned_skills])

    refresh_entry(guild_id)
  end

  # Restart the Horde entry so it rehydrates the seeded columns; running
  # sessions keep their topic subscriptions and reattach on the next call.
  defp refresh_entry(guild_id) do
    ClusterTestHelper.clear_all()
    {:ok, _} = GuildManager.ensure_started(guild_id)
    :ok
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
end
