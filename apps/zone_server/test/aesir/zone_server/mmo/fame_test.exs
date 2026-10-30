defmodule Aesir.ZoneServer.Mmo.FameTest do
  use ExUnit.Case, async: true

  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.Fame
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemCraft
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression

  test "condensed milestones accumulate 64 points and restart after ten" do
    for product <- 545..547, skill <- [228, 496, 497, 498] do
      assert {0, 64} = successes(0, skill, product, 10)
      assert {0, 128} = successes(0, skill, product, 20)
      assert {3, 1} = successes(2, skill, product, 1)
      assert {5, 3} = successes(4, skill, product, 1)
      assert {7, 10} = successes(6, skill, product, 1)
      assert {0, 50} = successes(9, skill, product, 1)
    end
  end

  test "only reference potion failure paths reset a streak" do
    for skill <- [228, 496, 497, 498, 407, 2025] do
      assert {0, 0} = Fame.potion_result(6, skill, 501, false)
      assert {6, 0} = Fame.potion_result(6, skill, 501, true)
    end

    for skill <- [94, 95, 96, 98, 99, 100, 101, 102, 103, 104] do
      assert {6, 0} = Fame.potion_result(6, skill, 545, false)
      assert {6, 0} = Fame.potion_result(6, skill, 545, true)
    end

    for product <- [544, 548], skill <- [228, 496, 497, 498] do
      assert {6, 0} = Fame.potion_result(6, skill, product, true)
    end
  end

  test "only resolved level-three-or-higher forge additions qualify" do
    for level <- [3, 4] do
      assert Fame.forge_points(level, 3, nil) == 10
      assert Fame.forge_points(level, 3, :neutral) == 10
      assert Fame.forge_points(level, 2, :fire) == 10
      assert Fame.forge_points(level, 2, nil) == 0
      assert Fame.forge_points(level, 2, :neutral) == 0
      assert Fame.forge_points(level, 1, :water) == 0
    end

    for level <- [0, 1, 2], do: assert(Fame.forge_points(level, 3, :wind) == 0)
  end

  test "script refinement requires own forged weapon landing on ten" do
    item = %InventoryItem{craft: ItemCraft.to_map(ItemCraft.forged(:neutral, 0, 7))}
    definition = %ItemDefinition{id: 1, aegis_name: "Sword", name: "Sword", type: :weapon}

    for {level, points} <- [{1, 1}, {2, 25}, {3, 1_000}, {4, 0}, {5, 0}] do
      weapon = %{definition | weapon_level: level}
      assert Fame.refine_points(item, weapon, 7, 10) == points
      assert Fame.refine_points(item, weapon, 8, 10) == 0
      assert Fame.refine_points(item, weapon, 7, 9) == 0
      assert Fame.refine_points(item, weapon, 7, 11) == 0
      assert Fame.refine_points(item, %{weapon | type: :armor}, 7, 10) == 0
      assert Fame.refine_points(%{item | craft: nil}, weapon, 7, 10) == 0
      signed = %{item | craft: ItemCraft.to_map(ItemCraft.signed(7))}
      assert Fame.refine_points(signed, weapon, 7, 10) == 0
    end
  end

  test "award eligibility is separate from streak evolution" do
    for {category, jobs} <- [
          blacksmith: [:blacksmith, :whitesmith, :baby_blacksmith, :mechanic, :meister],
          alchemist: [:alchemist, :creator, :baby_alchemist, :genetic, :biolo]
        ],
        job <- jobs do
      player = player(job)
      assert Fame.category(player.stats.progression.job_id) == category
      assert Fame.award(player, 0) == player
      awarded = Fame.award(player, 3)
      assert awarded.fame == 3

      assert awarded.pending_fame_awards == [
               %{category: category, awarded_points: 3, total_fame: 3}
             ]
    end

    for job <- [:novice, :merchant, :taekwon, :assassin_cross] do
      player = player(job)
      assert Fame.category(player.stats.progression.job_id) == nil
      assert Fame.award(player, 10) == player
      assert {3, 1} = Fame.potion_result(2, 228, 545, true)
    end

    assert Fame.category(-1) == nil
    assert Fame.category(999_999) == nil
  end

  test "capped fame retains the requested award amount" do
    player = %{player(:alchemist) | fame: 999_999_999}
    capped = Fame.award(player, 50)
    assert capped.fame == 1_000_000_000
    capped = Fame.award(capped, 10)
    assert capped.fame == 1_000_000_000

    assert capped.pending_fame_awards == [
             %{category: :alchemist, awarded_points: 50, total_fame: 1_000_000_000},
             %{category: :alchemist, awarded_points: 10, total_fame: 1_000_000_000}
           ]
  end

  test "a new player loads fame but starts a fresh streak" do
    character = %Character{id: 7, name: "Maker", account_id: 1, fame: 123}

    assert %{fame: 123, potion_success_counter: 0, pending_fame_awards: []} =
             PlayerState.new(character)
  end

  defp successes(counter, skill, product, count) do
    Enum.reduce(1..count, {counter, 0}, fn _, {counter, points} ->
      {counter, awarded} = Fame.potion_result(counter, skill, product, true)
      {counter, points + awarded}
    end)
  end

  defp player(job) do
    {:ok, id} = AvailableJobs.job_name_to_id(job)
    %PlayerState{character_id: 7, stats: %Stats{progression: %PlayerProgression{job_id: id}}}
  end
end
