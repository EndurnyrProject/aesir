defmodule Aesir.ZoneServer.Integration.CastleGuardiansIntegrationTest do
  @moduledoc """
  End-to-end coverage of the WoE First Edition castle guardian loop against
  the real subsystems: the castle steward's Summon Guardian dialog,
  `Guardians` hire/spawn/despawn/conquest, owner-aware hostility on the
  siege ground, and the Strengthen Guardians scaling formulas.

  All scenarios use castle 0 (`aldeg_cas01`): its slot 0 (soldier) cell is a
  walkable, non-recessed tile, unlike some other slots on this and other FE
  castles.
  """

  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  import Ecto.Query
  import Aesir.ZoneServer.EtsTable, only: [table_for: 1]

  alias Aesir.Commons.ClusterTestHelper
  alias Aesir.Commons.GameMode
  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.Guild, as: GuildModel
  alias Aesir.Commons.Models.GuildCastle
  alias Aesir.Net.NpcDialog
  alias Aesir.Net.NpcInteract
  alias Aesir.Repo
  alias Aesir.ZoneServer.Content.Npc.Woe.Steward
  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Guild.Manager, as: GuildManager
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.MobManagement.Mobs
  alias Aesir.ZoneServer.Mmo.Woe.CastleDb
  alias Aesir.ZoneServer.Mmo.Woe.CastleStore
  alias Aesir.ZoneServer.Mmo.Woe.Guardians
  alias Aesir.ZoneServer.Mmo.Woe.Persistence
  alias Aesir.ZoneServer.Mmo.Woe.Server, as: WoeServer
  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Interaction
  alias Aesir.ZoneServer.Unit.Mob.AIStateMachine
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerSession

  @castle_id 0
  @slot0_mob_id 1287
  @approval_skill_id 10_000
  @research_skill_id 10_002
  @guardup_skill_id 10_003

  setup do
    on_exit(&ClusterTestHelper.clear_all/0)
    :ok = CastleDb.reload()
    :ok = CastleStore.init()
    {:ok, castle} = CastleDb.by_id(@castle_id)
    start_per_test_map(castle.map)
    %{castle: castle}
  end

  test "hiring a slot through the steward survives a restart and spawns under the owner", %{
    castle: castle
  } do
    {owner, guild_id} = guild_player(castle)
    :ok = grant_guild_skills(guild_id, %{"#{@research_skill_id}" => 1})
    :ok = Persistence.persist(@castle_id, guild_id)
    :ok = CastleStore.hydrate(Persistence.load_all())

    gid = steward_gid(castle.map)
    ipid = open_guardian_menu(owner, gid)
    text = hire_slot(ipid, gid, 1)
    assert text =~ "completed the summoning"

    assert CastleStore.guardians(@castle_id) == [0]
    assert Repo.get_by!(GuildCastle, castle_id: @castle_id).guardians == [0]

    :ets.delete_all_objects(EtsTable.table_for(:castle_states))
    :ok = CastleStore.init()
    :ok = CastleStore.hydrate(Persistence.load_all())

    start_supervised!({WoeServer, []})
    :ok = WoeServer.start()

    assert Guardians.live_slots(@castle_id) == [0]
    [{{@castle_id, 0}, unit_id}] = :ets.lookup(table_for(:castle_guardians), {@castle_id, 0})
    {:ok, {_module, mob, _pid}} = UnitRegistry.get_unit(:mob, unit_id)
    assert mob.mob_id == @slot0_mob_id
    assert {mob.x, mob.y} == Enum.at(castle.guardians, 0).cell
    assert mob.guild_id == guild_id
  end

  test "the owner guild is immune and an approved outsider can kill the guardian", %{
    castle: castle
  } do
    {x, y} = Enum.at(castle.guardians, 0).cell

    {owner, owner_guild} = guild_player(castle, {x + 1, y})
    :ok = grant_guild_skills(owner_guild, %{"#{@research_skill_id}" => 1})
    :ok = Persistence.persist(@castle_id, owner_guild)
    :ok = CastleStore.hydrate(Persistence.load_all())

    start_supervised!({WoeServer, []})
    :ok = WoeServer.start()
    :ok = Guardians.hire(@castle_id, 0, owner_guild)

    [{{@castle_id, 0}, unit_id}] = :ets.lookup(table_for(:castle_guardians), {@castle_id, 0})
    {:ok, {_module, mob, mob_pid}} = UnitRegistry.get_unit(:mob, unit_id)

    assert {:error, :owner_guild} = attack(owner, unit_id)
    assert get_mob_state(mob_pid).hp == mob.hp

    refute AIStateMachine.check_aggro(get_mob_state(mob_pid)).target_ref
    refute AIStateMachine.check_aggro(get_mob_state(mob_pid)).target_ref

    {outsider, outsider_guild} = guild_player(castle, {x - 1, y})
    :ok = grant_guild_skills(outsider_guild, %{"#{@approval_skill_id}" => 1})

    legal_break(outsider, unit_id, mob_pid)

    assert_eventually(fn -> Guardians.live_slots(@castle_id) == [] end)
    assert CastleStore.guardians(@castle_id) == []
  end

  test "a researched conqueror keeps the hired slots and respawns them under the new owner", %{
    castle: castle
  } do
    {_owner, owner_guild} = guild_player(castle)
    :ok = grant_guild_skills(owner_guild, %{"#{@research_skill_id}" => 1})
    :ok = Persistence.persist(@castle_id, owner_guild)
    :ok = CastleStore.hydrate(Persistence.load_all())

    start_supervised!({WoeServer, []})
    :ok = WoeServer.start()
    :ok = Guardians.hire(@castle_id, 0, owner_guild)
    :ok = Guardians.hire(@castle_id, 1, owner_guild)
    old_ids = live_unit_ids([0, 1])

    {conqueror, conqueror_guild} = guild_player(castle)

    :ok =
      grant_guild_skills(conqueror_guild, %{
        "#{@approval_skill_id}" => 1,
        "#{@research_skill_id}" => 1
      })

    break_emperium(conqueror)

    assert_eventually(fn -> CastleStore.owner(@castle_id) == conqueror_guild end)
    assert_eventually(fn -> Enum.sort(Guardians.live_slots(@castle_id)) == [0, 1] end)
    assert CastleStore.guardians(@castle_id) == [0, 1]

    new_ids = live_unit_ids([0, 1])
    assert new_ids != old_ids

    Enum.each(old_ids, fn id -> assert {:error, :not_found} = UnitRegistry.get_unit(:mob, id) end)

    Enum.each(new_ids, fn id ->
      {:ok, {_module, mob, _pid}} = UnitRegistry.get_unit(:mob, id)
      assert mob.guild_id == conqueror_guild
    end)
  end

  test "an unresearched conqueror clears the hired slots on capture", %{castle: castle} do
    {_owner, owner_guild} = guild_player(castle)
    :ok = grant_guild_skills(owner_guild, %{"#{@research_skill_id}" => 1})
    :ok = Persistence.persist(@castle_id, owner_guild)
    :ok = CastleStore.hydrate(Persistence.load_all())

    start_supervised!({WoeServer, []})
    :ok = WoeServer.start()
    :ok = Guardians.hire(@castle_id, 0, owner_guild)
    :ok = Guardians.hire(@castle_id, 1, owner_guild)

    {conqueror, conqueror_guild} = guild_player(castle)
    :ok = grant_guild_skills(conqueror_guild, %{"#{@approval_skill_id}" => 1})

    break_emperium(conqueror)

    assert_eventually(fn -> CastleStore.owner(@castle_id) == conqueror_guild end)
    assert_eventually(fn -> Guardians.live_slots(@castle_id) == [] end)
    assert CastleStore.guardians(@castle_id) == []
  end

  @tag game_mode: :renewal, integration_pre_re: false
  test "renewal Strengthen Guardians scales HP, DEF/MDEF and attack speed with defense", %{
    castle: castle
  } do
    assert_scaled_guardian(castle)
  end

  @tag game_mode: :pre_renewal, integration_re: false
  test "pre-renewal Strengthen Guardians scales HP, DEF/MDEF and attack speed with defense", %{
    castle: castle
  } do
    assert_scaled_guardian(castle)
  end

  defp assert_scaled_guardian(castle) do
    {_owner, owner_guild} = guild_player(castle)

    :ok =
      grant_guild_skills(owner_guild, %{
        "#{@research_skill_id}" => 1,
        "#{@guardup_skill_id}" => 3
      })

    :ok =
      CastleStore.hydrate(%{
        @castle_id => %{
          guild_id: owner_guild,
          economy: 0,
          defense: 100,
          invested_economy: 0,
          invested_defense: 0
        }
      })

    start_supervised!({WoeServer, []})
    :ok = WoeServer.start()
    :ok = Guardians.hire(@castle_id, 0, owner_guild)

    [{{@castle_id, 0}, unit_id}] = :ets.lookup(table_for(:castle_guardians), {@castle_id, 0})
    {:ok, {_module, mob, _pid}} = UnitRegistry.get_unit(:mob, unit_id)

    {:ok, mob_db} = Mobs.by_id(@slot0_mob_id)

    extra_hp =
      if GameMode.mode() == :renewal,
        do: 50 * div(100, 5) + 1_000 * 100,
        else: 2_000 * 100

    assert mob.max_hp == mob_db.hp + extra_hp

    baseline = MobState.to_combatant(%{mob | stat_bonus: %{}})
    scaled = MobState.to_combatant(mob)

    assert scaled.combat_stats.def == baseline.combat_stats.def + 34
    assert scaled.combat_stats.mdef == baseline.combat_stats.mdef + 34
    assert scaled.attack_delay_ms == div(baseline.attack_delay_ms * 91, 100)
  end

  defp live_unit_ids(slots) do
    Enum.map(slots, fn slot ->
      [{{@castle_id, ^slot}, unit_id}] =
        :ets.lookup(table_for(:castle_guardians), {@castle_id, slot})

      unit_id
    end)
  end

  defp break_emperium(killer) do
    unit_id = CastleStore.get(@castle_id).emperium_unit_id
    {:ok, {_module, _mob, pid}} = UnitRegistry.get_unit(:mob, unit_id)
    :ok = MobSession.apply_damage(pid, 999_999, killer.character.id)
  end

  defp legal_break(attacker, unit_id, mob_pid) do
    :rand.seed(:exsss, {17, 19, 23})

    assert Enum.reduce_while(1..5000, false, fn _, _ ->
             assert :ok = attack(attacker, unit_id)
             if get_mob_state(mob_pid).hp == 0, do: {:halt, true}, else: {:cont, false}
           end),
           "eligible combat did not break the guardian"
  end

  defp attack(player, unit_id) do
    state = get_player_state(player.pid)
    Combat.execute_attack(state.stats, state, unit_id)
  end

  defp steward_gid(map_name) do
    Steward.spawn()
    |> Enum.find(&(&1.map == map_name))
    |> NpcRegistry.entity_id()
  end

  defp open_guardian_menu(owner, gid) do
    session_state = PlayerSession.get_state(owner.pid)

    ctx = %Ctx{
      char_id: owner.character.id,
      account_id: owner.character.account_id,
      connection_pid: session_state.connection_pid,
      game_state: session_state.game_state,
      source: {:npc, Steward.npc_id()},
      npc_gid: gid
    }

    {:ok, ipid} = Interaction.start(owner.pid, Steward, ctx)

    assert_receive {:packet_sent, %NpcDialog{expect: :NEXT}, _}, 500
    send(ipid, {:npc_interact, %NpcInteract{npc_id: gid, response: {:continue, true}}})

    assert_receive {:packet_sent, %NpcDialog{expect: :MENU, options: [_, _, _, _]}, _}, 500
    send(ipid, {:npc_interact, %NpcInteract{npc_id: gid, response: {:choice, 4}}})

    ipid
  end

  defp hire_slot(ipid, gid, choice) do
    assert_receive {:packet_sent, %NpcDialog{expect: :NEXT}, _}, 500
    send(ipid, {:npc_interact, %NpcInteract{npc_id: gid, response: {:continue, true}}})

    assert_receive {:packet_sent, %NpcDialog{expect: :MENU, options: options}, _}, 500
    assert length(options) == 9
    send(ipid, {:npc_interact, %NpcInteract{npc_id: gid, response: {:choice, choice}}})

    assert_receive {:packet_sent, %NpcDialog{expect: :MENU, options: ["Summon", "Cancel"]}, _},
                   500

    send(ipid, {:npc_interact, %NpcInteract{npc_id: gid, response: {:choice, 1}}})

    assert_receive {:packet_sent, %NpcDialog{expect: :CLOSE, text: text}, _}, 500
    await_interaction_end(ipid)
    text
  end

  defp await_interaction_end(pid) do
    ref = Process.monitor(pid)
    assert_receive {:DOWN, ^ref, :process, ^pid, _reason}, 500
  end

  defp grant_guild_skills(guild_id, skills) do
    {1, nil} =
      from(g in GuildModel, where: g.id == ^guild_id)
      |> Repo.update_all(set: [learned_skills: skills])

    :ok = ClusterTestHelper.clear_all()
    {:ok, _guild} = GuildManager.ensure_started(guild_id)
    :ok
  end

  defp guild_player(castle), do: guild_player(castle, offset(castle.emperium))

  defp guild_player(castle, {x, y}) do
    character = character_fixture(castle.map, {x, y})
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
        userid: "cg_#{unique}",
        user_pass: "password",
        sex: "M",
        email: "cg_#{unique}@aesir.test"
      })
      |> Repo.insert()

    {:ok, character} =
      %Character{}
      |> Character.changeset(%{
        account_id: account.id,
        char_num: 0,
        name: "Siege#{unique}",
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
