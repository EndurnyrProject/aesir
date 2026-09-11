defmodule Aesir.ZoneServer.Mmo.Woe.RulesTest do
  use ExUnit.Case, async: false

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.CombatTestHelper
  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.Woe.Rules

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
end
