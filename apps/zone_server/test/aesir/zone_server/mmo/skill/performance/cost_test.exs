defmodule Aesir.ZoneServer.Mmo.Skill.Performance.CostTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.Skill.Cost
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Performance.Cost, as: BardCost
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.UnitRegistry

  defmodule UnitStub do
    def get_entity_info(_state), do: %{stats: %{}}
  end

  @eligible_ids [317, 319, 320, 321, 322]

  setup :setup_ets_tables

  setup do
    :ok = UnitRegistry.register_unit(:player, 1_000, UnitStub, %{}, self())
  end

  test "Adaptation applies to performances" do
    :ok = apply_status(:sc_adaptation)

    for skill_id <- @eligible_ids do
      assert %Cost{sp: 8} = BardCost.resolve(game_state(%{}), definition(skill_id, 10), 1)
    end
  end

  test "ordinary status, global, per-skill rate, and flat modifiers resolve before Adaptation" do
    :ok = apply_status(:sc_spcost_rate, val1: 10)
    :ok = apply_status(:sc_adaptation)

    assert %Cost{sp_requirement: 16, sp: 16} =
             BardCost.resolve(game_state(), definition(319), 1)
  end

  test "a replacement raw base still receives ordinary modifiers before Adaptation" do
    :ok = apply_status(:sc_spcost_rate, val1: 10)
    :ok = apply_status(:sc_adaptation)

    assert %Cost{sp: 16} = BardCost.resolve(game_state(), definition(319, 99), 1, 37)
  end

  test "Adaptation rounds down only the discount" do
    :ok = apply_status(:sc_adaptation)

    assert %Cost{sp: 7} = BardCost.resolve(game_state(%{}), definition(319, 8), 1)
    assert %Cost{sp: 4} = BardCost.resolve(game_state(%{}), definition(319, 5), 1)
  end

  defp apply_status(status_id, params \\ []) do
    StatusStorage.apply_status(:player, 1_000, status_id, Keyword.put(params, :duration, 10_000))
  end

  defp definition(id, sp \\ 37) do
    %Definition{
      id: id,
      name: :bard_cost_test,
      display_name: "Bard Cost Test",
      max_level: 1,
      sp_cost: [sp]
    }
  end

  defp game_state(
         equipment_modifiers \\ %{
           {:skill_use_sp_rate, 319} => -20,
           {:skill_use_sp, 319} => 3,
           sp_cost_rate: -10
         }
       ) do
    %{
      character_id: 1_000,
      stats: %{
        current_state: %{hp: 100, sp: 100},
        derived_stats: %{max_hp: 100},
        modifiers: %{equipment: equipment_modifiers}
      }
    }
  end
end
