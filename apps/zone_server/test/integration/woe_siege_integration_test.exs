defmodule Aesir.ZoneServer.Integration.WoeSiegeIntegrationTest do
  @moduledoc """
  End-to-end coverage of the WoE siege loop against the real subsystems:
  `Woe.Server`, `CastleStore`, `Woe.Persistence`, `MapFlags`, the mob
  owner-event capture path, the same-map respawn hook, and the map-aware
  guild-skill GvG gate.

  Each test boots its own per-test seeded world (see `IntegrationCase`), so a
  `Woe.Server` is started in-test via `start_supervised!` — the app-level
  supervisor excludes it under `:test` (Task 13), exactly like the clock
  scheduler. `CastleDb`/`MapFlags`/`CastleStore` are re-initialised against the
  per-test seed, mirroring the boot sequence.
  """

  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  import Aesir.ZoneServer.EtsTable, only: [table_for: 1]
  import Ecto.Query

  alias Aesir.Commons.ClusterTestHelper
  alias Aesir.Commons.InterServer.PubSub, as: ServerPubSub
  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.Guild, as: GuildModel
  alias Aesir.Commons.Models.GuildCastle
  alias Aesir.Net.Announcement, as: AnnouncementMsg
  alias Aesir.Net.GuildActionResult
  alias Aesir.Net.GuildCreateRequest
  alias Aesir.Net.Respawn
  alias Aesir.Net.SkillCast
  alias Aesir.Net.SkillCastFailed
  alias Aesir.Repo
  alias Aesir.ZoneServer.Guild.Manager, as: GuildManager
  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Mmo.Woe.CastleDb
  alias Aesir.ZoneServer.Mmo.Woe.CastleStore
  alias Aesir.ZoneServer.Mmo.Woe.Persistence
  alias Aesir.ZoneServer.Mmo.Woe.Server, as: WoeServer
  alias Aesir.ZoneServer.Unit.Inventory.Persistence, as: InventoryPersistence
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobSupervisor
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @castle_id 0
  @emperium_event "WoeController::OnEmperiumBreak"
  @emperium_item_id 714
  @gd_battleorder 10_010

  setup do
    on_exit(&ClusterTestHelper.clear_all/0)
    :ok = CastleDb.reload()
    :ok = MapFlags.reload()
    :ok = CastleStore.init()
    :ok
  end

  describe "Emperium break → capture" do
    test "a guilded player breaking the Emperium captures, persists, broadcasts, and respawns it" do
      start_per_test_map(castle().map)
      start_supervised!({WoeServer, []})

      with_env(:woe_emperium_respawn_ms, 100, fn ->
        {master_on_prontera, guild_id} = create_guild("SiegeGuild", "SiegeMaster")

        killer =
          relocate_character(master_on_prontera, castle().map, castle().emperium)

        assert get_player_state(killer.pid).guild_id == guild_id

        :ok = ServerPubSub.subscribe_to_announcements()

        :ok = WoeServer.start()
        assert WoeServer.active?()
        assert MapFlags.get(castle().map, :gvg)

        assert_receive {:announcement, %AnnouncementMsg{text: "WoE has begun"}}, 500

        assert %{emperium_unit_id: old_unit_id} = CastleStore.get(@castle_id)
        assert is_integer(old_unit_id)

        {:ok, {_module, _mob, mob_pid}} = UnitRegistry.get_unit(:mob, old_unit_id)
        :ok = MobSession.apply_damage(mob_pid, 999_999, killer.character.id)

        assert_eventually(fn -> CastleStore.owner(@castle_id) == guild_id end)
        assert CastleStore.get(@castle_id).epoch == 1

        assert_eventually(fn ->
          Repo.get_by(GuildCastle, castle_id: @castle_id).guild_id == guild_id
        end)

        assert_receive {:announcement, %AnnouncementMsg{text: conquest}}, 1_000
        assert conquest == "#{castle().name} conquered by SiegeGuild"

        assert_eventually(
          fn ->
            respawned = CastleStore.get(@castle_id).emperium_unit_id
            is_integer(respawned) and respawned != old_unit_id
          end,
          2_000
        )
      end)
    end

    test "ownership survives a simulated restart by re-hydrating from the persisted row" do
      guild_id = 4242
      :ok = Persistence.persist(@castle_id, guild_id)

      :ets.delete_all_objects(table_for(:castle_states))
      :ok = CastleStore.init()

      assert CastleStore.owner(@castle_id) == nil

      :ok = CastleStore.hydrate(Persistence.load_all())

      assert CastleStore.owner(@castle_id) == guild_id
    end

    test "the Emperium capture path is unreachable without AgitStart" do
      start_per_test_map(castle().map)
      start_supervised!({WoeServer, []})

      refute WoeServer.active?()
      refute MapFlags.get(castle().map, :gvg)
      assert CastleStore.get(@castle_id).siege_active? == false
      assert MobSupervisor.count_by_event(castle().map, @emperium_event) == 0

      assert WoeServer.capture(@castle_id, 0, 999, 1) == {:error, :not_active}
      assert CastleStore.owner(@castle_id) == nil
    end
  end

  describe "same-map WoE respawn" do
    test "dying on a gvg-active castle map respawns at the castle respawn point" do
      :ok = MapFlags.set_runtime(castle().map, :gvg, true)

      character =
        character_fixture("WoeDead", %{
          hp: 100,
          max_hp: 100,
          last_map: castle().map,
          last_x: 150,
          last_y: 150
        })

      session =
        start_player_session(
          character: character,
          map_name: castle().map,
          position: {150, 150}
        )

      :ok = PlayerSession.apply_damage(session.pid, 999_999, nil)

      assert_eventually(fn -> get_player_state(session.pid).action_state == :dead end)

      simulate_incoming_message(session.pid, %Respawn{type: 0})

      {rx, ry} = castle().respawn

      assert_eventually(fn ->
        state = get_player_state(session.pid)
        state.map_name == castle().map and state.x == rx and state.y == ry
      end)
    end
  end

  describe "map-aware guild-skill GvG gate" do
    test "a guild active is rejected off-castle and permitted on a gvg-active castle map" do
      with_env(:guild_skills_gvg_only, true, fn ->
        {master_session, guild_id} = create_guild("GvgGuild", "GvgMaster")
        master_id = master_session.character.id

        seed_learned_skills(guild_id, %{"#{@gd_battleorder}" => 1})

        # Off-castle (prontera, not gvg): the gate rejects the cast.
        simulate_incoming_message(master_session.pid, %SkillCast{
          skill_id: @gd_battleorder,
          level: 1,
          target_id: master_id
        })

        assert_receive {:packet_sent,
                        %SkillCastFailed{
                          skill_id: @gd_battleorder,
                          reason: :SKILL_CAST_FAILURE_REASON_UNSPECIFIED
                        }, _},
                       1_000

        refute StatusStorage.has_status?(:player, master_id, :sc_battleorder)

        # On a gvg-active castle map: the same cast is permitted.
        :ok = MapFlags.set_runtime(castle().map, :gvg, true)

        master_on_castle = relocate_character(master_session, castle().map, castle().respawn)

        assert get_player_state(master_on_castle.pid).map_name == castle().map

        simulate_incoming_message(master_on_castle.pid, %SkillCast{
          skill_id: @gd_battleorder,
          level: 1,
          target_id: master_id
        })

        assert_eventually(fn ->
          StatusStorage.has_status?(:player, master_id, :sc_battleorder)
        end)
      end)
    end
  end

  describe "versus hostility" do
    test ":gvg runtime flag makes differently-guilded players enemies and same-guild players allies" do
      start_per_test_map(castle().map)

      {attacker_on_prontera, guild_id} = create_guild("GvgGuildA", "GvgAttacker")

      attacker = relocate_character(attacker_on_prontera, castle().map, castle().respawn)

      {rx, ry} = castle().respawn

      same_character =
        character_fixture("GvgSame", %{
          last_map: castle().map,
          last_x: rx,
          last_y: ry
        })

      {:ok, _guild_state} = GuildManager.add_member(guild_id, same_character)

      same_character = Repo.get!(Character, same_character.id)

      same =
        start_player_session(
          character: same_character,
          map_name: castle().map,
          position: {rx, ry}
        )

      {different_on_prontera, different_guild_id} = create_guild("GvgGuildB", "GvgDifferent")

      different = relocate_character(different_on_prontera, castle().map, castle().respawn)

      assert guild_id > 0
      assert different_guild_id > 0
      assert guild_id != different_guild_id

      assert get_player_state(attacker.pid).guild_id == guild_id
      assert get_player_state(same.pid).guild_id == guild_id
      assert get_player_state(different.pid).guild_id == different_guild_id

      :ok = MapFlags.set_runtime(castle().map, :gvg, true)

      assert :ok =
               Targeting.validate_enemy(
                 get_player_state(attacker.pid),
                 get_player_state(different.pid)
               )

      assert {:error, :invalid_target} =
               Targeting.validate_enemy(
                 get_player_state(attacker.pid),
                 get_player_state(same.pid)
               )
    end
  end

  defp castle do
    {:ok, castle} = CastleDb.by_id(@castle_id)
    castle
  end

  defp create_guild(name, master_name) do
    master = character_fixture(master_name, %{})
    :ok = seed_emperium(master.id, 2)
    session = start_session(master)

    simulate_incoming_message(session.pid, %GuildCreateRequest{name: name})

    assert_receive {:packet_sent, %GuildActionResult{action: "create", success: true}, _}, 1_000

    guild_id = Repo.get(Character, master.id).guild_id
    assert guild_id > 0

    flush_packets()

    {session, guild_id}
  end

  # `PlayerState.new/1` sources the session's `map_name` from `character.last_map`,
  # not from the `map_name` option, so a re-login must persist the new position first.
  defp relocate_character(session, map_name, {x, y}) do
    character = Repo.get!(Character, session.character.id)

    {:ok, character} =
      Repo.update(Character.changeset(character, %{last_map: map_name, last_x: x, last_y: y}))

    end_player_session(session)

    start_player_session(character: character, map_name: map_name, position: {x, y})
  end

  defp seed_emperium(char_id, amount) do
    {:ok, _item} =
      InventoryPersistence.insert_item(char_id, %{
        nameid: @emperium_item_id,
        amount: amount,
        identify: 1
      })

    :ok
  end

  defp seed_learned_skills(guild_id, learned_skills) do
    {1, nil} =
      from(g in GuildModel, where: g.id == ^guild_id)
      |> Repo.update_all(set: [learned_skills: learned_skills])

    refresh_entry(guild_id)
  end

  defp refresh_entry(guild_id) do
    :ok = ClusterTestHelper.clear_all()
    {:ok, _} = GuildManager.ensure_started(guild_id)
    :ok
  end

  defp start_session(%Character{} = character) do
    start_player_session(character: character, map_name: "prontera", position: {150, 150})
  end

  defp character_fixture(name, attrs) do
    account = account_fixture(name)

    {:ok, character} =
      attrs
      |> Enum.into(%{
        char_num: 0,
        class: 0,
        base_level: 50,
        hp: 100,
        max_hp: 100,
        account_id: account.id,
        name: name,
        last_map: "prontera",
        last_x: 150,
        last_y: 150,
        save_map: "prontera",
        save_x: 150,
        save_y: 150
      })
      |> Character.new()
      |> Repo.insert()

    character
  end

  defp account_fixture(userid) do
    unique = System.unique_integer([:positive])

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        userid: "woe_#{userid}_#{unique}",
        user_pass: "password",
        sex: "M",
        email: "woe_#{unique}@example.com"
      })
      |> Repo.insert()

    account
  end

  defp with_env(key, value, fun) do
    previous = Application.get_env(:zone_server, key)
    Application.put_env(:zone_server, key, value)

    try do
      fun.()
    after
      case previous do
        nil -> Application.delete_env(:zone_server, key)
        _ -> Application.put_env(:zone_server, key, previous)
      end
    end
  end
end
