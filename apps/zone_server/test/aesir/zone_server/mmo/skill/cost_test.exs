defmodule Aesir.ZoneServer.Mmo.Skill.CostTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.Skill.Cost
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.SpiritSpheres
  alias Aesir.ZoneServer.Unit.UnitRegistry

  defmodule UnitStub do
    def get_entity_info(_state), do: %{stats: %{}}
  end

  describe "resolve_sp/4" do
    setup :setup_ets_tables

    @char 1_000

    setup do
      :ok = UnitRegistry.register_unit(:player, @char, UnitStub, %{}, self())
    end

    defp sp_state(equipment \\ %{}, passive \\ %{}) do
      %{
        character_id: @char,
        stats: %{
          current_state: %{hp: 100, sp: 100},
          derived_stats: %{max_hp: 100},
          modifiers: %{equipment: equipment, passive: passive}
        }
      }
    end

    # 319 (Whistle) is a performance, so a song; 318 (Frost Joker) is not.
    defp sp_definition(sp, overrides \\ []),
      do: definition([id: 319, sp_cost: [sp]] ++ overrides)

    defp hold(status_id, params \\ []) do
      :ok =
        StatusStorage.apply_status(
          :player,
          @char,
          status_id,
          Keyword.put(params, :duration, 10_000)
        )
    end

    test "the global rate folds status, passive and equipment shares before the flat" do
      hold(:sc_spcost_rate, val1: 10)
      state = sp_state(%{{:skill_use_sp, 319} => 3, sp_cost_rate: -10}, %{sp_cost_rate: -20})

      assert Cost.resolve_sp(state, sp_definition(37), 1) == 19
    end

    test "the global rate floors at zero" do
      hold(:sc_spcost_rate, val1: 150)

      assert Cost.resolve_sp(sp_state(), sp_definition(37), 1) == 0
    end

    test "the per-skill rate applies after the flat, positive is cheaper, and the result floors at zero" do
      assert Cost.resolve_sp(
               sp_state(%{{:skill_use_sp, 319} => 3, {:skill_use_sp_rate, 319} => 50}),
               sp_definition(9),
               1
             ) == 3

      assert Cost.resolve_sp(
               sp_state(%{{:skill_use_sp, 319} => 20, {:skill_use_sp_rate, 319} => 50}),
               sp_definition(9),
               1
             ) == 0

      assert Cost.resolve_sp(sp_state(%{{:skill_use_sp_rate, 999} => 50}), sp_definition(9), 1) ==
               9
    end

    test "a negative flat result times a negative per-skill factor comes back positive" do
      assert Cost.resolve_sp(
               sp_state(%{{:skill_use_sp, 319} => 20, {:skill_use_sp_rate, 319} => 150}),
               sp_definition(9),
               1
             ) == 5
    end

    test "the per-skill rate step caps at 32,767" do
      assert Cost.resolve_sp(
               sp_state(%{{:skill_use_sp_rate, 319} => -20}),
               sp_definition(30_000),
               1
             ) ==
               32_767
    end

    @tag game_mode: :renewal
    test "Adaptation cuts a song by a fifth after the rate and flat steps" do
      hold(:sc_spcost_rate, val1: 10)
      hold(:sc_adaptation)

      state =
        sp_state(%{{:skill_use_sp, 319} => 3, {:skill_use_sp_rate, 319} => 20, sp_cost_rate: -10})

      assert Cost.resolve_sp(state, sp_definition(37), 1) == 16
      assert Cost.resolve_sp(state, sp_definition(99), 1, 37) == 16
      # Frost Joker (318) is not a song: no Adaptation and no per-skill keys.
      assert Cost.resolve_sp(state, sp_definition(37, id: 318), 1) == 29
    end

    @tag game_mode: :renewal
    test "Adaptation rounds down only the discount and precedes Nibelungen" do
      hold(:sc_adaptation)

      assert Cost.resolve_sp(sp_state(), sp_definition(8), 1) == 7
      assert Cost.resolve_sp(sp_state(), sp_definition(5), 1) == 4

      hold(:sc_nibelungen, val1: 5, val2: 9)

      assert Cost.resolve_sp(sp_state(), sp_definition(25), 1) == 14
    end

    @tag game_mode: :pre_renewal
    test "classic Adaptation leaves a song's cost alone" do
      hold(:sc_spcost_rate, val1: 10)
      hold(:sc_adaptation)

      state =
        sp_state(%{{:skill_use_sp, 319} => 3, {:skill_use_sp_rate, 319} => 20, sp_cost_rate: -10})

      assert Cost.resolve_sp(state, sp_definition(37), 1) == 20
    end
  end

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

  test "a positive HP rate is a share of current HP next to the flat HP cost" do
    definition = definition(hp_cost: [5], hp_cost_rate: [20])
    game_state = game_state(50, 40, 0, 100)

    assert %Cost{hp: 15} = Cost.from_definition(game_state, definition, 1)
  end

  test "refuses a cast whose HP-rate cost would reduce HP to zero" do
    definition = definition(hp_cost: [16], hp_cost_rate: [20])
    game_state = game_state(20, 40, 0, 100)
    cost = Cost.from_definition(game_state, definition, 1)

    assert %Cost{hp: 20} = cost
    assert {:error, :insufficient_hp} = Cost.validate(game_state, cost)
  end

  describe "prepare_clamped/2" do
    test "caps every resource at what the caster has instead of failing" do
      game_state = game_state(10, 4, 1)
      cost = %Cost{hp: 25, sp_requirement: 9, sp: 9, spheres: 3}

      commitment = Cost.prepare_clamped(game_state, cost)
      assert %Cost.Commitment{hp: 10, sp: 4, write_spheres?: true} = commitment

      applied = Cost.apply_commitment(game_state, commitment)
      assert applied.stats.current_state == %{hp: 0, sp: 0}
      assert SpiritSpheres.count(applied.spirit_spheres) == 0
    end

    test "spends the affordable amounts in full and leaves untouched spheres unwritten" do
      game_state = game_state(50, 40, 2)
      cost = %Cost{hp: 5, sp_requirement: 0, sp: 12, spheres: 0}

      commitment = Cost.prepare_clamped(game_state, cost)
      assert %Cost.Commitment{hp: 5, sp: 12, write_spheres?: false} = commitment

      assert Cost.apply_commitment(game_state, commitment).stats.current_state == %{
               hp: 45,
               sp: 28
             }
    end
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
