defmodule Aesir.ZoneServer.Mmo.Skill.CostTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skill.Cost
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Unit.Player.SpiritSpheres

  test "resolves fixed definition costs" do
    definition = definition(hp_cost: [10], sp_cost: [20], sphere_cost: [2])

    assert %Cost{hp: 10, sp: 20, spheres: 2} =
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

  test "does not allow a cost to reduce HP to zero" do
    assert {:error, :insufficient_hp} = Cost.validate(game_state(10, 40, 3), %Cost{hp: 10})
  end

  test "accepts an all-zero cost" do
    game_state = game_state(10, 0, 0)

    assert {:ok, commitment} = Cost.prepare(game_state, %Cost{})
    assert game_state == Cost.apply_commitment(game_state, commitment)
  end

  test "rejects malformed resolved costs without changing resources" do
    for cost <- [nil, %{}, %Cost{hp: -1}, %Cost{sp: :all}, %Cost{spheres: -1}] do
      assert {:error, :invalid_cost} = Cost.validate_resolved(cost)
    end
  end

  test "empty and all-reserved sphere costs resolve safely" do
    empty = game_state(50, 40, 0)
    assert %Cost{spheres: 0} = Cost.from_definition(empty, definition(sphere_cost: [:all]), 1)

    reserved = game_state(50, 40, 1)
    {:ok, spheres, _entries} = SpiritSpheres.reserve(reserved.spirit_spheres, :operation, 1)
    reserved = %{reserved | spirit_spheres: spheres}

    assert %Cost{spheres: 0} = Cost.from_definition(reserved, definition(sphere_cost: [:all]), 1)

    assert {:error, :insufficient_spirit_spheres} =
             Cost.prepare(reserved, %Cost{spheres: 1})
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
          sp_cost: [],
          sphere_cost: []
        },
        Map.new(overrides)
      )
    )
  end

  defp game_state(hp, sp, spheres) do
    entries =
      Enum.reduce(List.duplicate(:sphere, spheres), SpiritSpheres.new(), fn _, acc ->
        {next, _entry} = SpiritSpheres.summon(acc, 60_000, 5)
        next
      end)

    %{
      stats: %{current_state: %{hp: hp, sp: sp}},
      spirit_spheres: entries
    }
  end
end
