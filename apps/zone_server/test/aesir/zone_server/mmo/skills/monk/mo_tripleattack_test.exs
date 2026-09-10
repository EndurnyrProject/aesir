defmodule Aesir.ZoneServer.Mmo.Skills.Monk.MoTripleattackTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Monk.Formulas
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

  @tag game_mode: :renewal
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

  @tag game_mode: :pre_renewal
  test "classic rolls 30 minus level percent and still returns the directive" do
    assert Formulas.trifecta_activation_rate(5) == 25

    seeds = Enum.map(1..40, &{&1, &1, &1})

    assert Enum.any?(seeds, fn seed ->
             :rand.seed(:exsss, seed)
             match?({:skill_attack, _opts, :quadruple}, MoTripleattack.attack_replacement(5, %{}))
           end)

    assert Enum.any?(seeds, fn seed ->
             :rand.seed(:exsss, seed)
             MoTripleattack.attack_replacement(5, %{}) == :normal
           end)
  end
end
