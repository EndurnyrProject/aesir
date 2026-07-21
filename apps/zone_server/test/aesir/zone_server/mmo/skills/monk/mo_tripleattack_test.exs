defmodule Aesir.ZoneServer.Mmo.Skills.Monk.MoTripleattackTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Monk.MoTripleattack

  setup do
    Catalog.reload()
    :ok
  end

  test "catalog exposes the verified passive definition" do
    assert {:ok, definition} = Catalog.by_id(263)
    assert definition.name == :mo_tripleattack
    assert definition.max_level == 10
    assert definition.target_type == :passive
  end

  test "the Renewal thirty-percent roll returns the complete replacement directive" do
    :rand.seed(:exsss, {1, 2, 3})

    assert {:skill_attack, opts, :quadruple} = MoTripleattack.attack_replacement(5, %{})
    assert opts[:skill_id] == 263
    assert opts[:skill_level] == 5
    assert opts[:skill_ratio] == 200
    assert opts[:display_hit_count] == 3
    assert opts[:skip_crit]
  end

  test "a failed roll preserves the normal attack" do
    :rand.seed(:exsss, {6, 7, 8})
    assert :normal = MoTripleattack.attack_replacement(5, %{})
  end
end
