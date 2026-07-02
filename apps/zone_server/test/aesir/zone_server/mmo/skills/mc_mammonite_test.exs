defmodule Aesir.ZoneServer.Mmo.Skills.McMammoniteTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.McMammonite
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.Stats.BaseStats
  alias Aesir.ZoneServer.Unit.Stats.DerivedStats

  setup :verify_on_exit!

  @target_id 2000
  @sword 1101
  @right_hand 2

  defp build_caster do
    stats = %Stats{
      base_stats: %BaseStats{str: 1, agi: 1, vit: 10, int: 10, dex: 1, luk: 1},
      derived_stats: %DerivedStats{max_hp: 1000, max_sp: 100},
      progression: %PlayerProgression{base_level: 1, job_level: 1, learned_skills: %{}},
      equipment:
        Stats.equipment_from_inventory([
          %InventoryItem{nameid: @sword, amount: 1, equip: @right_hand, identify: 1}
        ])
    }

    %PlayerState{character_id: 1000, stats: stats}
  end

  defp definition do
    {:ok, definition} = Catalog.by_name(:mc_mammonite)
    definition
  end

  test "Catalog.active_module_for/1 resolves mc_mammonite" do
    assert {:ok, McMammonite} = Catalog.active_module_for(:mc_mammonite)
  end

  test "Catalog.by_id/1 resolves mc_mammonite with the correct zeny_cost" do
    assert {:ok, definition} = Catalog.by_id(42)
    assert definition.name == :mc_mammonite

    assert definition.zeny_cost == [
             100,
             200,
             300,
             400,
             500,
             600,
             700,
             800,
             900,
             1000
           ]
  end

  test "cast/4 hits the target for 100% + 50% per level at level 1, without crit" do
    caster = build_caster()

    expect(Combat, :execute_skill_attack, fn ^caster, @target_id, opts ->
      assert opts[:skill_id] == definition().id
      assert opts[:skill_level] == 1
      assert opts[:skill_ratio] == 150
      assert opts[:skip_crit] == true
      :ok
    end)

    assert {:ok, ^caster} = McMammonite.cast(caster, {:unit, @target_id}, 1, definition())
  end

  test "cast/4 uses skill_ratio 350 at level 5" do
    caster = build_caster()

    expect(Combat, :execute_skill_attack, fn ^caster, @target_id, opts ->
      assert opts[:skill_ratio] == 350
      :ok
    end)

    assert {:ok, ^caster} = McMammonite.cast(caster, {:unit, @target_id}, 5, definition())
  end

  test "cast/4 uses skill_ratio 600 at level 10" do
    caster = build_caster()

    expect(Combat, :execute_skill_attack, fn ^caster, @target_id, opts ->
      assert opts[:skill_ratio] == 600
      :ok
    end)

    assert {:ok, ^caster} = McMammonite.cast(caster, {:unit, @target_id}, 10, definition())
  end

  test "cast/4 propagates an attack error" do
    caster = build_caster()

    stub(Combat, :execute_skill_attack, fn ^caster, @target_id, _opts ->
      {:error, :target_out_of_range}
    end)

    assert {:error, :target_out_of_range} =
             McMammonite.cast(caster, {:unit, @target_id}, 1, definition())
  end
end
