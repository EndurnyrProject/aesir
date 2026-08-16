defmodule Aesir.ZoneServer.Mmo.Skills.Guild.AreaActivesTest do
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Guild.Manager, as: GuildManager
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

  describe "definitions" do
    test "all four actives resolve through the catalog with reference metadata" do
      assert {:ok, battleorder} = Catalog.by_id(10_010)
      assert battleorder.splash_radius == 15
      assert battleorder.cooldown == [180_000]

      assert {:ok, regeneration} = Catalog.by_id(10_011)
      assert regeneration.max_level == 3

      assert {:ok, restore} = Catalog.by_id(10_012)
      assert restore.fixed_cast_time == [1_000]

      assert {:ok, emergency_move} = Catalog.by_id(10_019)
      assert emergency_move.cooldown == [60_000]
    end
  end

  describe "validate/4" do
    test "rejects a non-master and a guildless caster on every entry point" do
      stub_guild_master(@master_id)
      {:ok, definition} = Catalog.by_id(10_010)

      non_master = %PlayerState{character_id: 99, account_id: 99, guild_id: @guild_id}
      guildless = %PlayerState{character_id: 99, account_id: 99, guild_id: 0}

      assert {:error, :not_guild_master} =
               GdBattleorder.validate(non_master, :self, 1, definition)

      assert {:error, :not_guild_master} = GdBattleorder.validate(guildless, :self, 1, definition)
    end

    test "accepts the guild master" do
      stub_guild_master(@master_id)
      {:ok, definition} = Catalog.by_id(10_010)
      master = %PlayerState{character_id: @master_id, account_id: 1, guild_id: @guild_id}

      assert :ok = GdBattleorder.validate(master, :self, 1, definition)
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

    test "an out-of-radius guildmate is not buffed" do
      master = register_player(@master_id, @guild_id, {10, 10})
      register_player(@member_id, @guild_id, {40, 10})

      {:ok, definition} = Catalog.by_id(10_010)
      assert {:ok, _caster} = GdBattleorder.cast(master, :self, 1, definition)

      assert StatusStorage.get_unit_statuses(:player, @member_id) == []
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

  describe "modifier maps" do
    test "regeneration follows the reference rate table" do
      assert Regeneration.modifiers(%StatusEntry{type: :sc_regeneration, val1: 1}, %{}) ==
               %{hp_regen: 200, sp_regen: 100}

      assert Regeneration.modifiers(%StatusEntry{type: :sc_regeneration, val1: 2}, %{}) ==
               %{hp_regen: 200, sp_regen: 200}

      assert Regeneration.modifiers(%StatusEntry{type: :sc_regeneration, val1: 3}, %{}) ==
               %{hp_regen: 300, sp_regen: 300}
    end

    test "emergency move grants +25% movement speed" do
      assert EmergencyMove.modifiers(%StatusEntry{type: :sc_emergency_move}, %{}) ==
               %{movement_speed: -25}
    end
  end
end
