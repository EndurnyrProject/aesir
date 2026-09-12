defmodule Aesir.ZoneServer.Mmo.Woe.RulesTest do
  use ExUnit.Case, async: false
  use Mimic

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.CombatTestHelper
  alias Aesir.ZoneServer.Guild.Manager, as: GuildManager
  alias Aesir.ZoneServer.Guild.Relations
  alias Aesir.ZoneServer.Guild.State, as: GuildState
  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.Woe.CastleDb
  alias Aesir.ZoneServer.Mmo.Woe.CastleStore
  alias Aesir.ZoneServer.Mmo.Woe.Rules

  setup :set_mimic_private

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})
    :ok = MapFlags.reload()
    :ok
  end

  test "castle ground and active siege are distinct from ordinary PvP" do
    assert Rules.ground?("aldeg_cas01")
    refute Rules.active?("aldeg_cas01")

    :ok = MapFlags.set_runtime("prontera", :gvg, true)
    assert Rules.ground?("prontera")
    assert Rules.active?("prontera")

    refute Rules.ground?("pvp_y_1-2")
    refute Rules.active?("pvp_y_1-2")
  end

  test "ordinary hits retain 80 percent while skills use 60 percent" do
    assert Rules.damage_rate(%{dmg_type: :physical, is_short: true, skill_id: nil}) == 80
    assert Rules.damage_rate(%{dmg_type: :physical, is_short: false, skill_id: nil}) == 80

    for dmg_type <- [:physical, :magic, :misc] do
      assert Rules.damage_rate(%{dmg_type: dmg_type, skill_id: 5}) == 60
    end

    assert Rules.damage_rate(%{
             dmg_type: :physical,
             skill_id: 263,
             from_caster?: true
           }) == 60

    assert Rules.damage_rate(%{
             dmg_type: :physical,
             skill_id: nil,
             basic_attack?: true,
             from_caster?: true
           }) == 80
  end

  test "castle-ground skill restrictions use the boot-selected mode" do
    for skill_id <- [26, 27, 87, 150, 219] do
      refute Rules.skill_allowed?(skill_id, "aldeg_cas01")
    end

    assert Rules.skill_allowed?(1013, "aldeg_cas01") == (GameMode.mode() == :renewal)
    assert Rules.skill_allowed?(5, "aldeg_cas01")
    assert Rules.skill_allowed?(26, "prontera")
    assert Rules.skill_allowed?(1013, "prontera")
  end

  test "castle-ground item and status restrictions hold while siege is inactive" do
    refute Rules.item_allowed?(14_529, "aldeg_cas01")

    assert Rules.item_allowed?(605, "aldeg_cas01") ==
             (GameMode.mode() == :pre_renewal)

    refute Rules.status_allowed?(:sc_endure, "aldeg_cas01")
    assert Rules.item_allowed?(501, "aldeg_cas01")
    assert Rules.status_allowed?(:sc_blessing, "aldeg_cas01")
    assert Rules.item_allowed?(14_529, "prontera")
    assert Rules.item_allowed?(605, "prontera")
    assert Rules.status_allowed?(:sc_endure, "prontera")
  end

  describe "owner-aware hostility for guild-owned mobs" do
    test "a hit on a guild-owned mob outside active siege is rejected regardless of skill" do
      :ok = MapFlags.set_runtime("aldeg_cas01", :gvg, false)

      target = guardian_combatant(guild_id: 7)

      assert Rules.validate_target(player_combatant(guild_id: 8), target, %{skill_id: nil}) ==
               {:error, :siege_inactive}

      assert Rules.validate_target(player_combatant(guild_id: 8), target, %{skill_id: 5}) ==
               {:error, :siege_inactive}
    end

    test "a same-guild hit on a guild-owned mob is rejected during active siege regardless of skill" do
      :ok = MapFlags.set_runtime("aldeg_cas01", :gvg, true)

      attacker = player_combatant(guild_id: 7)
      target = guardian_combatant(guild_id: 7)

      assert Rules.validate_target(attacker, target, %{skill_id: nil}) == {:error, :owner_guild}
      assert Rules.validate_target(attacker, target, %{skill_id: 5}) == {:error, :owner_guild}
    end

    test "a different-guild or guildless hit on a guild-owned mob is allowed during active siege" do
      :ok = MapFlags.set_runtime("aldeg_cas01", :gvg, true)

      target = guardian_combatant(guild_id: 7)

      for guild_id <- [8, 0], skill_id <- [nil, 5] do
        attacker = player_combatant(guild_id: guild_id)
        assert Rules.validate_target(attacker, target, %{skill_id: skill_id}) == :ok
      end
    end

    test "a guild-owned mob attacking its own guild's player is rejected" do
      attacker = guardian_combatant(guild_id: 7)
      target = player_combatant(guild_id: 7)

      assert Rules.validate_target(attacker, target, %{skill_id: nil}) == {:error, :owner_guild}
    end

    test "a guild-owned mob attacking a different guild's player is allowed" do
      attacker = guardian_combatant(guild_id: 7)
      target = player_combatant(guild_id: 8)

      assert Rules.validate_target(attacker, target, %{skill_id: nil}) == :ok
    end
  end

  describe "allied guilds are friendly on the hostility seam" do
    setup do
      :ok = CastleDb.reload()
      :ok = CastleStore.init()
      {:ok, castle} = CastleDb.by_map("aldeg_cas01")

      :ok = MapFlags.set_runtime(castle.map, :gvg, true)
      :ok = CastleStore.set_siege(castle.id, true)
      :ok = CastleStore.set_emperium(castle.id, 20_001)
      :ok = CastleStore.hydrate(%{castle.id => castle_owner_row(7)})

      %{castle: castle}
    end

    test "an attacker allied to the castle owner is refused against the live Emperium", %{
      castle: castle
    } do
      stub(Relations, :friendly?, fn 7, 9 -> true end)
      stub(GuildManager, :get, fn 9 -> {:ok, guild_state(9)} end)

      attacker = player_combatant(guild_id: 9)
      target = emperium_combatant(castle)

      assert Rules.validate_target(attacker, target, %{skill_id: nil}) == {:error, :owner_guild}
    end

    test "an attacker allied to the castle owner is refused against a guardian" do
      stub(Relations, :friendly?, fn 7, 9 -> true end)

      attacker = player_combatant(guild_id: 9)
      target = guardian_combatant(guild_id: 7)

      assert Rules.validate_target(attacker, target, %{skill_id: nil}) == {:error, :owner_guild}
    end

    test "a guardian is refused against a player allied to its guild" do
      stub(Relations, :friendly?, fn 7, 9 -> true end)

      attacker = guardian_combatant(guild_id: 7)
      target = player_combatant(guild_id: 9)

      assert Rules.validate_target(attacker, target, %{skill_id: nil}) == {:error, :owner_guild}
    end
  end

  defp player_combatant(guild_id: guild_id) do
    CombatTestHelper.create_player_combatant(unit_id: 10_001, map_name: "aldeg_cas01")
    |> Map.merge(%{
      guild_id: guild_id,
      social_root: {:player, 10_001},
      reward_root: {:player, 10_001}
    })
  end

  defp guardian_combatant(guild_id: guild_id) do
    CombatTestHelper.create_mob_combatant(
      unit_id: 20_101,
      monster_id: 1286,
      map_name: "aldeg_cas01"
    )
    |> Map.merge(%{guild_id: guild_id, social_root: {:mob, 20_101}, reward_root: nil})
  end

  defp emperium_combatant(castle) do
    CombatTestHelper.create_mob_combatant(
      unit_id: 20_001,
      monster_id: 1288,
      map_name: castle.map
    )
    |> Map.merge(%{social_root: {:mob, 20_001}, reward_root: nil})
  end

  defp castle_owner_row(guild_id) do
    %{guild_id: guild_id, economy: 0, defense: 0, invested_economy: 0, invested_defense: 0}
  end

  defp guild_state(guild_id) do
    %GuildState{
      guild_id: guild_id,
      name: "Guild #{guild_id}",
      master_char_id: guild_id,
      learned_skills: %{10_000 => 1}
    }
  end
end
