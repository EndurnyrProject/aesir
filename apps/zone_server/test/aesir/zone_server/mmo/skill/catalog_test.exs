defmodule Aesir.ZoneServer.Mmo.Skill.CatalogTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skills.Swordsman.SmBash
  alias Aesir.ZoneServer.Mmo.Skills.Swordsman.SmFatalblow
  alias Aesir.ZoneServer.Mmo.Skills.Swordsman.SmSword
  alias Aesir.ZoneServer.Mmo.Skills.Wizard.WzEarthspike
  alias Aesir.ZoneServer.Mmo.Skills.Wizard.WzFirepillar
  alias Aesir.ZoneServer.Mmo.Skills.Wizard.WzFrostnova
  alias Aesir.ZoneServer.Mmo.Skills.Wizard.WzHeavendrive
  alias Aesir.ZoneServer.Mmo.Skills.Wizard.WzJupitel
  alias Aesir.ZoneServer.Mmo.Skills.Wizard.WzMeteor
  alias Aesir.ZoneServer.Mmo.Skills.Wizard.WzQuagmire
  alias Aesir.ZoneServer.Mmo.Skills.Wizard.WzSightrasher
  alias Aesir.ZoneServer.Mmo.Skills.Wizard.WzStormgust
  alias Aesir.ZoneServer.Mmo.Skills.Wizard.WzVermilion

  test "by_id/1 loads AL_INCAGI with correct structure" do
    assert {:ok, %Definition{} = def} = Catalog.by_id(29)
    assert def.name == :al_incagi
    assert def.max_level == 10
    assert def.target_type == :target_ally
    assert length(def.sp_cost) == def.max_level
    assert length(def.duration) == def.max_level
  end

  test "by_name/1 finds the same record" do
    assert {:ok, %Definition{id: 29}} = Catalog.by_name(:al_incagi)
  end

  test "by_id/1 returns :error for an unknown skill" do
    assert :error = Catalog.by_id(999_999)
  end

  test "reload/0 rebuilds the requirement index" do
    assert :ok = Catalog.reload()
    assert {:ok, [:player_state]} = Catalog.requirements_for(29)
    assert :error = Catalog.requirements_for(999_999)
  end

  test "by_id/1 loads AL_DP as a passive skill" do
    assert {:ok, %Definition{} = defn} = Catalog.by_id(22)
    assert defn.name == :al_dp
    assert defn.target_type == :passive
    assert defn.max_level == 10
  end

  test "by_id/1 loads AL_DEMONBANE as a passive skill" do
    assert {:ok, %Definition{} = defn} = Catalog.by_id(23)
    assert defn.name == :al_demonbane
    assert defn.target_type == :passive
    assert defn.max_level == 10
  end

  test "by_name/1 resolves AL_DP and AL_DEMONBANE" do
    assert {:ok, %Definition{id: 22}} = Catalog.by_name(:al_dp)
    assert {:ok, %Definition{id: 23}} = Catalog.by_name(:al_demonbane)
  end

  test "by_id/1 loads SM_PROVOKE with correct target and damage type" do
    assert {:ok, %Definition{} = defn} = Catalog.by_id(6)
    assert defn.name == :sm_provoke
    assert defn.target_type == :target_enemy
    assert defn.damage_type == :no_damage
    assert defn.max_level == 10
    assert length(defn.sp_cost) == defn.max_level
    assert length(defn.duration) == defn.max_level
  end

  test "by_id/1 loads SM_MAGNUM with correct target, damage type and cooldown" do
    assert {:ok, %Definition{} = defn} = Catalog.by_id(7)
    assert defn.name == :sm_magnum
    assert defn.target_type == :self
    assert defn.damage_type == :damage
    assert defn.max_level == 10
    assert defn.cooldown == List.duplicate(2000, defn.max_level)
  end

  test "by_id/1 loads SM_ENDURE with correct target and damage type" do
    assert {:ok, %Definition{} = defn} = Catalog.by_id(8)
    assert defn.name == :sm_endure
    assert defn.target_type == :self
    assert defn.damage_type == :no_damage
    assert defn.max_level == 10
    assert length(defn.sp_cost) == defn.max_level
    assert length(defn.duration) == defn.max_level
  end

  test "by_id/1 loads SM_AUTOBERSERK with correct target, damage type and max_level" do
    assert {:ok, %Definition{} = defn} = Catalog.by_id(146)
    assert defn.name == :sm_autoberserk
    assert defn.target_type == :self
    assert defn.damage_type == :no_damage
    assert defn.max_level == 1
  end

  describe "granted status (skill_get_sc)" do
    test "a self-buff skill exposes the SC it grants" do
      assert {:ok, %Definition{status: :sc_endure}} = Catalog.by_id(8)
      assert {:ok, %Definition{status: :sc_autoberserk}} = Catalog.by_name(:sm_autoberserk)
      assert {:ok, %Definition{status: :sc_increaseagi}} = Catalog.by_name(:al_incagi)
    end

    test "a skill that grants no status has a nil status" do
      assert {:ok, %Definition{status: nil}} = Catalog.by_name(:sm_bash)
    end

    test "status defaults to nil when the definition omits it" do
      assert %Definition{status: nil} =
               Definition.build!([id: 1, name: :x, display_name: "X", max_level: 1], __MODULE__)
    end
  end

  describe "capability indexes" do
    test "active_module_for/1 resolves an active skill" do
      assert {:ok, SmBash} = Catalog.active_module_for(:sm_bash)
    end

    test "ground_module_for/1 resolves a ground skill" do
      assert {:ok, WzStormgust} = Catalog.ground_module_for(:wz_stormgust)
    end

    test "a ground skill is also active, since its cast is auto-derived" do
      assert {:ok, WzStormgust} = Catalog.active_module_for(:wz_stormgust)
    end

    test "passive_module_for/1 resolves a passive skill" do
      assert {:ok, SmSword} = Catalog.passive_module_for(:sm_sword)
    end

    test "an active skill is absent from the passive index" do
      assert :error = Catalog.passive_module_for(:sm_bash)
    end

    test "a passive skill is absent from the active index" do
      assert :error = Catalog.active_module_for(:sm_sword)
    end

    test "passive_modules/0 lists every passive-capable module and excludes active-only skills" do
      modules = Catalog.passive_modules()

      assert SmSword in modules
      assert SmFatalblow in modules
      refute SmBash in modules
    end
  end

  describe "sp_cost_at/2" do
    test "reads the cost directly for a level within the defined range" do
      assert Catalog.sp_cost_at([12, 14, 16, 18, 20, 22, 24, 26, 28, 30], 10) == 30
      assert Catalog.sp_cost_at([12, 14, 16, 18, 20, 22, 24, 26, 28, 30], 1) == 12
    end

    test "extrapolates the linear trend past the defined range for high mob levels" do
      # Fire Bolt's list (last three 26, 28, 30) at level 48: 30 + 39 + 38 = 107.
      firebolt = [12, 14, 16, 18, 20, 22, 24, 26, 28, 30]
      assert Catalog.sp_cost_at(firebolt, 48) == 107

      # A decreasing table extrapolates downward from its last three entries.
      # Frost Diver (last three 18, 17, 16) at level 13: 16 + div(4*-1,2) +
      # div(3*-1,2) = 16 - 2 - 1 = 13.
      frostdiver = [25, 24, 23, 22, 21, 20, 19, 18, 17, 16]
      assert Catalog.sp_cost_at(frostdiver, 13) == 13
    end

    test "clamps to the last value when the list is too short to project a trend" do
      assert Catalog.sp_cost_at([10], 5) == 10
      assert Catalog.sp_cost_at([10, 12], 5) == 12
    end

    test "an :all-priced level resolves to 0 rather than crashing" do
      assert Catalog.sp_cost_at([:all], 1) == 0
    end
  end

  describe "core Wizard skills" do
    test "reload/0 registers staged skills by id, name, and active or ground capability" do
      assert :ok = Catalog.reload()

      for {id, name, module, capability} <- [
            {80, :wz_firepillar, WzFirepillar, :ground},
            {81, :wz_sightrasher, WzSightrasher, :active},
            {84, :wz_jupitel, WzJupitel, :active},
            {83, :wz_meteor, WzMeteor, :ground},
            {85, :wz_vermilion, WzVermilion, :ground},
            {88, :wz_frostnova, WzFrostnova, :active},
            {90, :wz_earthspike, WzEarthspike, :active},
            {91, :wz_heavendrive, WzHeavendrive, :active},
            {92, :wz_quagmire, WzQuagmire, :ground}
          ] do
        assert {:ok, %Definition{id: ^id, name: ^name}} = Catalog.by_id(id)
        assert {:ok, %Definition{id: ^id, name: ^name}} = Catalog.by_name(name)
        assert {:ok, ^module} = Catalog.active_module_for(name)

        if capability == :ground do
          assert {:ok, ^module} = Catalog.ground_module_for(name)
        else
          assert :error = Catalog.ground_module_for(name)
        end
      end
    end
  end
end
