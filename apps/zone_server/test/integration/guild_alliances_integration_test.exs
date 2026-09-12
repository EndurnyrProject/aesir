defmodule Aesir.ZoneServer.Integration.GuildAlliancesIntegrationTest do
  @moduledoc """
  End-to-end guild alliance and antagonist coverage against real, concurrent
  `PlayerSession`s and the real WoE siege subsystem (design section 15,
  integration item): alliance formation broadcasting `GUILD_RELATION_ALLY` to
  both masters, siege-ground hostility flipping on formation and restoring on
  break, Emperium and guardian ownership protection extending to an ally, the
  ally-limit and siege-freeze refusals, unilateral antagonist declaration and
  removal, and relation cleanup on disband.

  Every flow is driven through the real `GuildAlliance*`/`GuildAntagonist*`
  protocol messages fed to the owning session with no relog, mirroring
  `guild_integration_test.exs`. Siege state goes through the real
  `Aesir.ZoneServer.Mmo.Woe.Server`, started per test as in
  `castle_guardians_integration_test.exs`.
  """

  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  import Ecto.Query
  import Aesir.ZoneServer.EtsTable, only: [table_for: 1]

  alias Aesir.Commons.ClusterTestHelper
  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.Guild, as: GuildModel
  alias Aesir.Commons.Models.GuildRelation
  alias Aesir.Net.GuildActionResult
  alias Aesir.Net.GuildAllianceBreakRequest
  alias Aesir.Net.GuildAllianceRequest
  alias Aesir.Net.GuildAllianceRequestNotify
  alias Aesir.Net.GuildAllianceResponse
  alias Aesir.Net.GuildAntagonistRemoveRequest
  alias Aesir.Net.GuildAntagonistRequest
  alias Aesir.Net.GuildInfo
  alias Aesir.Net.GuildInviteNotify
  alias Aesir.Net.GuildInviteRequest
  alias Aesir.Net.GuildInviteResponse
  alias Aesir.Net.GuildLeaveRequest
  alias Aesir.Repo
  alias Aesir.ZoneServer.Guild.Manager, as: GuildManager
  alias Aesir.ZoneServer.Guild.Relations
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Woe.CastleDb
  alias Aesir.ZoneServer.Mmo.Woe.CastleStore
  alias Aesir.ZoneServer.Mmo.Woe.Guardians
  alias Aesir.ZoneServer.Mmo.Woe.Persistence
  alias Aesir.ZoneServer.Mmo.Woe.Server, as: WoeServer
  alias Aesir.ZoneServer.Unit.Mob.AIStateMachine

  @castle_id 0
  @research_skill_id 10_002
  @approval_skill_id 10_000

  setup do
    on_exit(&ClusterTestHelper.clear_all/0)
    :ok = CastleDb.reload()
    :ok = CastleStore.init()
    {:ok, castle} = CastleDb.by_id(@castle_id)
    start_per_test_map(castle.map)

    {ex, ey} = castle.emperium

    {master_a, guild_a} = create_guild_master("MasterA", castle.map, {ex + 2, ey})
    member_a_char = character_fixture("MemberA", castle.map, {ex + 1, ey})
    member_a = start_player_session(character: member_a_char)
    :ok = invite_and_accept(master_a, member_a, member_a_char, guild_a)

    {master_b, guild_b} = create_guild_master("MasterB", castle.map, {ex + 2, ey + 1})
    member_b_char = character_fixture("MemberB", castle.map, {ex + 1, ey + 1})
    member_b = start_player_session(character: member_b_char)
    :ok = invite_and_accept(master_b, member_b, member_b_char, guild_b)

    %{
      castle: castle,
      master_a: master_a,
      member_a: member_a,
      guild_a: guild_a,
      master_b: master_b,
      member_b: member_b,
      guild_b: guild_b
    }
  end

  test "alliance formation notifies the target master and both see GUILD_RELATION_ALLY", %{
    master_a: master_a,
    guild_a: guild_a,
    master_b: master_b,
    guild_b: guild_b
  } do
    simulate_incoming_message(master_a.pid, %GuildAllianceRequest{
      target_char_id: master_b.character.id,
      target_name: ""
    })

    assert_receive {:packet_sent,
                    %GuildActionResult{
                      action: "alliance_request",
                      success: true,
                      error: :GUILD_ERR_NONE
                    }, _},
                   1_000

    assert_receive {:packet_sent,
                    %GuildAllianceRequestNotify{
                      guild_id: ^guild_a,
                      requester_name: "MasterA"
                    }, _},
                   1_000

    simulate_incoming_message(master_b.pid, %GuildAllianceResponse{
      guild_id: guild_a,
      accept: true
    })

    assert_receive {:packet_sent,
                    %GuildActionResult{
                      action: "alliance_response",
                      success: true,
                      error: :GUILD_ERR_NONE
                    }, _},
                   1_000

    infos = collect_packets_of_type(GuildInfo, 500)
    a_info = Enum.find(infos, &(&1.guild_id == guild_a))
    b_info = Enum.find(infos, &(&1.guild_id == guild_b))

    assert Enum.any?(
             a_info.relations,
             &(&1.guild_id == guild_b and &1.kind == :GUILD_RELATION_ALLY)
           )

    assert Enum.any?(
             b_info.relations,
             &(&1.guild_id == guild_a and &1.kind == :GUILD_RELATION_ALLY)
           )

    assert Repo.aggregate(
             from(r in GuildRelation, where: r.guild_id in ^[guild_a, guild_b]),
             :count
           ) == 2
  end

  test "siege-ground hostility flips on alliance and restores on break", %{
    master_a: master_a,
    guild_a: guild_a,
    member_a: member_a,
    master_b: master_b,
    guild_b: guild_b,
    member_b: member_b
  } do
    start_supervised!({WoeServer, []})
    :ok = WoeServer.start()

    assert :ok = attack(member_a, member_b.character.id)

    :ok = WoeServer.stop()
    :ok = form_alliance(master_a, guild_a, master_b, master_b.character.id)
    :ok = WoeServer.start()

    assert {:error, :invalid_target} = attack(member_a, member_b.character.id)

    :ok = WoeServer.stop()

    simulate_incoming_message(master_a.pid, %GuildAllianceBreakRequest{guild_id: guild_b})

    assert_receive {:packet_sent,
                    %GuildActionResult{
                      action: "alliance_break",
                      success: true,
                      error: :GUILD_ERR_NONE
                    }, _},
                   1_000

    flush_packets()
    :ok = WoeServer.start()

    assert :ok = attack(member_a, member_b.character.id)
  end

  test "an owned castle's Emperium and hired guardian protect an ally", %{
    castle: castle,
    master_a: master_a,
    guild_a: guild_a,
    master_b: master_b,
    guild_b: guild_b,
    member_b: member_b
  } do
    :ok = form_alliance(master_a, guild_a, master_b, master_b.character.id)

    :ok = grant_guild_skills(guild_a, %{"#{@research_skill_id}" => 1})
    :ok = grant_guild_skills(guild_b, %{"#{@approval_skill_id}" => 1})
    {:ok, _guild_a_state} = GuildManager.ensure_started(guild_a)

    :ok = Persistence.persist(@castle_id, guild_a)
    :ok = CastleStore.hydrate(Persistence.load_all())

    start_supervised!({WoeServer, []})
    :ok = WoeServer.start()
    :ok = Guardians.hire(@castle_id, 0, guild_a)

    emperium_unit_id = CastleStore.get(@castle_id).emperium_unit_id
    assert {:error, :owner_guild} = attack(member_b, emperium_unit_id)

    [{{@castle_id, 0}, guardian_unit_id}] =
      :ets.lookup(table_for(:castle_guardians), {@castle_id, 0})

    {gx, gy} = Enum.at(castle.guardians, 0).cell

    raider_char = character_fixture("RaiderB", castle.map, {gx + 1, gy})
    {:ok, _guild_b_state} = GuildManager.add_member(guild_b, raider_char)
    raider_char = Repo.get!(Character, raider_char.id)
    raider = start_player_session(character: raider_char)

    assert {:error, :owner_guild} = attack(raider, guardian_unit_id)

    {:ok, {_module, _mob, guardian_pid}} = UnitRegistry.get_unit(:mob, guardian_unit_id)

    refute AIStateMachine.check_aggro(get_mob_state(guardian_pid)).target_ref

    bystander_char = character_fixture("Bystander", castle.map, {gx - 1, gy})
    _bystander = start_player_session(character: bystander_char)

    scanned = AIStateMachine.check_aggro(get_mob_state(guardian_pid))
    assert scanned.target_ref == {:player, bystander_char.id}
  end

  test "an active siege refuses alliance writes and a third ally trips the limit", %{
    master_a: master_a,
    guild_a: guild_a,
    master_b: master_b,
    guild_b: guild_b
  } do
    start_supervised!({WoeServer, []})
    :ok = WoeServer.start()

    simulate_incoming_message(master_a.pid, %GuildAllianceRequest{
      target_char_id: master_b.character.id,
      target_name: ""
    })

    assert_receive {:packet_sent,
                    %GuildActionResult{
                      action: "alliance_request",
                      success: false,
                      error: :GUILD_ERR_SIEGE_ACTIVE
                    }, _},
                   1_000

    :ok = WoeServer.stop()
    :ok = form_alliance(master_a, guild_a, master_b, master_b.character.id)
    :ok = WoeServer.start()

    simulate_incoming_message(master_a.pid, %GuildAllianceBreakRequest{guild_id: guild_b})

    assert_receive {:packet_sent,
                    %GuildActionResult{
                      action: "alliance_break",
                      success: false,
                      error: :GUILD_ERR_SIEGE_ACTIVE
                    }, _},
                   1_000

    :ok = WoeServer.stop()

    ally_c_char = character_fixture("AllyC", "prontera", {150, 150})
    {:ok, ally_c} = GuildManager.create("AllyC", ally_c_char)

    ally_d_char = character_fixture("AllyD", "prontera", {150, 150})
    {:ok, ally_d} = GuildManager.create("AllyD", ally_d_char)

    :ok = Relations.ally(guild_a, ally_c.guild_id)
    :ok = Relations.ally(guild_a, ally_d.guild_id)

    ally_e_char = character_fixture("AllyE", "prontera", {150, 150})
    {:ok, _ally_e} = GuildManager.create("AllyE", ally_e_char)

    flush_packets()

    simulate_incoming_message(master_a.pid, %GuildAllianceRequest{
      target_char_id: ally_e_char.id,
      target_name: ""
    })

    assert_receive {:packet_sent,
                    %GuildActionResult{
                      action: "alliance_request",
                      success: false,
                      error: :GUILD_ERR_ALLY_LIMIT
                    }, _},
                   1_000
  end

  test "an antagonist declaration is unilateral, does not shield combat, and clears on removal",
       %{
         master_a: master_a,
         guild_a: guild_a,
         member_a: member_a,
         guild_b: guild_b,
         member_b: member_b
       } do
    simulate_incoming_message(master_a.pid, %GuildAntagonistRequest{
      target_char_id: member_b.character.id,
      target_name: ""
    })

    assert_receive {:packet_sent,
                    %GuildActionResult{
                      action: "antagonist",
                      success: true,
                      error: :GUILD_ERR_NONE
                    }, _},
                   1_000

    declared = collect_packets_of_type(GuildInfo, 500)
    a_info = Enum.find(declared, &(&1.guild_id == guild_a))
    b_info = Enum.find(declared, &(&1.guild_id == guild_b))

    assert Enum.any?(
             a_info.relations,
             &(&1.guild_id == guild_b and &1.kind == :GUILD_RELATION_ANTAGONIST)
           )

    assert b_info.relations == []

    start_supervised!({WoeServer, []})
    :ok = WoeServer.start()

    assert :ok = attack(member_a, member_b.character.id)

    :ok = WoeServer.stop()

    simulate_incoming_message(master_a.pid, %GuildAntagonistRemoveRequest{guild_id: guild_b})

    assert_receive {:packet_sent,
                    %GuildActionResult{
                      action: "antagonist_remove",
                      success: true,
                      error: :GUILD_ERR_NONE
                    }, _},
                   1_000

    cleared = collect_packets_of_type(GuildInfo, 500)
    cleared_a_info = Enum.find(cleared, &(&1.guild_id == guild_a))
    assert cleared_a_info.relations == []
  end

  test "disbanding an allied guild cascades its relations and pushes an empty list to the ally",
       %{
         master_a: master_a,
         guild_a: guild_a,
         master_b: master_b,
         guild_b: guild_b
       } do
    :ok = form_alliance(master_a, guild_a, master_b, master_b.character.id)

    simulate_incoming_message(master_a.pid, %GuildLeaveRequest{})

    assert_receive {:packet_sent,
                    %GuildActionResult{action: "leave", success: true, error: :GUILD_ERR_NONE},
                    _},
                   1_000

    assert Repo.get(GuildModel, guild_a) == nil

    assert Repo.all(
             from(r in GuildRelation,
               where: r.guild_id == ^guild_a or r.other_guild_id == ^guild_a
             )
           ) == []

    infos = collect_packets_of_type(GuildInfo, 500)
    b_info = Enum.find(infos, &(&1.guild_id == guild_b))
    assert b_info.relations == []
  end

  defp attack(player, target_id) do
    state = get_player_state(player.pid)
    Combat.execute_attack(state.stats, state, target_id)
  end

  defp form_alliance(requester, requester_guild_id, target, target_char_id) do
    simulate_incoming_message(requester.pid, %GuildAllianceRequest{
      target_char_id: target_char_id,
      target_name: ""
    })

    assert_receive {:packet_sent, %GuildActionResult{action: "alliance_request", success: true},
                    _},
                   1_000

    assert_receive {:packet_sent, %GuildAllianceRequestNotify{guild_id: ^requester_guild_id}, _},
                   1_000

    simulate_incoming_message(target.pid, %GuildAllianceResponse{
      guild_id: requester_guild_id,
      accept: true
    })

    assert_receive {:packet_sent, %GuildActionResult{action: "alliance_response", success: true},
                    _},
                   1_000

    flush_packets()
    :ok
  end

  defp grant_guild_skills(guild_id, skills) do
    {1, nil} =
      from(g in GuildModel, where: g.id == ^guild_id)
      |> Repo.update_all(set: [learned_skills: skills])

    :ok = ClusterTestHelper.clear_all()
    {:ok, _guild} = GuildManager.ensure_started(guild_id)
    :ok
  end

  defp create_guild_master(name, map, {x, y}) do
    character = character_fixture(name, map, {x, y})
    {:ok, guild} = GuildManager.create(name, character)
    character = Repo.get!(Character, character.id)
    session = start_player_session(character: character)
    {session, guild.guild_id}
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

  defp account_fixture(userid) do
    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        userid: userid,
        user_pass: "password",
        sex: "M",
        email: "#{userid}@aesir.test"
      })
      |> Repo.insert()

    account
  end

  defp character_fixture(name, map, {x, y}) do
    account = account_fixture(name)

    {:ok, character} =
      %{
        account_id: account.id,
        char_num: 0,
        name: name,
        class: 0,
        base_level: 99,
        job_level: 50,
        str: 99,
        agi: 99,
        vit: 1,
        int: 1,
        dex: 99,
        luk: 0,
        hp: 10_000,
        max_hp: 10_000,
        sp: 1_000,
        max_sp: 1_000,
        zeny: 20_000,
        last_map: map,
        last_x: x,
        last_y: y,
        save_map: "prontera",
        save_x: 150,
        save_y: 150
      }
      |> Character.new()
      |> Repo.insert()

    character
  end
end
