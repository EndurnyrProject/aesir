defmodule Aesir.ZoneServer.Integration.CastleEconomyIntegrationTest do
  @moduledoc """
  End-to-end coverage of the WoE First Edition castle economy loop against the
  real subsystems: the castle steward NPC dialog, `Economy`/`Treasure`
  maturation and box spawning, and the conquest penalty applied by
  `Woe.Server` on a guild-credited Emperium break.

  Each test boots its own per-test seeded world (see `IntegrationCase`), so a
  `Woe.Server` is started in-test via `start_supervised!` wherever the
  scenario needs the lifecycle handlers that release treasure slots or apply
  the conquest penalty.
  """

  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  import Aesir.ZoneServer.EtsTable, only: [table_for: 1]
  import Ecto.Query

  alias Aesir.Commons.ClusterTestHelper
  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.Guild, as: GuildModel
  alias Aesir.Commons.Models.GuildCastle
  alias Aesir.Net.GuildActionResult
  alias Aesir.Net.GuildCreateRequest
  alias Aesir.Net.NpcDialog
  alias Aesir.Net.NpcInteract
  alias Aesir.Repo
  alias Aesir.ZoneServer.Content.Npc.Woe.Steward
  alias Aesir.ZoneServer.Guild.Manager, as: GuildManager
  alias Aesir.ZoneServer.Mmo.MobManagement.Mobs
  alias Aesir.ZoneServer.Mmo.Woe.CastleDb
  alias Aesir.ZoneServer.Mmo.Woe.CastleStore
  alias Aesir.ZoneServer.Mmo.Woe.Economy
  alias Aesir.ZoneServer.Mmo.Woe.Server, as: WoeServer
  alias Aesir.ZoneServer.Mmo.Woe.Treasure
  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Interaction
  alias Aesir.ZoneServer.Unit.Inventory.Persistence, as: InventoryPersistence
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @castle_id 0
  @approval_skill_id 10_000
  @emperium_item_id 714
  @emperium_mob_id 1288

  setup do
    on_exit(&ClusterTestHelper.clear_all/0)
    :ok = CastleDb.reload()
    :ok = CastleStore.init()
    :ok
  end

  describe "steward investment" do
    test "the master invests economy twice then hits the daily limit, persisting counters" do
      start_per_test_map(castle().map)

      {master, guild_id} = create_guild("EconomyGuild", "EconomyMaster")
      :ok = grant_zeny(master.character.id, 1_000_000)

      :ok =
        CastleStore.hydrate(%{
          @castle_id => %{
            guild_id: guild_id,
            economy: 0,
            defense: 0,
            invested_economy: 0,
            invested_defense: 0
          }
        })

      master = relocate_character(master, castle().map, castle().respawn)
      gid = steward_gid(castle().map)

      zeny_before = get_player_state(master.pid).zeny

      ipid1 = open_investment_menu(master, gid, 2)
      text1 = confirm_investment(ipid1, gid)
      assert text1 =~ "finished the investment"

      zeny_after_first = get_player_state(master.pid).zeny
      assert zeny_after_first == zeny_before - 5_000

      ipid2 = open_investment_menu(master, gid, 2)
      text2 = confirm_investment(ipid2, gid)
      assert text2 =~ "finished the investment"

      zeny_after_second = get_player_state(master.pid).zeny
      assert zeny_after_second == zeny_after_first - 20_000

      ipid3 = open_investment_menu(master, gid, 2)
      text3 = close_text(ipid3)
      assert text3 =~ "already invested twice today"

      row = Repo.get_by!(GuildCastle, castle_id: @castle_id)
      assert row.invested_economy == 2
    end
  end

  describe "treasure economy loop" do
    test "maturation grows economy, treasure spawns scale with it, and a killed box's slot refills" do
      start_per_test_map(castle().map)
      start_supervised!({WoeServer, []})

      :ok =
        CastleStore.hydrate(%{
          @castle_id => %{
            guild_id: 424_242,
            economy: 0,
            defense: 0,
            invested_economy: 2,
            invested_defense: 0
          }
        })

      :ok = Economy.mature_all()
      assert CastleStore.economy(@castle_id).economy == 2

      :ok = Treasure.spawn_all()
      assert length(Treasure.live_slots(@castle_id)) == 4

      :ok = Treasure.spawn_all()
      assert length(Treasure.live_slots(@castle_id)) == 4

      [slot | _] = Treasure.live_slots(@castle_id) |> Enum.sort()

      [{{@castle_id, ^slot}, unit_id}] =
        :ets.lookup(table_for(:castle_treasure), {@castle_id, slot})

      {:ok, {_module, _mob, pid}} = UnitRegistry.get_unit(:mob, unit_id)
      :ok = MobSession.apply_damage(pid, 999_999, nil)

      assert_eventually(fn -> slot not in Treasure.live_slots(@castle_id) end)

      :ok = Treasure.spawn_all()

      assert_eventually(fn -> slot in Treasure.live_slots(@castle_id) end)
      assert length(Treasure.live_slots(@castle_id)) == 4
    end
  end

  describe "conquest penalty" do
    test "an eligible guild-credited Emperium break reduces economy/defense by five and clears counters" do
      start_per_test_map(castle().map)
      start_supervised!({WoeServer, []})

      :ok =
        CastleStore.hydrate(%{
          @castle_id => %{
            guild_id: nil,
            economy: 20,
            defense: 20,
            invested_economy: 1,
            invested_defense: 1
          }
        })

      {master, guild_id} = create_guild("ConquestGuild", "ConquestMaster")
      seed_learned_skills(guild_id, %{"#{@approval_skill_id}" => 1})

      killer = relocate_character(master, castle().map, castle().emperium)

      :ok = WoeServer.start()

      assert %{emperium_unit_id: unit_id} = CastleStore.get(@castle_id)
      assert is_integer(unit_id)

      {:ok, {_module, _mob, pid}} = UnitRegistry.get_unit(:mob, unit_id)
      :ok = MobSession.apply_damage(pid, 999_999, killer.character.id)

      assert_eventually(fn -> CastleStore.owner(@castle_id) == guild_id end)

      assert_eventually(fn ->
        row = Repo.get_by(GuildCastle, castle_id: @castle_id)

        row.economy == 15 and row.defense == 15 and row.invested_economy == 0 and
          row.invested_defense == 0
      end)
    end
  end

  describe "Emperium HP scales with castle defense" do
    @tag game_mode: :renewal, integration_pre_re: false
    test "renewal HP is the base plus the renewal defense bonus" do
      start_per_test_map(castle().map)
      start_supervised!({WoeServer, []})

      :ok =
        CastleStore.hydrate(%{
          @castle_id => %{
            guild_id: nil,
            economy: 0,
            defense: 100,
            invested_economy: 0,
            invested_defense: 0
          }
        })

      :ok = WoeServer.start()

      {:ok, mob} = Mobs.by_id(@emperium_mob_id)
      assert %{emperium_unit_id: unit_id} = CastleStore.get(@castle_id)
      {:ok, {_module, live_mob, _pid}} = UnitRegistry.get_unit(:mob, unit_id)

      assert live_mob.max_hp == mob.hp + 1_000
    end

    @tag game_mode: :pre_renewal, integration_re: false
    test "pre-renewal HP is the base plus the pre-renewal defense bonus" do
      start_per_test_map(castle().map)
      start_supervised!({WoeServer, []})

      :ok =
        CastleStore.hydrate(%{
          @castle_id => %{
            guild_id: nil,
            economy: 0,
            defense: 100,
            invested_economy: 0,
            invested_defense: 0
          }
        })

      :ok = WoeServer.start()

      {:ok, mob} = Mobs.by_id(@emperium_mob_id)
      assert %{emperium_unit_id: unit_id} = CastleStore.get(@castle_id)
      {:ok, {_module, live_mob, _pid}} = UnitRegistry.get_unit(:mob, unit_id)

      assert live_mob.max_hp == mob.hp + 100_000
    end
  end

  defp castle do
    {:ok, castle} = CastleDb.by_id(@castle_id)
    castle
  end

  defp steward_gid(map_name) do
    Steward.spawn()
    |> Enum.find(&(&1.map == map_name))
    |> NpcRegistry.entity_id()
  end

  defp open_investment_menu(master, gid, choice) do
    session_state = PlayerSession.get_state(master.pid)

    ctx = %Ctx{
      char_id: master.character.id,
      account_id: master.character.account_id,
      connection_pid: session_state.connection_pid,
      game_state: session_state.game_state,
      source: {:npc, Steward.npc_id()},
      npc_gid: gid
    }

    {:ok, ipid} = Interaction.start(master.pid, Steward, ctx)

    assert_receive {:packet_sent, %NpcDialog{expect: :NEXT}, _}, 500
    send(ipid, {:npc_interact, %NpcInteract{npc_id: gid, response: {:continue, true}}})

    assert_receive {:packet_sent, %NpcDialog{expect: :MENU, options: [_, _, _]}, _}, 500
    send(ipid, {:npc_interact, %NpcInteract{npc_id: gid, response: {:choice, choice}}})

    ipid
  end

  defp confirm_investment(ipid, gid) do
    assert_receive {:packet_sent, %NpcDialog{expect: :NEXT}, _}, 500
    send(ipid, {:npc_interact, %NpcInteract{npc_id: gid, response: {:continue, true}}})

    assert_receive {:packet_sent, %NpcDialog{expect: :MENU, options: [_confirm, "Cancel"]}, _},
                   500

    send(ipid, {:npc_interact, %NpcInteract{npc_id: gid, response: {:choice, 1}}})

    close_text(ipid)
  end

  defp close_text(ipid) do
    assert_receive {:packet_sent, %NpcDialog{expect: :CLOSE, text: text}, _}, 500
    await_interaction_end(ipid)
    text
  end

  defp await_interaction_end(pid) do
    ref = Process.monitor(pid)
    assert_receive {:DOWN, ^ref, :process, ^pid, _reason}, 500
  end

  defp grant_zeny(character_id, amount) do
    character = Repo.get!(Character, character_id)
    {:ok, _} = Repo.update(Character.changeset(character, %{zeny: amount}))
    :ok
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

  defp account_fixture(_name) do
    unique = System.unique_integer([:positive])

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        userid: "cecon_#{unique}",
        user_pass: "password",
        sex: "M",
        email: "cecon_#{unique}@example.com"
      })
      |> Repo.insert()

    account
  end
end
