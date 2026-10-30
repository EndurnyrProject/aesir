defmodule Aesir.ZoneServer.Mmo.Skill.ZenyCostTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter
  alias Aesir.ZoneServer.Mmo.Skill.Passives
  alias Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsUnfairlytrick
  alias Aesir.ZoneServer.Mmo.Skills.Merchant.McMammonite
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Equipment
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.Stats.BaseStats
  alias Aesir.ZoneServer.Unit.Stats.CurrentState
  alias Aesir.ZoneServer.Unit.Stats.DerivedStats

  setup :verify_on_exit!

  setup do
    Mimic.copy(McMammonite)
    :ok
  end

  defp game_state(sp, zeny, learned) do
    stats = %Stats{
      base_stats: %BaseStats{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
      current_state: %CurrentState{sp: sp, hp: 100},
      derived_stats: %DerivedStats{max_sp: 200, max_hp: 100},
      progression: %PlayerProgression{base_level: 1, job_level: 1, learned_skills: learned},
      equipment: %Equipment{}
    }

    %PlayerState{
      character_id: 1000,
      x: 10,
      y: 10,
      map_name: "prontera",
      skill_cooldowns: %{},
      act_delay_until: 0,
      zeny: zeny,
      stats: stats
    }
  end

  defp zeny_definition(zeny_cost) do
    %Definition{
      id: 42,
      name: :mc_mammonite,
      display_name: "Zeny Cost Test",
      max_level: 10,
      target_type: :self,
      damage_type: :no_damage,
      sp_cost: List.duplicate(9, 10),
      zeny_cost: zeny_cost
    }
  end

  test "insufficient zeny fails the cast, spends no SP, and never runs the behavior" do
    stub(Catalog, :by_id, fn 42 -> {:ok, zeny_definition([500])} end)
    reject(&McMammonite.cast/4)

    gs = game_state(100, 400, %{42 => 1})

    assert {:error, :insufficient_zeny} = Interpreter.cast(gs, 42, 1, :self)
  end

  test "without a discount every level deducts its unchanged zeny cost" do
    costs = Enum.map(1..10, &(&1 * 100))
    stub(Catalog, :by_id, fn 42 -> {:ok, zeny_definition(costs)} end)
    stub(McMammonite, :cast, fn caster, :self, _level, _definition -> {:ok, caster} end)

    for level <- 1..10 do
      gs = game_state(100, 2000, %{42 => 10})

      assert {:ok, updated} = Interpreter.cast(gs, 42, level, :self)
      assert updated.zeny == 2000 - level * 100
      assert updated.stats.current_state.sp == 100 - 9
    end
  end

  @tag game_mode: :renewal
  test "Unfair Trick lets a player with exactly 80 zeny pay a 100 zeny skill cost" do
    stub(Catalog, :by_id, fn
      42 -> {:ok, zeny_definition([100])}
      1012 -> {:ok, BsUnfairlytrick.definition()}
    end)

    stub(McMammonite, :cast, fn caster, :self, 1, _definition -> {:ok, caster} end)

    gs = game_state(100, 80, %{42 => 1, 1012 => 1})

    assert {:ok, updated} = Interpreter.cast(gs, 42, 1, :self)
    assert updated.zeny == 0
  end

  @tag game_mode: :pre_renewal
  test "classic Unfair Trick lets a player with exactly 90 zeny pay a 100 zeny skill cost" do
    stub(Catalog, :by_id, fn
      42 -> {:ok, zeny_definition([100])}
      1012 -> {:ok, BsUnfairlytrick.definition()}
    end)

    stub(McMammonite, :cast, fn caster, :self, 1, _definition -> {:ok, caster} end)

    gs = game_state(100, 90, %{42 => 1, 1012 => 1})

    assert {:ok, updated} = Interpreter.cast(gs, 42, 1, :self)
    assert updated.zeny == 0
  end

  test "a summed reduction above 100% floors the cost at zero and never credits zeny" do
    stub(Catalog, :by_id, fn
      42 -> {:ok, zeny_definition([100])}
      1012 -> {:ok, BsUnfairlytrick.definition()}
    end)

    stub(McMammonite, :cast, fn caster, :self, 1, _definition -> {:ok, caster} end)
    stub(Passives, :zeny_cost_reduction, fn _stats -> 150 end)

    gs = game_state(100, 500, %{42 => 1, 1012 => 1})

    assert {:ok, updated} = Interpreter.cast(gs, 42, 1, :self)
    assert updated.zeny == 500
  end

  @tag game_mode: :renewal
  test "Unfair Trick reduces a level 10 cost from 1000 to 800 zeny" do
    stub(Catalog, :by_id, fn
      42 -> {:ok, zeny_definition(Enum.map(1..10, &(&1 * 100)))}
      1012 -> {:ok, BsUnfairlytrick.definition()}
    end)

    stub(McMammonite, :cast, fn caster, :self, 10, _definition -> {:ok, caster} end)

    gs = game_state(100, 800, %{42 => 10, 1012 => 1})

    assert {:ok, updated} = Interpreter.cast(gs, 42, 10, :self)
    assert updated.zeny == 0
  end

  @tag game_mode: :pre_renewal
  test "classic Unfair Trick reduces a level 10 cost from 1000 to 900 zeny" do
    stub(Catalog, :by_id, fn
      42 -> {:ok, zeny_definition(Enum.map(1..10, &(&1 * 100)))}
      1012 -> {:ok, BsUnfairlytrick.definition()}
    end)

    stub(McMammonite, :cast, fn caster, :self, 10, _definition -> {:ok, caster} end)

    gs = game_state(100, 900, %{42 => 10, 1012 => 1})

    assert {:ok, updated} = Interpreter.cast(gs, 42, 10, :self)
    assert updated.zeny == 0
  end

  test "empty zeny_cost deducts no zeny (backward compat)" do
    stub(Catalog, :by_id, fn 42 -> {:ok, zeny_definition([])} end)
    stub(McMammonite, :cast, fn caster, :self, 1, _definition -> {:ok, caster} end)

    gs = game_state(100, 1000, %{42 => 1})

    assert {:ok, updated} = Interpreter.cast(gs, 42, 1, :self)
    assert updated.zeny == 1000
  end
end
