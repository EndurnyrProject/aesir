defmodule Aesir.ZoneServer.Mmo.Skill.CostTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skill.Cost
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Unit.Player.SpiritSpheres

  test "resolves fixed definition costs" do
    definition = definition(hp_cost: [10], sp_cost: [20], sphere_cost: [2])

    assert %Cost{hp: 10, sp_requirement: 20, sp: 20, spheres: 2} =
             Cost.from_definition(game_state(50, 40, 3), definition, 1)
  end

  test "resolves all SP and available spheres from current state" do
    definition = definition(sp_cost: [:all], sphere_cost: [:all])

    assert %Cost{hp: 0, sp: 40, spheres: 3} =
             Cost.from_definition(game_state(50, 40, 3), definition, 1)
  end

  test "prepares and applies all resolved resources together" do
    definition = definition(hp_cost: [10], sp_cost: [:all], sphere_cost: [:all])
    game_state = game_state(50, 40, 3)
    cost = Cost.from_definition(game_state, definition, 1)

    assert :ok = Cost.validate(game_state, cost)
    assert {:ok, commitment} = Cost.prepare(game_state, cost)
    committed = Cost.apply_commitment(game_state, commitment)
    assert committed.stats.current_state.hp == 40
    assert committed.stats.current_state.sp == 0
    assert SpiritSpheres.count(committed.spirit_spheres) == 0
  end

  test "requires more SP than it consumes without committing the requirement" do
    game_state = game_state(50, 40, 0)
    cost = %Cost{sp_requirement: 40, sp: 10}

    assert {:ok, commitment} = Cost.prepare(game_state, cost)
    assert Cost.apply_commitment(game_state, commitment).stats.current_state.sp == 30
    assert {:error, :insufficient_sp} = Cost.prepare(game_state(50, 39, 0), cost)
  end

  test "requires enough SP for consumption when consumption exceeds the requirement" do
    cost = %Cost{sp_requirement: 10, sp: 40}

    assert {:ok, _commitment} = Cost.prepare(game_state(50, 40, 0), cost)
    assert {:error, :insufficient_sp} = Cost.prepare(game_state(50, 39, 0), cost)
  end

  test "defaults the requirement to consumption for direct costs" do
    cost = %Cost{sp: 20}

    assert {:ok, %Cost{sp_requirement: 20}} = Cost.validate_resolved(cost)
    assert {:error, :insufficient_sp} = Cost.prepare(game_state(50, 19, 0), cost)
  end

  test "rejects nil consumption before defaulting its requirement" do
    assert {:error, :invalid_cost} = Cost.validate_resolved(%Cost{sp: nil})
  end

  test "allows a positive requirement with zero consumption" do
    game_state = game_state(50, 10, 0)

    assert {:ok, commitment} = Cost.prepare(game_state, %Cost{sp_requirement: 10, sp: 0})
    assert Cost.apply_commitment(game_state, commitment).stats.current_state.sp == 10
  end

  test "does not allow a cost to reduce HP to zero" do
    assert {:error, :insufficient_hp} =
             Cost.validate(game_state(10, 40, 3), %Cost{hp: 10, sp_requirement: 0})
  end

  test "resolves a percent-max-HP cost next to the flat HP cost" do
    definition = definition(hp_cost: [5], hp_cost_rate: [20])
    game_state = game_state(50, 40, 0, 100)

    assert %Cost{hp: 25} = Cost.from_definition(game_state, definition, 1)
  end

  test "refuses a cast whose HP-rate cost would reduce HP to zero" do
    definition = definition(hp_cost_rate: [20])
    game_state = game_state(20, 40, 0, 100)
    cost = Cost.from_definition(game_state, definition, 1)

    assert {:error, :insufficient_hp} = Cost.validate(game_state, cost)
  end

  test "accepts an all-zero cost" do
    game_state = game_state(10, 0, 0)

    assert {:ok, commitment} = Cost.prepare(game_state, %Cost{})
    assert game_state == Cost.apply_commitment(game_state, commitment)
  end

  test "rejects malformed resolved costs without changing resources" do
    for cost <- [
          nil,
          %{},
          %Cost{hp: -1},
          %Cost{sp_requirement: -1},
          %Cost{sp_requirement: :all},
          %Cost{sp: :all},
          %Cost{spheres: -1}
        ] do
      assert {:error, :invalid_cost} = Cost.validate_resolved(cost)
    end
  end

  test "empty sphere costs resolve safely" do
    empty = game_state(50, 40, 0)
    assert %Cost{spheres: 0} = Cost.from_definition(empty, definition(sphere_cost: [:all]), 1)
  end

  defp definition(overrides) do
    struct!(
      Definition,
      Map.merge(
        %{
          id: 1,
          name: :test_skill,
          display_name: "Test Skill",
          max_level: 1,
          hp_cost: [],
          hp_cost_rate: [],
          sp_cost: [],
          sphere_cost: []
        },
        Map.new(overrides)
      )
    )
  end

  defp game_state(hp, sp, spheres, max_hp \\ 0) do
    entries =
      Enum.reduce(List.duplicate(:sphere, spheres), SpiritSpheres.new(), fn _, acc ->
        {next, _entry} = SpiritSpheres.summon(acc, 60_000, 5)
        next
      end)

    %{
      stats: %{current_state: %{hp: hp, sp: sp}, derived_stats: %{max_hp: max_hp}},
      spirit_spheres: entries
    }
  end
end
