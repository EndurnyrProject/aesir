defmodule Aesir.ZoneServer.Mmo.Skill.CatalystTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter
  alias Aesir.ZoneServer.Mmo.Skills.SmProvoke

  setup :verify_on_exit!

  @gem_id 716

  defp game_state(sp, learned, inventory) do
    %{
      character_id: 1000,
      x: 10,
      y: 10,
      map_name: "prontera",
      skill_cooldowns: %{},
      act_delay_until: 0,
      inventory: inventory,
      pending_inventory_persist: [],
      stats: %{
        base_stats: %{dex: 1, int: 1},
        current_state: %{sp: sp, hp: 100},
        derived_stats: %{max_sp: 200, max_hp: 100},
        progression: %{learned_skills: learned}
      }
    }
  end

  defp gem(amount), do: %InventoryItem{nameid: @gem_id, amount: amount, equip: 0}

  defp catalyst_definition do
    %Definition{
      id: 6,
      name: :sm_provoke,
      display_name: "Catalyst Test",
      max_level: 10,
      target_type: :target_ally,
      damage_type: :no_damage,
      element: :neutral,
      range: 9,
      sp_cost: List.duplicate(9, 10),
      cast_time: [0],
      item_cost: [%{id: @gem_id, amount: 1}]
    }
  end

  test "missing catalyst fails the cast, spends no SP, and never runs the behavior" do
    stub(Catalog, :by_id, fn 6 -> {:ok, catalyst_definition()} end)
    reject(&SmProvoke.cast/4)

    gs = game_state(100, %{6 => 1}, %{})

    assert {:error, :missing_catalyst} = Interpreter.complete_cast(gs, 6, 1, :self)
  end

  test "successful cast consumes the catalyst and records the inventory delta to persist" do
    stub(Catalog, :by_id, fn 6 -> {:ok, catalyst_definition()} end)
    stub(SmProvoke, :cast, fn caster, :self, 1, _definition -> {:ok, caster} end)

    gs = game_state(100, %{6 => 1}, %{0 => gem(3)})

    assert {:ok, updated} = Interpreter.complete_cast(gs, 6, 1, :self)
    assert updated.stats.current_state.sp == 100 - 9
    assert %{0 => %InventoryItem{amount: 2}} = updated.inventory

    assert [{%{}, %{0 => %InventoryItem{amount: 2}}, {:reduced, 0, 2}}] =
             updated.pending_inventory_persist
  end

  test "consumption spills across stacks and stages a delta per stack touched" do
    stub(Catalog, :by_id, fn 6 ->
      {:ok, %{catalyst_definition() | item_cost: [%{id: @gem_id, amount: 4}]}}
    end)

    stub(SmProvoke, :cast, fn caster, :self, 1, _definition -> {:ok, caster} end)

    gs = game_state(100, %{6 => 1}, %{0 => gem(2), 1 => gem(3)})

    assert {:ok, updated} = Interpreter.complete_cast(gs, 6, 1, :self)
    assert updated.inventory == %{1 => %InventoryItem{nameid: @gem_id, amount: 1, equip: 0}}

    assert [
             {%{0 => _, 1 => _}, %{1 => _}, {:removed, 0}},
             {%{1 => _}, %{1 => %InventoryItem{amount: 1}}, {:reduced, 1, 1}}
           ] = updated.pending_inventory_persist
  end

  test ":no_consume result completes the cast but leaves the inventory untouched" do
    stub(Catalog, :by_id, fn 6 -> {:ok, catalyst_definition()} end)
    stub(SmProvoke, :cast, fn caster, :self, 1, _definition -> {:ok, caster, :no_consume} end)

    gs = game_state(100, %{6 => 1}, %{0 => gem(3)})

    assert {:ok, updated} = Interpreter.complete_cast(gs, 6, 1, :self)
    assert updated.stats.current_state.sp == 100 - 9
    assert %{0 => %InventoryItem{amount: 3}} = updated.inventory
    assert updated.pending_inventory_persist == []
  end
end
