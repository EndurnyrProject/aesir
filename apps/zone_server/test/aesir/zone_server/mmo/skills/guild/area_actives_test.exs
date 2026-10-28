defmodule Aesir.ZoneServer.Mmo.Skills.Guild.AreaActivesTest do
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Guild.Manager, as: GuildManager
  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Guild.GdBattleorder
  alias Aesir.ZoneServer.Mmo.Skills.Guild.GdRestore
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.EmergencyMove
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Regeneration
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!
  setup :set_mimic_from_context
  setup :setup_ets_tables

  setup do
    stub_guild_master(1)
    :ok
  end

  @master_id 1
  @member_id 2
  @outsider_id 3
  @guild_id 5

  defp register_player(id, guild_id, {x, y}) do
    player =
      %Character{
        id: id,
        account_id: id,
        name: "Player #{id}",
        last_map: "prontera",
        last_x: x,
        last_y: y,
        sex: "M",
        str: 1,
        agi: 1,
        vit: 1,
        int: 1,
        dex: 1,
        luk: 1,
        base_level: 50,
        job_level: 50,
        class: 12
      }
      |> PlayerState.new()
      |> Map.put(:guild_id, guild_id)

    :ok = UnitRegistry.register_player(player, self())
    :ok = SpatialIndex.add_unit(:player, id, x, y, "prontera")
    player
  end

  defp stub_guild_master(master_char_id) do
    stub(GuildManager, :get, fn @guild_id ->
      {:ok, %{master_char_id: master_char_id}}
    end)
  end

  describe "begin_attempt/4" do
    setup do
      stub(MapFlags, :get, fn
        "castle", :gvg_castle -> true
        _map, _flag -> false
      end)

      stub(MapFlags, :gvg2?, fn map_name -> map_name == "castle" end)

      {:ok, definition} = Catalog.by_id(10_010)
      %{definition: definition}
    end

    test "fails off GvG ground before looking at the caster", %{definition: definition} do
      master = %PlayerState{character_id: @master_id, account_id: 1, guild_id: @guild_id}
      guildless = %{master | guild_id: 0}

      for caster <- [master, guildless] do
        assert {:error, :not_gvg_ground} =
                 GdBattleorder.begin_attempt(
                   %{caster | map_name: "prontera"},
                   :self,
                   1,
                   definition
                 )
      end
    end

    test "drops a non-master or a guildless caster silently on GvG ground", %{
      definition: definition
    } do
      non_master = %PlayerState{
        character_id: 99,
        account_id: 99,
        guild_id: @guild_id,
        map_name: "castle"
      }

      guildless = %{non_master | guild_id: 0}

      for caster <- [non_master, guildless] do
        assert {:error, :guild_skill_unavailable} =
                 GdBattleorder.begin_attempt(caster, :self, 1, definition)
      end
    end

    test "accepts the guild master on GvG ground", %{definition: definition} do
      master = %PlayerState{
        character_id: @master_id,
        account_id: 1,
        guild_id: @guild_id,
        map_name: "castle"
      }

      assert {:ok, ^master} = GdBattleorder.begin_attempt(master, :self, 1, definition)
    end
  end

  describe "GD_BATTLEORDER cast" do
    test "buffs same-guild players in radius (caster included), skipping outsiders" do
      master = register_player(@master_id, @guild_id, {10, 10})
      register_player(@member_id, @guild_id, {12, 10})
      register_player(@outsider_id, 0, {11, 10})

      {:ok, definition} = Catalog.by_id(10_010)
      assert {:ok, _caster} = GdBattleorder.cast(master, :self, 1, definition)

      for id <- [@master_id, @member_id] do
        assert [%StatusEntry{type: :sc_battleorder}] =
                 StatusStorage.get_unit_statuses(:player, id)
      end

      assert StatusStorage.get_unit_statuses(:player, @outsider_id) == []
    end

    test "the area is a square: a corner guildmate is buffed, one cell beyond is not" do
      master = register_player(@master_id, @guild_id, {20, 20})
      register_player(@member_id, @guild_id, {35, 35})
      register_player(4, @guild_id, {36, 20})

      {:ok, definition} = Catalog.by_id(10_010)
      assert {:ok, _caster} = GdBattleorder.cast(master, :self, 1, definition)

      assert [%StatusEntry{type: :sc_battleorder}] =
               StatusStorage.get_unit_statuses(:player, @member_id)

      assert StatusStorage.get_unit_statuses(:player, 4) == []
    end

    test "the effect needs only a guild, not the master" do
      peon = register_player(@member_id, @guild_id, {10, 10})

      {:ok, definition} = Catalog.by_id(10_010)
      assert {:ok, _caster} = GdBattleorder.cast(peon, :self, 1, definition)

      assert [%StatusEntry{type: :sc_battleorder}] =
               StatusStorage.get_unit_statuses(:player, @member_id)
    end
  end

  describe "GD_RESTORE cast" do
    test "restores 90% max HP and SP to guildmates in radius" do
      master = register_player(@master_id, @guild_id, {10, 10})
      register_player(@member_id, @guild_id, {11, 10})

      test_pid = self()

      stub(Combat, :apply_heal, fn :player, char_id, amount, @master_id ->
        send(test_pid, {:healed, char_id, amount})
        :ok
      end)

      stub(PlayerSession, :restore_sp, fn _pid, amount ->
        send(test_pid, {:sp, amount})
        :ok
      end)

      {:ok, definition} = Catalog.by_id(10_012)
      assert {:ok, _caster} = GdRestore.cast(master, :self, 1, definition)

      max_hp = master.stats.derived_stats.max_hp
      max_sp = master.stats.derived_stats.max_sp

      assert_received {:healed, @master_id, amount_master}
      assert amount_master == div(max_hp * 90, 100)
      assert_received {:healed, @member_id, _amount_member}
      assert_received {:sp, sp_amount}
      assert sp_amount == div(max_sp * 90, 100)
    end
  end

  describe "cooldowns the effect arms" do
    @tag game_mode: :renewal
    test "renewal re-arms the cast skill's own cooldown" do
      master = register_player(@master_id, @guild_id, {10, 10})
      {:ok, definition} = Catalog.by_id(10_010)

      assert GdBattleorder.rearm_cooldowns(master, 1, definition, 1_000).skill_cooldowns ==
               %{10_010 => 181_000}
    end

    @tag game_mode: :pre_renewal
    test "pre-renewal blocks Battle Orders, Regeneration, Restore and Urgent Call" do
      master = register_player(@master_id, @guild_id, {10, 10})
      {:ok, definition} = Catalog.by_id(10_012)

      assert GdRestore.rearm_cooldowns(master, 1, definition, 1_000).skill_cooldowns ==
               Map.new([10_010, 10_011, 10_012, 10_013], &{&1, 301_000})
    end

    test "a guildless caster arms nothing" do
      caster = register_player(@outsider_id, 0, {10, 10})
      {:ok, definition} = Catalog.by_id(10_010)

      assert GdBattleorder.rearm_cooldowns(caster, 1, definition, 1_000).skill_cooldowns == %{}
    end
  end

  describe "modifier maps" do
    test "regeneration follows the reference rate table" do
      assert Regeneration.modifiers(%StatusEntry{type: :sc_regeneration, val1: 1}, %{}) ==
               %{hp_regen_tick_rate: 200, sp_regen_tick_rate: 100}

      assert Regeneration.modifiers(%StatusEntry{type: :sc_regeneration, val1: 2}, %{}) ==
               %{hp_regen_tick_rate: 200, sp_regen_tick_rate: 200}

      assert Regeneration.modifiers(%StatusEntry{type: :sc_regeneration, val1: 3}, %{}) ==
               %{hp_regen_tick_rate: 300, sp_regen_tick_rate: 300}
    end

    test "emergency move grants +25% movement speed" do
      assert EmergencyMove.modifiers(%StatusEntry{type: :sc_emergency_move}, %{}) ==
               %{haste_rate: 25}
    end
  end
end
