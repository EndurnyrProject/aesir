defmodule Aesir.ZoneServer.Integration.PvpCombatIntegrationTest do
  @moduledoc """
  End-to-end Phase A PvP coverage against two real player sessions on a
  versus map: auto-attack, a physical `:target_enemy` skill, and a bolt each
  damage a hostile defender; party and guild protection plus their `noparty` /
  `noguild` overrides; heal still lands on an enemy; a non-versus map still
  blocks player damage; the WoE `:gvg` case; and equip-break on a player
  victim.

  Characters are persisted so skill casts (SP persistence) and social fixtures
  work for real. Runtime flags are scoped with `with_flags/2`, which clears
  them in the same test process after the block exits — while the per-test
  seeded flag ETS table is still alive — rather than deferring to `on_exit`.
  """
  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Commons.ClusterTestHelper
  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Net.DamageDealt
  alias Aesir.Net.SkillCast
  alias Aesir.Net.SkillDamage
  alias Aesir.Repo
  alias Aesir.ZoneServer.Guild.Manager, as: GuildManager
  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.EquipBreak
  alias Aesir.ZoneServer.Party.Manager, as: PartyManager
  alias Aesir.ZoneServer.Unit.Inventory.Persistence, as: InventoryPersistence
  alias Aesir.ZoneServer.Unit.Player.PlayerSession

  @map "prontera"

  @bash 5
  @firebolt 19
  @heal 28

  @sword 1101
  @right_hand 2

  setup do
    on_exit(&ClusterTestHelper.clear_all/0)
    :ok = MapFlags.reload()
    :ok
  end

  describe "runtime :pvp hostility" do
    test "auto-attack damages a hostile defender" do
      {attacker, defender} = scenario(attacker_attrs(), defender_attrs())

      with_flags(:pvp, fn ->
        flush_packets()
        hp_before = get_player_state(defender.pid).stats.current_state.hp

        assert :ok = auto_attack(attacker, defender.character.id)

        packet = positive_attack_packet(defender.character.id)
        assert packet, "no positive-damage packet for the defender"
        assert packet.src_id == attacker.character.id

        assert_eventually(fn ->
          get_player_state(defender.pid).stats.current_state.hp < hp_before
        end)
      end)
    end

    test "SM_BASH physical skill damages a hostile defender" do
      {attacker, defender} = scenario(attacker_attrs([@bash]), defender_attrs())

      with_flags(:pvp, fn ->
        flush_packets()
        hp_before = get_player_state(defender.pid).stats.current_state.hp

        cast_skill(attacker, @bash, defender.character.id)

        packet = positive_skill_packet(@bash, defender.character.id)
        assert packet, "no positive-damage SkillDamage packet for the defender"
        assert packet.src_id == attacker.character.id

        assert_eventually(fn ->
          get_player_state(defender.pid).stats.current_state.hp < hp_before
        end)
      end)
    end

    test "MG_FIREBOLT bolt damages a hostile defender" do
      {attacker, defender} = scenario(attacker_attrs([@firebolt]), defender_attrs())

      with_flags(:pvp, fn ->
        flush_packets()
        hp_before = get_player_state(defender.pid).stats.current_state.hp

        cast_skill(attacker, @firebolt, defender.character.id)

        assert_eventually(fn ->
          get_player_state(defender.pid).stats.current_state.hp < hp_before
        end)

        packet = positive_skill_packet(@firebolt, defender.character.id)
        assert packet, "no positive-damage SkillDamage packet for the defender"
        assert packet.src_id == attacker.character.id
      end)
    end
  end

  describe "social protection and overrides" do
    test "same-party pair cannot attack until :pvp_noparty re-enables" do
      attacker_char = insert_character("PartyAtk", attacker_attrs())
      defender_char = insert_character("PartyDef", defender_attrs())

      {:ok, party} = PartyManager.create("PvPParty#{unique()}", attacker_char)
      {:ok, _state} = PartyManager.add_member(party.party_id, defender_char)

      {attacker, defender} = reload_and_pair(attacker_char.id, defender_char.id)

      with_flags(:pvp, fn ->
        assert get_player_state(attacker.pid).party_id > 0
        assert get_player_state(attacker.pid).party_id == get_player_state(defender.pid).party_id

        flush_packets()
        blocked_hp = get_player_state(defender.pid).stats.current_state.hp

        assert {:error, :invalid_target} = auto_attack(attacker, defender.character.id)

        assert get_player_state(defender.pid).stats.current_state.hp == blocked_hp
        refute_positive_attack_packet(defender.character.id)

        with_flags(:pvp_noparty, fn ->
          flush_packets()
          hp_before = get_player_state(defender.pid).stats.current_state.hp

          assert :ok = auto_attack(attacker, defender.character.id)

          packet = positive_attack_packet(defender.character.id)
          assert packet, "no positive-damage packet for the defender after noparty"
          assert packet.src_id == attacker.character.id

          assert_eventually(fn ->
            get_player_state(defender.pid).stats.current_state.hp < hp_before
          end)
        end)
      end)
    end

    test "same-guild pair cannot attack until :pvp_noguild re-enables" do
      attacker_char = insert_character("GuildAtk", attacker_attrs())
      defender_char = insert_character("GuildDef", defender_attrs())

      {:ok, guild} = GuildManager.create("PvPGuild#{unique()}", attacker_char)
      {:ok, _state} = GuildManager.add_member(guild.guild_id, defender_char)

      {attacker, defender} = reload_and_pair(attacker_char.id, defender_char.id)

      with_flags(:pvp, fn ->
        assert get_player_state(attacker.pid).guild_id > 0
        assert get_player_state(attacker.pid).guild_id == get_player_state(defender.pid).guild_id

        flush_packets()
        blocked_hp = get_player_state(defender.pid).stats.current_state.hp

        assert {:error, :invalid_target} = auto_attack(attacker, defender.character.id)

        assert get_player_state(defender.pid).stats.current_state.hp == blocked_hp
        refute_positive_attack_packet(defender.character.id)

        with_flags(:pvp_noguild, fn ->
          flush_packets()
          hp_before = get_player_state(defender.pid).stats.current_state.hp

          assert :ok = auto_attack(attacker, defender.character.id)

          packet = positive_attack_packet(defender.character.id)
          assert packet, "no positive-damage packet for the defender after noguild"
          assert packet.src_id == attacker.character.id

          assert_eventually(fn ->
            get_player_state(defender.pid).stats.current_state.hp < hp_before
          end)
        end)
      end)
    end
  end

  describe "heal stays target-any" do
    test "a healer restores HP on an enemy defender" do
      {attacker, defender} =
        scenario(attacker_attrs([@heal]), Map.put(defender_attrs(), :hp, 100))

      with_flags(:pvp, fn ->
        flush_packets()

        PlayerSession.apply_damage(defender.pid, 40, nil)

        assert_eventually(fn ->
          get_player_state(defender.pid).stats.current_state.hp < 100
        end)

        hp_before = get_player_state(defender.pid).stats.current_state.hp

        cast_skill(attacker, @heal, defender.character.id)

        assert_eventually(fn ->
          get_player_state(defender.pid).stats.current_state.hp > hp_before
        end)
      end)
    end
  end

  describe "non-versus map" do
    test "auto-attack against a player is rejected without a versus flag" do
      {attacker, defender} = scenario(attacker_attrs(), defender_attrs())
      flush_packets()

      hp_before = get_player_state(defender.pid).stats.current_state.hp

      assert {:error, :invalid_target} = auto_attack(attacker, defender.character.id)

      assert get_player_state(defender.pid).stats.current_state.hp == hp_before
      refute_positive_attack_packet(defender.character.id)
    end
  end

  describe "WoE :gvg hostility" do
    test "differently-guilded players fight but same-guild allies cannot" do
      attacker_char = insert_character("GvgAtk", attacker_attrs())
      ally_char = insert_character("GvgAlly", defender_attrs())
      enemy_char = insert_character("GvgEnemy", defender_attrs())

      {:ok, guild_a} = GuildManager.create("GuildA#{unique()}", attacker_char)
      {:ok, _state} = GuildManager.add_member(guild_a.guild_id, ally_char)
      {:ok, _other} = GuildManager.create("GuildB#{unique()}", enemy_char)

      attacker_char = Repo.get!(Character, attacker_char.id)
      ally_char = Repo.get!(Character, ally_char.id)
      enemy_char = Repo.get!(Character, enemy_char.id)

      attacker =
        start_player_session(character: attacker_char, map_name: @map, position: {150, 150})

      ally = start_player_session(character: ally_char, map_name: @map, position: {151, 150})
      enemy = start_player_session(character: enemy_char, map_name: @map, position: {150, 151})

      with_flags(:gvg, fn ->
        assert get_player_state(attacker.pid).guild_id == get_player_state(ally.pid).guild_id
        refute get_player_state(attacker.pid).guild_id == get_player_state(enemy.pid).guild_id

        flush_packets()
        blocked_hp = get_player_state(ally.pid).stats.current_state.hp

        assert {:error, :invalid_target} = auto_attack(attacker, ally.character.id)

        assert get_player_state(ally.pid).stats.current_state.hp == blocked_hp
        refute_positive_attack_packet(ally.character.id)

        hp_before = get_player_state(enemy.pid).stats.current_state.hp
        assert :ok = auto_attack(attacker, enemy.character.id)

        packet = positive_attack_packet(enemy.character.id)
        assert packet, "no positive-damage packet for the differently-guilded defender"
        assert packet.src_id == attacker.character.id

        assert_eventually(fn ->
          get_player_state(enemy.pid).stats.current_state.hp < hp_before
        end)
      end)
    end
  end

  describe "equip-break on a player victim" do
    test "a real player hit breaks and unequips the defender's weapon" do
      attacker_char = insert_character("BreakAtk", attacker_attrs())
      defender_char = insert_character("BreakDef", defender_attrs())
      seed_item(defender_char.id, @sword, @right_hand)

      {attacker, defender} =
        create_pvp_scenario([character: attacker_char], character: defender_char)

      with_flags(:pvp, fn ->
        stub(EquipBreak, :resolve, fn _stats, _target -> [{:target, :weapon}] end)
        flush_packets()

        assert :ok = auto_attack(attacker, defender.character.id)

        assert_eventually(fn -> broken_sword?(defender.pid) end)

        assert %InventoryItem{attribute: 1, equip: 0} =
                 InventoryPersistence.load_inventory(defender_char.id)
                 |> Enum.find(&(&1.nameid == @sword))
      end)
    end
  end

  # Scenario / fixture helpers

  defp scenario(attacker_attrs, defender_attrs) do
    create_pvp_scenario(
      [character: insert_character("PvPAtk", attacker_attrs)],
      character: insert_character("PvPDef", defender_attrs)
    )
  end

  defp reload_and_pair(attacker_id, defender_id) do
    create_pvp_scenario(
      [character: Repo.get!(Character, attacker_id)],
      character: Repo.get!(Character, defender_id)
    )
  end

  defp insert_character(name, attrs) do
    uniq = unique()

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        userid: "pvp_#{name}_#{uniq}",
        user_pass: "password",
        sex: "M",
        email: "pvp_#{name}_#{uniq}@aesir.test"
      })
      |> Repo.insert()

    {:ok, character} =
      %Character{}
      |> Character.changeset(
        Map.merge(
          %{
            account_id: account.id,
            char_num: 0,
            name: name,
            class: 0,
            base_level: 1,
            job_level: 1,
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
            learned_skills: %{}
          },
          attrs
        )
      )
      |> Repo.insert()

    character
  end

  defp attacker_attrs(skills \\ []) do
    %{
      base_level: 99,
      job_level: 50,
      str: 99,
      agi: 99,
      vit: 99,
      int: 99,
      dex: 99,
      luk: 1,
      hp: 100_000,
      max_hp: 100_000,
      sp: 10_000,
      max_sp: 10_000,
      learned_skills: learned(skills)
    }
  end

  defp defender_attrs do
    %{
      base_level: 99,
      job_level: 50,
      str: 1,
      agi: 0,
      vit: 99,
      int: 1,
      dex: 1,
      luk: 0,
      hp: 100_000,
      max_hp: 100_000,
      sp: 10_000,
      max_sp: 10_000
    }
  end

  defp learned(ids), do: Map.new(ids, &{Integer.to_string(&1), 1})

  defp with_flags(flags, fun) do
    flags = List.wrap(flags)
    Enum.each(flags, fn flag -> :ok = MapFlags.set_runtime(@map, flag, true) end)

    try do
      fun.()
    after
      Enum.each(flags, &MapFlags.clear_runtime(@map, &1))
    end
  end

  defp auto_attack(attacker, target_id) do
    Combat.execute_attack(
      get_player_stats(attacker.pid),
      get_player_state(attacker.pid),
      target_id
    )
  end

  defp cast_skill(caster, skill_id, target_id) do
    simulate_incoming_message(caster.pid, %SkillCast{
      skill_id: skill_id,
      level: 1,
      target_id: target_id
    })
  end

  defp positive_attack_packet(target_id) do
    DamageDealt
    |> collect_packets_of_type(200)
    |> Enum.find(&(&1.target_id == target_id and &1.damage > 0))
  end

  defp refute_positive_attack_packet(target_id) do
    packets =
      DamageDealt
      |> collect_packets_of_type(200)
      |> Enum.filter(&(&1.target_id == target_id and &1.damage > 0))

    assert packets == [],
           "expected no positive-damage packet for target #{target_id}, got #{inspect(packets)}"
  end

  defp positive_skill_packet(skill_id, target_id) do
    SkillDamage
    |> collect_packets_of_type(200)
    |> Enum.find(&(&1.skill_id == skill_id and &1.target_id == target_id and &1.damage > 0))
  end

  defp seed_item(char_id, nameid, equip) do
    {:ok, _item} =
      InventoryPersistence.insert_item(char_id, %{
        nameid: nameid,
        amount: 1,
        identify: 1,
        equip: equip
      })

    :ok
  end

  defp broken_sword?(pid) do
    pid
    |> get_player_state()
    |> Map.fetch!(:inventory)
    |> Map.values()
    |> Enum.find(&(&1.nameid == @sword))
    |> case do
      %InventoryItem{attribute: 1, equip: 0} -> true
      _ -> false
    end
  end

  defp unique, do: System.unique_integer([:positive])
end
