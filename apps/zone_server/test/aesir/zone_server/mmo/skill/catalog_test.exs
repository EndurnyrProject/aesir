defmodule Aesir.ZoneServer.Mmo.Skill.CatalogTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Definition

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
end
