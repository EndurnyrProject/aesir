defmodule Aesir.ZoneServer.Mmo.Skill.ZenyCostTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter
  alias Aesir.ZoneServer.Mmo.Skills.Swordsman.SmProvoke

  setup :verify_on_exit!

  defp game_state(sp, zeny, learned) do
    %{
      character_id: 1000,
      x: 10,
      y: 10,
      map_name: "prontera",
      skill_cooldowns: %{},
      act_delay_until: 0,
      zeny: zeny,
      stats: %{
        base_stats: %{dex: 1, int: 1},
        current_state: %{sp: sp, hp: 100},
        derived_stats: %{max_sp: 200, max_hp: 100},
        progression: %{learned_skills: learned}
      }
    }
  end

  defp zeny_definition(zeny_cost) do
    %Definition{
      id: 6,
      name: :sm_provoke,
      display_name: "Zeny Cost Test",
      max_level: 10,
      target_type: :self,
      damage_type: :no_damage,
      sp_cost: List.duplicate(9, 10),
      zeny_cost: zeny_cost
    }
  end

  test "insufficient zeny fails the cast, spends no SP, and never runs the behavior" do
    stub(Catalog, :by_id, fn 6 -> {:ok, zeny_definition([500])} end)
    reject(&SmProvoke.cast/4)

    gs = game_state(100, 400, %{6 => 1})

    assert {:error, :insufficient_zeny} = Interpreter.cast(gs, 6, 1, :self)
  end

  test "sufficient zeny succeeds and deducts the per-level zeny cost" do
    stub(Catalog, :by_id, fn 6 -> {:ok, zeny_definition([500])} end)
    stub(SmProvoke, :cast, fn caster, :self, 1, _definition -> {:ok, caster} end)

    gs = game_state(100, 1000, %{6 => 1})

    assert {:ok, updated} = Interpreter.cast(gs, 6, 1, :self)
    assert updated.zeny == 500
    assert updated.stats.current_state.sp == 100 - 9
  end

  test "empty zeny_cost deducts no zeny (backward compat)" do
    stub(Catalog, :by_id, fn 6 -> {:ok, zeny_definition([])} end)
    stub(SmProvoke, :cast, fn caster, :self, 1, _definition -> {:ok, caster} end)

    gs = game_state(100, 1000, %{6 => 1})

    assert {:ok, updated} = Interpreter.cast(gs, 6, 1, :self)
    assert updated.zeny == 1000
  end
end
