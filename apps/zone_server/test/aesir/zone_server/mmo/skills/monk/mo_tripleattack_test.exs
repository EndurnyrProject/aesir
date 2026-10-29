defmodule Aesir.ZoneServer.Mmo.Skills.Monk.MoTripleattackTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Monk.Formulas
  alias Aesir.ZoneServer.Mmo.Skills.Monk.MoTripleattack
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats

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

  describe "delay/1" do
    test "is 1000 less 4 per AGI and 2 per DEX, never below 0" do
      assert MoTripleattack.delay(stats(50, 40, 0)) == 720
      assert MoTripleattack.delay(stats(200, 200, 0)) == 0
    end

    test "scales by the delay rate in single precision, truncating" do
      # 720 x float32(1 - float32(0.3)) = 503.99999..., not 504.
      assert MoTripleattack.delay(stats(50, 40, -30)) == 503
    end
  end

  defp stats(agi, dex, delay_rate) do
    %PlayerStats{
      base_stats: %{str: 1, agi: agi, vit: 1, int: 1, dex: dex, luk: 1},
      modifiers: %{equipment: %{delay_rate: delay_rate}, status_effects: %{}, job_bonuses: %{}}
    }
  end
end
