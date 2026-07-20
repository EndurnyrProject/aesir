defmodule Aesir.ZoneServer.Mmo.Skills.Thief.TfDoubleTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Thief.TfDouble

  test "Catalog.by_id/1 resolves TF_DOUBLE" do
    assert {:ok, definition} = Catalog.by_id(48)
    assert definition.name == :tf_double
    assert definition.max_level == 10
    assert definition.target_type == :passive
  end

  test "Catalog.passive_module_for/1 resolves tf_double" do
    assert {:ok, TfDouble} = Catalog.passive_module_for(:tf_double)
  end

  test "attack_proc is %{multi_hit: 2, chance: 7 * level} for a dagger" do
    assert TfDouble.attack_proc(5, %{weapon_type: :dagger}) == %{multi_hit: 2, chance: 35}
    assert TfDouble.attack_proc(10, %{weapon_type: :dagger}) == %{multi_hit: 2, chance: 70}
  end

  test "attack_proc is empty for other weapons" do
    assert TfDouble.attack_proc(5, %{weapon_type: :one_handed_sword}) == %{}
    assert TfDouble.attack_proc(5, %{weapon_type: :bow}) == %{}
  end

  test "hit_bonus is level for a dagger" do
    assert TfDouble.hit_bonus(7, %{weapon_type: :dagger}) == 7
  end

  test "hit_bonus is 0 for other weapons" do
    assert TfDouble.hit_bonus(7, %{weapon_type: :bow}) == 0
  end
end
