defmodule Aesir.ZoneServer.Mmo.Skills.Monk.MoTripleattackTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Monk.Formulas
  alias Aesir.ZoneServer.Mmo.Skills.Monk.MoTripleattack
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats

  setup :setup_ets_tables

  setup do
    Catalog.reload()
    :ok
  end

  @tag game_mode: :renewal
  test "the Renewal thirty-percent roll returns the complete replacement directive" do
    :rand.seed(:exsss, {1, 2, 3})

    assert {:skill_attack, opts, :quadruple} = MoTripleattack.attack_replacement(5, %{})
    assert opts[:skill_id] == 263
    assert opts[:skill_level] == 5
    assert opts[:skill_ratio] == 200
    assert opts[:hit_divisions] == -3
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

  test "a proc's delay has a 1000 ms base and ignores Bragi" do
    stats = %PlayerStats{
      base_stats: %{str: 1, agi: 50, vit: 1, int: 1, dex: 40, luk: 1},
      modifiers: %{equipment: %{}, status_effects: %{}, job_bonuses: %{}}
    }

    caster = %PlayerState{character_id: 7_263, stats: stats}
    :ok = StatusStorage.apply_status(:player, 7_263, :sc_poembragi, state: %{delay_reduction: 50})

    assert MoTripleattack.delay(caster, 10) == 720
  end
end
