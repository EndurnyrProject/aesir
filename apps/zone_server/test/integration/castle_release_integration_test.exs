defmodule Aesir.ZoneServer.Integration.CastleReleaseIntegrationTest do
  @moduledoc """
  End-to-end coverage of the WoE castle release loop against the real
  subsystems: a guild owning a castle with a hired guardian and Kafra is
  disbanded by its master leaving, the castle store, guardians, services,
  persistence, announcement and PvE population all release together, and
  agit start/end interact correctly with an already-released or still-owned
  castle.

  All scenarios use castle 0 (`aldeg_cas01`).
  """

  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  import Ecto.Query

  alias Aesir.Commons.ClusterTestHelper
  alias Aesir.Commons.InterServer.PubSub, as: ServerPubSub
  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.Guild, as: GuildModel
  alias Aesir.Commons.Models.GuildCastle
  alias Aesir.Net.Announcement, as: AnnouncementMsg
  alias Aesir.Net.GuildActionResult
  alias Aesir.Net.GuildLeaveRequest
  alias Aesir.Repo
  alias Aesir.ZoneServer.Content.Npc.Woe.InsideFlag
  alias Aesir.ZoneServer.Content.Npc.Woe.Kafra
  alias Aesir.ZoneServer.Content.Npc.Woe.OutsideFlag
  alias Aesir.ZoneServer.Content.Npc.Woe.Steward
  alias Aesir.ZoneServer.Guild.Lifecycle, as: GuildLifecycle
  alias Aesir.ZoneServer.Guild.Manager, as: GuildManager
  alias Aesir.ZoneServer.Mmo.Woe.CastleDb
  alias Aesir.ZoneServer.Mmo.Woe.CastleMobs
  alias Aesir.ZoneServer.Mmo.Woe.CastleStore
  alias Aesir.ZoneServer.Mmo.Woe.Guardians
  alias Aesir.ZoneServer.Mmo.Woe.Persistence
  alias Aesir.ZoneServer.Mmo.Woe.Server, as: WoeServer
  alias Aesir.ZoneServer.Mmo.Woe.Services
  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry
  alias Aesir.ZoneServer.Npc.Session, as: NpcSession
  alias Aesir.ZoneServer.Unit.Mob.MobSupervisor

  @castle_id 0
  @research_skill_id 10_002
  @contract_skill_id 10_001
  @outside_flag "Neuschwanstein#aldeg_cas01#out0"

  setup do
    on_exit(&ClusterTestHelper.clear_all/0)
    on_exit(fn -> :persistent_term.erase(NpcRegistry) end)
    :ok = CastleDb.reload()
    :ok = CastleStore.init()
    {:ok, castle} = CastleDb.by_id(@castle_id)

    NpcRegistry.reload([Steward, Kafra, OutsideFlag, InsideFlag])

    kafra_gid = gid_for(Kafra, "Kafra Employee#" <> castle.map)
    on_exit(fn -> NpcSession.set_enabled(kafra_gid, true) end)

    start_per_test_map(castle.map)
    {:ok, expected_pack} = CastleMobs.set_for(castle.map)

    expected_count =
      expected_pack |> Map.values() |> List.flatten() |> Enum.map(&elem(&1, 1)) |> Enum.sum()

    %{castle: castle, kafra_gid: kafra_gid, expected_count: expected_count}
  end

  test "a master leaving disbands the guild and releases the owned castle", %{
    castle: castle,
    kafra_gid: kafra_gid,
    expected_count: expected_count
  } do
    {master, guild_id} = guild_player(castle.map, offset(castle.emperium))
    :ok = own_castle(guild_id)

    :ok =
      grant_guild_skills(guild_id, %{
        "#{@research_skill_id}" => 1,
        "#{@contract_skill_id}" => 1
      })

    :ok = Guardians.hire(@castle_id, 0, guild_id)
    :ok = Services.hire_kafra(@castle_id, guild_id)

    start_supervised!({WoeServer, []})
    :ok = ServerPubSub.subscribe_to_announcements()

    disband_by_leaving(master, guild_id)

    assert_eventually(fn -> CastleStore.owner(@castle_id) == nil end)
    assert_eventually(fn -> CastleStore.guardians(@castle_id) == [] end)
    assert_eventually(fn -> Services.kafra_hired?(@castle_id) == false end)
    assert_eventually(fn -> NpcSession.enabled?(kafra_gid) == false end)

    assert_eventually(fn ->
      row = Repo.get_by!(GuildCastle, castle_id: @castle_id)
      row.guild_id == nil and row.guardians == [] and row.kafra == false
    end)

    [{_module, flag_placement}] = NpcRegistry.by_name(@outside_flag)
    assert OutsideFlag.guild_id(flag_placement) == 0

    assert_receive {:announcement, %AnnouncementMsg{text: text}}, 1_000
    assert text =~ "has been abandoned"

    assert_eventually(fn ->
      MobSupervisor.count_by_event(castle.map, :all) == expected_count
    end)
  end

  test "agit start leaves only the Emperium on a map released back to no owner", %{
    castle: castle,
    expected_count: expected_count
  } do
    {master, guild_id} = guild_player(castle.map, offset(castle.emperium))
    :ok = own_castle(guild_id)

    start_supervised!({WoeServer, []})
    disband_by_leaving(master, guild_id)

    assert_eventually(fn ->
      MobSupervisor.count_by_event(castle.map, :all) == expected_count
    end)

    :ok = WoeServer.start()

    assert_eventually(fn -> is_integer(CastleStore.get(@castle_id).emperium_unit_id) end)
    assert_eventually(fn -> MobSupervisor.count_by_event(castle.map, :all) == 1 end)
  end

  test "a disband during an active agit keeps the Emperium and seeds nothing", %{
    castle: castle
  } do
    {master, guild_id} = guild_player(castle.map, offset(castle.emperium))
    :ok = own_castle(guild_id)

    start_supervised!({WoeServer, []})
    :ok = WoeServer.start()

    assert_eventually(fn -> is_integer(CastleStore.get(@castle_id).emperium_unit_id) end)
    emperium_unit_id = CastleStore.get(@castle_id).emperium_unit_id

    disband_by_leaving(master, guild_id)

    assert_eventually(fn -> CastleStore.owner(@castle_id) == nil end)
    assert CastleStore.get(@castle_id).emperium_unit_id == emperium_unit_id
    assert_eventually(fn -> MobSupervisor.count_by_event(castle.map, :all) == 1 end)
  end

  defp disband_by_leaving(master, guild_id) do
    :ok = GuildLifecycle.subscribe()
    simulate_incoming_message(master.pid, %GuildLeaveRequest{})

    assert_receive {:packet_sent,
                    %GuildActionResult{action: "leave", success: true, error: :GUILD_ERR_NONE},
                    _},
                   1_000

    assert_receive {:guild_lifecycle, {:disbanded, ^guild_id}}, 1_000
  end

  defp gid_for(module, unique_name) do
    [{^module, placement}] = NpcRegistry.by_name(unique_name)
    NpcRegistry.entity_id(placement)
  end

  defp own_castle(guild_id) do
    :ok = Persistence.persist(@castle_id, guild_id)
    CastleStore.hydrate(Persistence.load_all())
  end

  defp grant_guild_skills(guild_id, skills) do
    {1, nil} =
      from(g in GuildModel, where: g.id == ^guild_id)
      |> Repo.update_all(set: [learned_skills: skills])

    :ok = ClusterTestHelper.clear_all()
    {:ok, _guild} = GuildManager.ensure_started(guild_id)
    :ok
  end

  defp guild_player(map, {x, y}) do
    character = character_fixture(map, {x, y})
    {:ok, guild} = GuildManager.create("Siege#{character.id}", character)
    character = Repo.get!(Character, character.id)
    player = start_player_session(character: character)
    {player, guild.guild_id}
  end

  defp offset({x, y}), do: {x + 1, y}

  defp character_fixture(map, {x, y}) do
    unique = System.unique_integer([:positive])

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        userid: "cr_#{unique}",
        user_pass: "password",
        sex: "M",
        email: "cr_#{unique}@aesir.test"
      })
      |> Repo.insert()

    {:ok, character} =
      %Character{}
      |> Character.changeset(%{
        account_id: account.id,
        char_num: 0,
        name: "Release#{unique}",
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
        sp: 1000,
        max_sp: 1000,
        zeny: 20_000,
        last_map: map,
        last_x: x,
        last_y: y,
        save_map: "prontera",
        save_x: 150,
        save_y: 150
      })
      |> Repo.insert()

    character
  end
end
