defmodule Aesir.ZoneServer.Integration.WoeCorrectnessIntegrationTest do
  @moduledoc """
  Legal combat and attributed conquest through isolated siege worlds.
  Run in separate boot-selected Renewal and pre-renewal VMs.

  The maximized unarmed classic contact has 241 status ATK + 238 variance ATK;
  40 hard DEF and 80 soft DEF leave 207, then castle ground retains 165.
  """

  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  import Ecto.Query

  alias Aesir.Commons.ClusterTestHelper
  alias Aesir.Commons.GameMode
  alias Aesir.Commons.InterServer.PubSub, as: ServerPubSub
  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.Guild, as: GuildModel
  alias Aesir.Net.ActionRequest
  alias Aesir.Net.Announcement
  alias Aesir.Net.DamageDealt
  alias Aesir.Net.MapMove
  alias Aesir.Net.SkillDamage
  alias Aesir.Repo
  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Guild.Manager, as: GuildManager
  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.SkillAttack
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Mmo.Woe.CastleDb
  alias Aesir.ZoneServer.Mmo.Woe.CastleStore
  alias Aesir.ZoneServer.Mmo.Woe.Persistence
  alias Aesir.ZoneServer.Mmo.Woe.Server, as: WoeServer
  alias Aesir.ZoneServer.Unit.Lifecycle
  alias Aesir.ZoneServer.Unit.Lifecycle.Event

  @castle_id 0
  @approval_skill_id 10_000

  setup do
    on_exit(&ClusterTestHelper.clear_all/0)
    :ok = CastleDb.reload()
    :ok = MapFlags.reload()
    :ok = CastleStore.init()
    {:ok, castle} = CastleDb.by_id(@castle_id)
    start_per_test_map(castle.map)
    server = start_supervised!({WoeServer, []})
    previous = Application.get_env(:zone_server, :woe_emperium_respawn_ms)
    Application.put_env(:zone_server, :woe_emperium_respawn_ms, 100)

    on_exit(fn ->
      if is_nil(previous),
        do: Application.delete_env(:zone_server, :woe_emperium_respawn_ms),
        else: Application.put_env(:zone_server, :woe_emperium_respawn_ms, previous)
    end)

    %{castle: castle, server: server}
  end

  test "Approval gates real attacks and eligible hits use the imported mode profile", %{
    castle: castle
  } do
    {attacker, guild_id} = guild_player(castle)
    :ok = WoeServer.start()
    unit_id = CastleStore.get(@castle_id).emperium_unit_id
    {:ok, {_module, mob, mob_pid}} = UnitRegistry.get_unit(:mob, unit_id)
    assert mob.max_hp == if(GameMode.mode() == :renewal, do: 100, else: 68_430)
    assert mob.hp == mob.max_hp

    :ok =
      StatusInterpreter.apply_status(:mob, unit_id, :sc_aeterna, loaded: true, duration: 60_000)

    assert {:error, :approval_required} = attack(attacker, unit_id)
    assert get_mob_state(mob_pid).hp == mob.hp
    assert StatusStorage.has_status?(:mob, unit_id, :sc_aeterna)
    refute_packet_sent(DamageDealt)
    :ok = StatusInterpreter.remove_status(:mob, unit_id, :sc_aeterna)

    grant_approval(guild_id)
    :ok = StatusInterpreter.apply_status(:player, attacker.character.id, :sc_maximizepower)
    :ok = PlayerSession.recalculate_stats(attacker.pid, false)
    assert get_player_state(attacker.pid).stats.combat_stats.max_weapon_damage

    :sys.replace_state(attacker.pid, fn state ->
      :rand.seed(:exsss, {17, 19, 23})
      state
    end)

    simulate_incoming_message(attacker.pid, %ActionRequest{target_id: unit_id, action: 0})
    assert_receive {:packet_sent, %DamageDealt{} = packet, _}, 1000
    loss = mob.hp - get_mob_state(mob_pid).hp
    assert packet.target_id == unit_id
    assert packet.damage + packet.damage2 == loss

    if GameMode.mode() == :renewal do
      assert loss == 1
    else
      assert get_player_state(attacker.pid).stats.combat_stats.atk == 199
      assert loss == 165
    end
  end

  test "a legal break captures, persists, replaces and ejects outsiders including pending map loads",
       %{castle: castle} do
    {attacker, guild_id} = guild_player(castle)
    grant_approval(guild_id)
    owner_character = character_fixture(castle.map, castle.respawn)
    {:ok, _guild} = GuildManager.add_member(guild_id, owner_character)
    owner = start_player_session(character: Repo.get!(Character, owner_character.id))
    outsider = start_player_session(character: character_fixture(castle.map, castle.respawn))
    loading = start_player_session(character: character_fixture("prontera", {150, 150}))
    {x, y} = castle.respawn
    :ok = PlayerSession.warp(loading.pid, castle.map, x, y)
    assert_eventually(fn -> get_player_state(loading.pid).pending_map_load == :warp end)
    assert {:error, :not_found} = SpatialIndex.get_unit_position(:player, loading.character.id)
    :ok = ServerPubSub.subscribe_to_announcements()
    :ok = WoeServer.start()
    assert_receive {:announcement, %Announcement{text: "WoE has begun"}}, 1000
    old_id = CastleStore.get(@castle_id).emperium_unit_id

    legal_break(attacker, old_id)

    assert_eventually(fn -> CastleStore.owner(@castle_id) == guild_id end)
    assert CastleStore.get(@castle_id).epoch == 1
    assert_receive {:announcement, %Announcement{text: conquest}}, 1000
    assert conquest == "#{castle.name} conquered by Siege#{attacker.character.id}"
    assert Persistence.load_all()[@castle_id] == guild_id
    assert_eventually(fn -> get_player_state(outsider.pid).map_name == "prontera" end)
    assert_eventually(fn -> get_player_state(loading.pid).map_name == "prontera" end)
    assert {get_player_state(loading.pid).x, get_player_state(loading.pid).y} == {150, 150}
    assert get_player_state(owner.pid).map_name == castle.map
    assert get_player_state(attacker.pid).map_name == castle.map
    replacement = await_replacement(old_id)

    stale_outsider =
      start_player_session(character: character_fixture(castle.map, castle.respawn))

    flush_packets()
    :ok = PlayerSession.eject_from_castle(outsider.pid, @castle_id, castle.map, 1)
    :ok = PlayerSession.eject_from_castle(owner.pid, @castle_id, castle.map, 0)
    :ok = PlayerSession.eject_from_castle(stale_outsider.pid, @castle_id, castle.map, 0)
    assert get_player_state(outsider.pid).map_name == "prontera"
    assert get_player_state(owner.pid).map_name == castle.map
    assert get_player_state(stale_outsider.pid).map_name == castle.map
    refute_packet_sent(MapMove)

    :ok =
      StatusInterpreter.apply_status(:mob, replacement, :sc_aeterna,
        loaded: true,
        duration: 60_000
      )

    assert {:error, :owner_guild} = attack(attacker, replacement)
    assert StatusStorage.has_status?(:mob, replacement, :sc_aeterna)
    {:ok, {_module, replacement_state, _pid}} = UnitRegistry.get_unit(:mob, replacement)
    assert replacement_state.hp == replacement_state.max_hp

    :ok = WoeServer.stop()
    :ets.delete_all_objects(EtsTable.table_for(:castle_states))
    :ok = CastleStore.init()
    assert CastleStore.owner(@castle_id) == nil
    :ok = CastleStore.hydrate(Persistence.load_all())
    assert CastleStore.owner(@castle_id) == guild_id
  end

  test "sampled lethal credit survives logout before processing and duplicates cannot claim a new siege",
       %{castle: castle, server: server} do
    {attacker, guild_id} = guild_player(castle)
    grant_approval(guild_id)
    :ok = Lifecycle.subscribe()
    :ok = WoeServer.start()
    old_id = CastleStore.get(@castle_id).emperium_unit_id
    :ok = :sys.suspend(server)

    event =
      try do
        legal_break(attacker, old_id)
        assert_receive {:unit_lifecycle, %Event{unit_id: ^old_id, reason: :death} = event}, 1000

        assert event.kill_credit == %{
                 attacker: {:player, attacker.character.id},
                 character_id: attacker.character.id,
                 guild_id: guild_id
               }

        assert CastleStore.owner(@castle_id) == nil
        :ok = end_player_session(attacker)
        assert {:error, :not_found} = UnitRegistry.get_unit(:player, attacker.character.id)
        event
      after
        :ok = :sys.resume(server)
      end

    assert_eventually(fn -> CastleStore.owner(@castle_id) == guild_id end)
    replacement = await_replacement(old_id)
    claimed = CastleStore.get(@castle_id)
    :ok = Lifecycle.publish(event)
    assert WoeServer.active?()
    assert CastleStore.get(@castle_id) == claimed
    assert claimed.emperium_unit_id == replacement
    :ok = WoeServer.stop()
    stopped = CastleStore.get(@castle_id)
    :ok = Lifecycle.publish(event)
    refute WoeServer.active?()
    assert CastleStore.get(@castle_id) == stopped
    :ok = WoeServer.start()
    restarted = CastleStore.get(@castle_id)
    assert restarted.emperium_unit_id != replacement
    :ok = Lifecycle.publish(event)
    assert WoeServer.active?()
    assert CastleStore.get(@castle_id) == restarted
  end

  test "Triple Attack keeps its mode exception and staged objective hits recheck current siege",
       %{castle: castle} do
    {attacker, guild_id} = guild_player(castle)
    grant_approval(guild_id)
    :ok = WoeServer.start()
    id = CastleStore.get(@castle_id).emperium_unit_id
    {:ok, {_module, original, pid}} = UnitRegistry.get_unit(:mob, id)
    state = get_player_state(attacker.pid)

    opts = [
      skill_id: 263,
      skill_level: 1,
      skill_ratio: 120,
      ignore_flee: true,
      skip_crit: true,
      display_hit_count: 3
    ]

    :rand.seed(:exsss, {17, 19, 23})
    flush_packets()

    if GameMode.mode() == :renewal do
      assert {:error, :skill_not_allowed} =
               SkillAttack.execute_skill_attack(state, {:mob, id}, opts)

      assert {:error, :skill_not_allowed} =
               SkillAttack.prepare_staged_skill_attack(state, {:mob, id}, opts)

      assert get_mob_state(pid).hp == original.hp
      refute_packet_sent(SkillDamage)
      refute_packet_sent(DamageDealt)
    else
      assert :ok = SkillAttack.execute_skill_attack(state, {:mob, id}, opts)
      packet = assert_packet_sent(SkillDamage)
      assert packet.skill_id == 263
      assert packet.damage > 1
      assert original.hp - get_mob_state(pid).hp == packet.damage
      assert {:ok, staged} = SkillAttack.prepare_staged_skill_attack(state, {:mob, id}, opts)
      :ok = WoeServer.stop()
      assert {:error, :not_found} = UnitRegistry.get_unit(:mob, id)
      :ok = WoeServer.start()
      replacement = CastleStore.get(@castle_id).emperium_unit_id
      assert replacement != id
      {:ok, {_module, fresh, fresh_pid}} = UnitRegistry.get_unit(:mob, replacement)

      :ok =
        StatusInterpreter.apply_status(:mob, replacement, :sc_aeterna,
          loaded: true,
          duration: 60_000
        )

      flush_packets()
      assert :ok = SkillAttack.deliver_prepared_skill_hit(staged)
      refute_packet_sent(SkillDamage)
      assert get_mob_state(fresh_pid).hp == fresh.max_hp
      assert StatusStorage.has_status?(:mob, replacement, :sc_aeterna)
    end
  end

  test "an unattributed objective death retains ownership, replaces once and does not eject", %{
    castle: castle
  } do
    {_owner, guild_id} = guild_player(castle)
    grant_approval(guild_id)
    :ok = Persistence.persist(@castle_id, guild_id)
    :ok = CastleStore.hydrate(Persistence.load_all())
    outsider = start_player_session(character: character_fixture(castle.map, castle.respawn))
    :ok = Lifecycle.subscribe()
    :ok = ServerPubSub.subscribe_to_announcements()
    :ok = WoeServer.start()
    assert_receive {:announcement, %Announcement{text: "WoE has begun"}}, 1000
    old_id = CastleStore.get(@castle_id).emperium_unit_id
    {:ok, {_module, mob, pid}} = UnitRegistry.get_unit(:mob, old_id)

    :ok = MobSession.apply_damage(pid, mob.hp, nil)

    assert_receive {:unit_lifecycle,
                    %Event{
                      unit_id: ^old_id,
                      reason: :death,
                      kill_credit: %{attacker: nil, character_id: nil, guild_id: nil}
                    } = event},
                   1000

    replacement = await_replacement(old_id)
    assert CastleStore.owner(@castle_id) == guild_id
    assert CastleStore.get(@castle_id).epoch == 1
    assert Persistence.load_all()[@castle_id] == guild_id
    assert get_player_state(outsider.pid).map_name == castle.map
    refute_receive {:announcement, %Announcement{}}, 100
    :ok = Lifecycle.publish(event)
    assert WoeServer.active?()
    assert CastleStore.get(@castle_id).emperium_unit_id == replacement
    assert CastleStore.get(@castle_id).epoch == 1
  end

  defp legal_break(attacker, unit_id) do
    {:ok, {_module, _mob, pid}} = UnitRegistry.get_unit(:mob, unit_id)
    :rand.seed(:exsss, {17, 19, 23})

    assert Enum.reduce_while(1..5000, false, fn _, _ ->
             assert :ok = attack(attacker, unit_id)
             if get_mob_state(pid).hp == 0, do: {:halt, true}, else: {:cont, false}
           end),
           "eligible combat did not break the objective"
  end

  defp await_replacement(old_id) do
    assert_eventually(fn ->
      id = CastleStore.get(@castle_id).emperium_unit_id
      is_integer(id) and id != old_id
    end)

    CastleStore.get(@castle_id).emperium_unit_id
  end

  defp attack(player, unit_id) do
    state = get_player_state(player.pid)
    Combat.execute_attack(state.stats, state, unit_id)
  end

  defp guild_player(castle) do
    {x, y} = castle.emperium
    character = character_fixture(castle.map, {x + 1, y})
    {:ok, guild} = GuildManager.create("Siege#{character.id}", character)
    character = Repo.get!(Character, character.id)
    player = start_player_session(character: character)
    {player, guild.guild_id}
  end

  defp grant_approval(guild_id) do
    {1, nil} =
      from(g in GuildModel, where: g.id == ^guild_id)
      |> Repo.update_all(set: [learned_skills: %{"#{@approval_skill_id}" => 1}])

    :ok = ClusterTestHelper.clear_all()
    {:ok, _guild} = GuildManager.ensure_started(guild_id)
    :ok
  end

  defp character_fixture(map, {x, y}) do
    unique = System.unique_integer([:positive])

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        userid: "w17_#{unique}",
        user_pass: "password",
        sex: "M",
        email: "w17_#{unique}@aesir.test"
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
