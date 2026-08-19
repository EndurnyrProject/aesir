defmodule Aesir.ZoneServer.Integration.PvpDeathIntegrationTest do
  @moduledoc """
  End-to-end Phase B PvP death/penalty coverage against real sessions, the real
  `Repo`, `MapFlags`, `DamageApplication`, and `Dispatcher`:

    * a player kill on a `:pvp` map persists victim loss (`pvp_point -5`,
      `pvp_lost +1`) and killer credit (`pvp_point +1`, `pvp_won +1`);
    * a mob whose instance id collides with a bystander's character id credits
      nobody, proving the typed `{:mob, id}` ref is not mistaken for a player;
    * a `nil` attacker (reflection's attribution seam) costs the victim but
      credits nobody;
    * a `:gvg` death skips the EXP penalty and respawns at the castle;
    * a normal-map death applies the exact base/job penalty (regression guard);
    * `@pvpon`/`@pvpoff` toggles attackability and replies exactly.

  Map-flag cleanup is the load-bearing detail. `IntegrationCase` seeds a fresh
  EtsTable per test and stores its seed in the test process dictionary;
  `on_exit` callbacks run in a different process without that seed, so any
  `MapFlags.clear_runtime/2` deferred to `on_exit` would resolve the wrong (or a
  missing) flag table. Every test that mutates map flags or GM toggles therefore
  runs inside `with_flags/3`, which clears all four versus flags
  (`:pvp`, `:pvp_noparty`, `:pvp_noguild`, `:gvg`) in the same process `after`
  the body — while the per-test seed is still current.
  """

  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Commons.ClusterTestHelper
  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Net.ChatMessage
  alias Aesir.Net.Respawn
  alias Aesir.Repo
  alias Aesir.ZoneServer.Gm.Dispatcher
  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.DamageApplication
  alias Aesir.ZoneServer.Mmo.Leveling
  alias Aesir.ZoneServer.Mmo.Woe.CastleDb
  alias Aesir.ZoneServer.Unit.Player.PlayerSession

  @map "prontera"
  @versus_flags [:pvp, :pvp_noparty, :pvp_noguild, :gvg]

  setup do
    on_exit(&ClusterTestHelper.clear_all/0)
    :ok = CastleDb.reload()
    :ok = MapFlags.reload()
    :ok
  end

  describe "PvP death" do
    test "a player kill persists victim loss and killer credit" do
      killer = insert_character("PvPKiller")
      victim = insert_character("PvPVictim")

      killer_session =
        start_player_session(character: killer, map_name: @map, position: {150, 150})

      victim_session =
        start_player_session(character: victim, map_name: @map, position: {151, 150})

      with_death_penalty(0, 0, fn ->
        with_flags(@map, [:pvp], fn ->
          deliver_lethal(victim_session, {:player, killer.id})

          assert_eventually(fn -> get_player_state(victim_session.pid).action_state == :dead end)

          assert_eventually(fn ->
            state_counters(victim_session.pid) == %{pvp_point: -5, pvp_won: 0, pvp_lost: 1}
          end)

          assert_eventually(fn ->
            persisted_counters(victim.id) == %{pvp_point: -5, pvp_won: 0, pvp_lost: 1}
          end)

          assert_eventually(fn ->
            state_counters(killer_session.pid) == %{pvp_point: 1, pvp_won: 1, pvp_lost: 0}
          end)

          assert_eventually(fn ->
            persisted_counters(killer.id) == %{pvp_point: 1, pvp_won: 1, pvp_lost: 0}
          end)
        end)
      end)
    end

    test "a mob sharing a character id is not credited as a player kill" do
      victim = insert_character("PvPVictim")
      bystander = insert_character("PvPStandby")

      victim_session =
        start_player_session(character: victim, map_name: @map, position: {150, 150})

      bystander_session =
        start_player_session(character: bystander, map_name: @map, position: {151, 150})

      mob =
        start_mob_session(
          mob_id: 1002,
          unit_id: bystander.id,
          map_name: @map,
          position: {152, 150},
          hp: 100,
          max_hp: 100
        )

      with_death_penalty(0, 0, fn ->
        with_flags(@map, [:pvp], fn ->
          deliver_lethal(victim_session, {:mob, mob.unit_id})

          assert_eventually(fn -> get_player_state(victim_session.pid).action_state == :dead end)

          assert_eventually(fn ->
            persisted_counters(victim.id) == %{pvp_point: -5, pvp_won: 0, pvp_lost: 1}
          end)

          assert_eventually(fn ->
            state_counters(bystander_session.pid) == %{pvp_point: 0, pvp_won: 0, pvp_lost: 0}
          end)

          assert_eventually(fn ->
            persisted_counters(bystander.id) == %{pvp_point: 0, pvp_won: 0, pvp_lost: 0}
          end)
        end)
      end)
    end

    test "a nil attacker costs the victim points but credits nobody" do
      victim = insert_character("PvPVictim")
      bystander = insert_character("PvPStandby")

      victim_session =
        start_player_session(character: victim, map_name: @map, position: {150, 150})

      bystander_session =
        start_player_session(character: bystander, map_name: @map, position: {151, 150})

      with_death_penalty(0, 0, fn ->
        with_flags(@map, [:pvp], fn ->
          deliver_lethal(victim_session, nil)

          assert_eventually(fn -> get_player_state(victim_session.pid).action_state == :dead end)

          assert_eventually(fn ->
            state_counters(victim_session.pid) == %{pvp_point: -5, pvp_won: 0, pvp_lost: 1}
          end)

          assert_eventually(fn ->
            persisted_counters(victim.id) == %{pvp_point: -5, pvp_won: 0, pvp_lost: 1}
          end)

          assert_eventually(fn ->
            state_counters(bystander_session.pid) == %{pvp_point: 0, pvp_won: 0, pvp_lost: 0}
          end)

          assert_eventually(fn ->
            persisted_counters(bystander.id) == %{pvp_point: 0, pvp_won: 0, pvp_lost: 0}
          end)
        end)
      end)
    end
  end

  describe "death penalty" do
    test "a gvg death skips the penalty and respawns at the castle" do
      castle = castle()
      start_per_test_map(castle.map)

      victim = insert_character("PvPCastle", %{last_map: castle.map})

      session =
        start_player_session(
          character: victim,
          map_name: castle.map,
          position: {150, 150}
        )

      with_death_penalty(100, 100, fn ->
        with_flags(castle.map, [:pvp, :gvg], fn ->
          assert MapFlags.get(castle.map, :pvp)
          assert MapFlags.get(castle.map, :gvg)

          deliver_lethal(session, nil)

          assert_eventually(fn ->
            state = get_player_state(session.pid)

            state.action_state == :dead and state.stats.progression.base_exp == 10_000 and
              state.stats.progression.job_exp == 10_000 and state.pvp_point == 0 and
              state.pvp_won == 0 and state.pvp_lost == 0
          end)

          assert_eventually(fn ->
            char = Repo.get!(Character, victim.id)

            char.base_exp == 10_000 and char.job_exp == 10_000 and
              char.pvp_point == 0 and char.pvp_won == 0 and char.pvp_lost == 0
          end)

          simulate_incoming_message(session.pid, %Respawn{type: 0})

          {rx, ry} = castle.respawn

          assert_eventually(fn ->
            state = get_player_state(session.pid)
            state.map_name == castle.map and state.x == rx and state.y == ry
          end)
        end)
      end)
    end

    test "a normal-map death applies the exact base/job penalty" do
      victim = insert_character("PvPNormal")

      session =
        start_player_session(character: victim, map_name: @map, position: {150, 150})

      with_death_penalty(100, 100, fn ->
        before = get_player_state(session.pid).stats.progression

        {base_loss, job_loss} = Leveling.death_penalty(before, 100, 100)
        assert base_loss > 0
        assert job_loss > 0

        deliver_lethal(session, nil)

        assert_eventually(fn -> get_player_state(session.pid).action_state == :dead end)

        dead_state = get_player_state(session.pid)
        assert dead_state.stats.progression.base_exp == before.base_exp - base_loss
        assert dead_state.stats.progression.job_exp == before.job_exp - job_loss
        assert dead_state.pvp_point == 0
        assert dead_state.pvp_won == 0
        assert dead_state.pvp_lost == 0

        assert_eventually(fn ->
          char = Repo.get!(Character, victim.id)

          char.base_exp == before.base_exp - base_loss and
            char.job_exp == before.job_exp - job_loss and
            char.pvp_point == 0 and char.pvp_won == 0 and char.pvp_lost == 0
        end)
      end)
    end
  end

  describe "GM pvp toggles" do
    test "@pvpon/@pvpoff toggle attackability and reply exactly" do
      gm = insert_character("PvpLeader", %{}, gm_level: 99)
      defender = insert_character("PvpDefender", %{hp: 100_000, max_hp: 100_000})

      gm_session =
        start_player_session(character: gm, map_name: @map, position: {150, 150})

      _defender_session =
        start_player_session(character: defender, map_name: @map, position: {151, 150})

      gm_state = PlayerSession.get_state(gm_session.pid)

      assert {:error, :invalid_target} = auto_attack(gm_session, defender.id)

      with_flags(@map, [], fn ->
        flags_before = complete_flags(@map)

        Dispatcher.dispatch("@pvpon bogus", gm_state)

        assert_receive {:packet_sent, %ChatMessage{message: "Usage: @pvpon [noparty] [noguild]"},
                        _},
                       1_000

        assert complete_flags(@map) == flags_before

        Dispatcher.dispatch("@pvpon", gm_state)
        assert_receive {:packet_sent, %ChatMessage{message: "PvP enabled."}, _}, 1_000

        assert :ok = auto_attack(gm_session, defender.id)

        Dispatcher.dispatch("@pvpoff", gm_state)
        assert_receive {:packet_sent, %ChatMessage{message: "PvP disabled."}, _}, 1_000

        assert complete_flags(@map) == %{
                 pvp: false,
                 pvp_noparty: false,
                 pvp_noguild: false,
                 gvg: false
               }

        assert {:error, :invalid_target} = auto_attack(gm_session, defender.id)
      end)
    end
  end

  defp deliver_lethal(victim, attacker) do
    DamageApplication.apply_unit_damage(
      :player,
      victim.pid,
      victim.character.id,
      999_999,
      %{dmg_type: :misc},
      attacker
    )
  end

  defp auto_attack(attacker, target_id) do
    Combat.execute_attack(
      get_player_stats(attacker.pid),
      get_player_state(attacker.pid),
      target_id
    )
  end

  defp state_counters(pid) do
    state = get_player_state(pid)
    %{pvp_point: state.pvp_point, pvp_won: state.pvp_won, pvp_lost: state.pvp_lost}
  end

  defp persisted_counters(char_id) do
    char = Repo.get!(Character, char_id)
    %{pvp_point: char.pvp_point, pvp_won: char.pvp_won, pvp_lost: char.pvp_lost}
  end

  defp complete_flags(map) do
    Map.new(@versus_flags, fn flag -> {flag, MapFlags.get(map, flag)} end)
  end

  defp with_flags(map, flags, fun) do
    Enum.each(flags, fn flag -> :ok = MapFlags.set_runtime(map, flag, true) end)

    try do
      fun.()
    after
      Enum.each(@versus_flags, fn flag -> MapFlags.clear_runtime(map, flag) end)
    end
  end

  defp with_death_penalty(base, job, fun) do
    prev_base = Application.get_env(:zone_server, :death_penalty_base)
    prev_job = Application.get_env(:zone_server, :death_penalty_job)
    Application.put_env(:zone_server, :death_penalty_base, base)
    Application.put_env(:zone_server, :death_penalty_job, job)

    try do
      fun.()
    after
      restore_env(:zone_server, :death_penalty_base, prev_base)
      restore_env(:zone_server, :death_penalty_job, prev_job)
    end
  end

  defp restore_env(app, key, nil), do: Application.delete_env(app, key)
  defp restore_env(app, key, value), do: Application.put_env(app, key, value)

  defp castle do
    {:ok, castle} = CastleDb.by_id(0)
    castle
  end

  defp insert_character(name, attrs \\ %{}, opts \\ []) do
    account = insert_account(Keyword.get(opts, :gm_level, 0))
    insert_character_for(account, name, attrs)
  end

  defp insert_character_for(account, name, attrs) do
    {:ok, character} =
      %Character{}
      |> Character.changeset(
        base_attrs()
        |> Map.merge(attrs)
        |> Map.merge(%{account_id: account.id, name: name})
      )
      |> Repo.insert()

    character
  end

  defp insert_account(gm_level) do
    unique = unique()

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        userid: "pvd_#{unique}",
        user_pass: "password",
        sex: "M",
        email: "pvd_#{unique}@aesir.test",
        gm_level: gm_level
      })
      |> Repo.insert()

    account
  end

  defp base_attrs do
    %{
      char_num: 0,
      class: 0,
      base_level: 10,
      job_level: 5,
      base_exp: 10_000,
      job_exp: 10_000,
      str: 1,
      agi: 1,
      vit: 1,
      int: 1,
      dex: 1,
      luk: 1,
      hp: 100,
      max_hp: 100,
      sp: 50,
      max_sp: 50,
      last_map: @map,
      last_x: 150,
      last_y: 150,
      save_map: @map,
      save_x: 150,
      save_y: 150,
      pvp_point: 0,
      pvp_won: 0,
      pvp_lost: 0,
      learned_skills: %{}
    }
  end

  defp unique, do: System.unique_integer([:positive]) |> Integer.to_string(36)
end
