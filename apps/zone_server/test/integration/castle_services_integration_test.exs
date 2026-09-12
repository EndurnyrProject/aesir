defmodule Aesir.ZoneServer.Integration.CastleServicesIntegrationTest do
  @moduledoc """
  End-to-end coverage of the WoE First Edition castle service loop against the
  real subsystems: hiring the castle Kafra through the steward, the Kafra's
  own member-only menu, conquest revoking the service and re-flagging the
  castle, the outside flag's return warp, the master's room and its treasure
  lever, and the guild dungeon lever.

  All scenarios use castle 0 (`aldeg_cas01`), whose outside flags stand on the
  shared `alde_gld` field map and whose guild dungeon is `gld_dun02`.
  """

  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  import Ecto.Query

  alias Aesir.Commons.ClusterTestHelper
  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.Guild, as: GuildModel
  alias Aesir.Commons.Models.GuildCastle
  alias Aesir.Net.MapMove
  alias Aesir.Net.NpcDialog
  alias Aesir.Net.NpcInteract
  alias Aesir.Net.StorageOpened
  alias Aesir.Repo
  alias Aesir.ZoneServer.Content.Npc.Woe.DungeonLever
  alias Aesir.ZoneServer.Content.Npc.Woe.InsideFlag
  alias Aesir.ZoneServer.Content.Npc.Woe.Kafra
  alias Aesir.ZoneServer.Content.Npc.Woe.OutsideFlag
  alias Aesir.ZoneServer.Content.Npc.Woe.Steward
  alias Aesir.ZoneServer.Content.Npc.Woe.TreasureLever
  alias Aesir.ZoneServer.Guild.Manager, as: GuildManager
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Woe.CastleDb
  alias Aesir.ZoneServer.Mmo.Woe.CastleStore
  alias Aesir.ZoneServer.Mmo.Woe.Persistence
  alias Aesir.ZoneServer.Mmo.Woe.Server, as: WoeServer
  alias Aesir.ZoneServer.Mmo.Woe.Services
  alias Aesir.ZoneServer.Npc.Packets, as: NpcPackets
  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry
  alias Aesir.ZoneServer.Npc.Session, as: NpcSession
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Interaction
  alias Aesir.ZoneServer.Unit.Player.PlayerSession

  @castle_id 0
  @approval_skill_id 10_000
  @contract_skill_id 10_001
  @field_map "alde_gld"
  @dungeon_map "gld_dun02"
  @outside_flag "Neuschwanstein#aldeg_cas01#out0"
  @outside_flag_cell {61, 87}
  @flag_entry {218, 170}
  @master_room {113, 223}
  @treasure_exit {218, 176}
  @dungeon_entry {32, 122}
  @dungeon_lever_cell {211, 181}
  @steward_menu [
    "Castle briefing",
    "Invest in commercial growth",
    "Invest in Castle Defenses",
    "Summon Guardian",
    "Hire / Fire a Kafra Employee",
    "Go into Master's room"
  ]

  setup do
    on_exit(&ClusterTestHelper.clear_all/0)
    on_exit(fn -> :persistent_term.erase(NpcRegistry) end)
    :ok = CastleDb.reload()
    :ok = CastleStore.init()
    {:ok, castle} = CastleDb.by_id(@castle_id)

    NpcRegistry.reload([Steward, Kafra, OutsideFlag, InsideFlag, TreasureLever, DungeonLever])

    kafra_gid = gid_for(Kafra, "Kafra Employee#" <> castle.map)
    on_exit(fn -> NpcSession.set_enabled(kafra_gid, true) end)

    start_per_test_map(castle.map)
    %{castle: castle, kafra_gid: kafra_gid}
  end

  test "the master hires the Kafra, a member gets storage and an outsider is refused", %{
    castle: castle,
    kafra_gid: kafra_gid
  } do
    {master, guild_id} = guild_player(castle.map, offset(castle.emperium))
    :ok = own_castle(guild_id)
    :ok = grant_guild_skills(guild_id, %{"#{@contract_skill_id}" => 1})

    gid = gid_for(Steward, "Steward#" <> castle.map)
    ipid = open_steward_menu(master, gid)
    send_choice(ipid, gid, 5)

    expect_next(ipid, gid)
    expect_choice(ipid, gid, ["Hire.", "Cancel"], 1)
    expect_next(ipid, gid)
    expect_next(ipid, gid)
    assert expect_close(ipid) =~ "Contract terms of the hired Kafra Employee"

    assert Services.kafra_hired?(@castle_id)
    assert Repo.get_by!(GuildCastle, castle_id: @castle_id).kafra
    assert NpcSession.enabled?(kafra_gid)

    open_kafra_storage(master, kafra_gid)

    {outsider, _outsider_guild} = guild_player(castle.map, offset(castle.emperium))
    refusal = talk_to_kafra(outsider, kafra_gid)
    assert refusal =~ "I am instructed to only offer my services"
  end

  test "conquest revokes the Kafra and re-flags the castle under the new owner", %{
    castle: castle,
    kafra_gid: kafra_gid
  } do
    {_master, guild_id} = guild_player(castle.map, offset(castle.emperium))
    :ok = own_castle(guild_id)
    :ok = grant_guild_skills(guild_id, %{"#{@contract_skill_id}" => 1})
    :ok = Services.hire_kafra(@castle_id, guild_id)
    assert Services.kafra_hired?(@castle_id)

    {conqueror, conqueror_guild} = guild_player(castle.map, offset(castle.emperium))
    :ok = grant_guild_skills(conqueror_guild, %{"#{@approval_skill_id}" => 1})

    start_supervised!({WoeServer, []})
    :ok = WoeServer.start()

    break_emperium(conqueror)

    assert_eventually(fn -> CastleStore.owner(@castle_id) == conqueror_guild end)
    assert_eventually(fn -> Services.kafra_hired?(@castle_id) == false end)
    refute Repo.get_by!(GuildCastle, castle_id: @castle_id).kafra
    refute NpcSession.enabled?(kafra_gid)

    [flag] = NpcRegistry.by_name(@outside_flag)
    assert NpcPackets.spawn_packet(flag).guild_id == conqueror_guild
  end

  test "an owner member returns to the castle from an outside flag", %{castle: castle} do
    start_per_test_map(@field_map)
    {member, guild_id} = guild_player(@field_map, @outside_flag_cell)
    :ok = own_castle(guild_id)

    gid = gid_for(OutsideFlag, @outside_flag)
    ipid = start_interaction(member, OutsideFlag, gid)

    expect_next(ipid, gid)
    expect_choice(ipid, gid, ["Return to the guild castle.", "Quit."], 1)
    expect_close(ipid)

    assert_warped(member, castle.map, @flag_entry)
  end

  test "the master reaches the treasure room and the lever sends him back", %{castle: castle} do
    {master, guild_id} = guild_player(castle.map, offset(castle.emperium))
    :ok = own_castle(guild_id)

    gid = gid_for(Steward, "Steward#" <> castle.map)
    ipid = open_steward_menu(master, gid)
    send_choice(ipid, gid, 6)

    expect_next(ipid, gid)
    expect_choice(ipid, gid, ["Go into Master's room.", "Cancel"], 1)
    expect_close(ipid)

    assert_warped(master, castle.map, @master_room)

    lever_gid = gid_for(TreasureLever, "Lever#" <> castle.map)
    lever_ipid = start_interaction(master, TreasureLever, lever_gid)

    expect_next(lever_ipid, lever_gid)
    expect_choice(lever_ipid, lever_gid, ["Pull.", "Do not."], 1)
    expect_close(lever_ipid)

    assert_warped(master, castle.map, @treasure_exit)
  end

  test "the dungeon lever only moves owner-guild members", %{castle: castle} do
    start_per_test_map(@dungeon_map)
    {member, guild_id} = guild_player(castle.map, @dungeon_lever_cell)
    :ok = own_castle(guild_id)

    gid = gid_for(DungeonLever, "Dungeon Lever#" <> castle.map)
    pull_dungeon_lever(member, gid)

    assert_warped(member, @dungeon_map, @dungeon_entry)

    {outsider, _outsider_guild} = guild_player(castle.map, @dungeon_lever_cell)
    flush_packets()
    assert pull_dungeon_lever(outsider, gid) =~ "Nothing happened."

    refute_receive {:packet_sent, %MapMove{}, _}, 200
    assert %{map_name: map} = get_player_state(outsider.pid)
    assert map == castle.map
  end

  defp pull_dungeon_lever(player, gid) do
    ipid = start_interaction(player, DungeonLever, gid)

    expect_next(ipid, gid)
    expect_next(ipid, gid)
    expect_choice(ipid, gid, ["Pull.", "Don't pull."], 1)
    expect_close(ipid)
  end

  defp open_kafra_storage(player, gid) do
    ipid = start_interaction(player, Kafra, gid)

    expect_next(ipid, gid)

    expect_choice(
      ipid,
      gid,
      ["Use Storage", "Use Teleport Service", "Rent a Pushcart", "Cancel"],
      1
    )

    assert_receive {:packet_sent, %StorageOpened{}, _}, 1_000
    expect_close(ipid)
  end

  defp talk_to_kafra(player, gid) do
    player
    |> start_interaction(Kafra, gid)
    |> expect_close()
  end

  defp break_emperium(killer) do
    unit_id = CastleStore.get(@castle_id).emperium_unit_id
    {:ok, {_module, _mob, pid}} = UnitRegistry.get_unit(:mob, unit_id)
    :ok = MobSession.apply_damage(pid, 999_999, killer.character.id)
  end

  defp assert_warped(player, map, {x, y}) do
    assert_receive {:packet_sent, %MapMove{map_name: ^map, x: ^x, y: ^y}, _}, 1_000

    assert_eventually(fn ->
      match?(%{map_name: ^map, x: ^x, y: ^y}, get_player_state(player.pid))
    end)
  end

  defp open_steward_menu(player, gid) do
    ipid = start_interaction(player, Steward, gid)

    expect_next(ipid, gid)
    assert_receive {:packet_sent, %NpcDialog{expect: :MENU, options: options}, _}, 500
    assert options == @steward_menu

    ipid
  end

  defp start_interaction(player, module, gid) do
    session_state = PlayerSession.get_state(player.pid)

    ctx = %Ctx{
      char_id: player.character.id,
      account_id: player.character.account_id,
      connection_pid: session_state.connection_pid,
      game_state: session_state.game_state,
      source: {:npc, module.npc_id()},
      npc_gid: gid
    }

    {:ok, ipid} = Interaction.start(player.pid, module, ctx)
    ipid
  end

  defp expect_next(ipid, gid) do
    assert_receive {:packet_sent, %NpcDialog{expect: :NEXT}, _}, 500
    send(ipid, {:npc_interact, %NpcInteract{npc_id: gid, response: {:continue, true}}})
  end

  defp expect_choice(ipid, gid, options, choice) do
    assert_receive {:packet_sent, %NpcDialog{expect: :MENU, options: ^options}, _}, 500
    send_choice(ipid, gid, choice)
  end

  defp send_choice(ipid, gid, choice) do
    send(ipid, {:npc_interact, %NpcInteract{npc_id: gid, response: {:choice, choice}}})
  end

  defp expect_close(ipid) do
    assert_receive {:packet_sent, %NpcDialog{expect: :CLOSE, text: text}, _}, 1_000
    ref = Process.monitor(ipid)
    assert_receive {:DOWN, ^ref, :process, ^ipid, _reason}, 1_000
    text
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
        userid: "cs_#{unique}",
        user_pass: "password",
        sex: "M",
        email: "cs_#{unique}@aesir.test"
      })
      |> Repo.insert()

    {:ok, character} =
      %Character{}
      |> Character.changeset(%{
        account_id: account.id,
        char_num: 0,
        name: "Servant#{unique}",
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
        save_y: 150,
        learned_skills: %{"#{nv_basic_id()}" => 6}
      })
      |> Repo.insert()

    character
  end

  defp nv_basic_id do
    {:ok, %{id: id}} = Catalog.by_name(:nv_basic)
    id
  end
end
