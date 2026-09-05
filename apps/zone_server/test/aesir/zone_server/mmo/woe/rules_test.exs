defmodule Aesir.ZoneServer.Mmo.Woe.RulesTest do
  use ExUnit.Case, async: false

  alias Aesir.Commons.GameMode
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
end
