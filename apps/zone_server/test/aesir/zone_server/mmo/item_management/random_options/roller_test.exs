defmodule Aesir.ZoneServer.Mmo.ItemManagement.RandomOptions.RollerTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.ItemManagement.RandomOptions.Entry
  alias Aesir.ZoneServer.Mmo.ItemManagement.RandomOptions.Group
  alias Aesir.ZoneServer.Mmo.ItemManagement.RandomOptions.Roller

  # Each roll takes the next scripted value; `{n, v}` also checks the roll's range.
  defp scripted(rolls) do
    {:ok, agent} = Agent.start_link(fn -> rolls end)

    fn range ->
      {expected_range, value} =
        Agent.get_and_update(agent, fn [roll | rest] -> {roll, rest} end)

      assert range == expected_range
      value
    end
  end

  defp entry(id, chance, min \\ 1, max \\ 1, param \\ 0),
    do: %Entry{option_id: id, min: min, max: max, param: param, chance: chance}

  defp group(slots, max_random \\ 0, random \\ []),
    do: %Group{id: 1, name: "G", slots: slots, max_random: max_random, random: random}

  test "a fixed slot picks uniformly until a chance roll passes, then rolls the value inclusively" do
    slot = [entry(3, 2_000, 1, 5, 7), entry(4, 9_000)]

    rng =
      scripted([
        # pick option 3, chance roll 2001 > 2000 fails
        {2, 1},
        {10_000, 2_001},
        # pick option 3 again, 2000 passes, value roll 5 of 1..5
        {2, 1},
        {10_000, 2_000},
        {5, 5}
      ])

    assert Roller.roll(group([slot]), rng) == [%{id: 3, value: 5, param: 7}]
  end

  test "a fixed slot whose size * 3 picks all fail takes one more pick without a chance roll" do
    slot = [entry(3, 1), entry(4, 1)]
    failed = List.duplicate([{2, 1}, {10_000, 2}], 6) |> List.flatten()

    rng = scripted(failed ++ [{2, 2}, {1, 1}])

    assert Roller.roll(group([slot]), rng) == [%{id: 4, value: 1, param: 0}]
  end

  test "random picks fill only the empty positions below MaxRandom, each chance-gated" do
    fixed = [entry(3, 10_000)]
    random = [entry(8, 5_000), entry(9, 5_000)]

    rng =
      scripted([
        # fixed slot 0
        {1, 1},
        {10_000, 1},
        {1, 1},
        # position 1: option 8 fails its chance; position 2: option 9 passes
        {2, 1},
        {10_000, 5_001},
        {2, 2},
        {10_000, 5_000},
        {1, 1}
      ])

    assert Roller.roll(group([fixed], 3, random), rng) == [
             %{id: 3, value: 1, param: 0},
             %{id: 9, value: 1, param: 0}
           ]
  end

  test "positions taken by fixed slots count toward MaxRandom" do
    fixed = [[entry(3, 10_000)], [entry(4, 10_000)]]
    rng = scripted([{1, 1}, {10_000, 1}, {1, 1}, {1, 1}, {10_000, 1}, {1, 1}])

    assert Roller.roll(group(fixed, 2, [entry(8, 10_000)]), rng) == [
             %{id: 3, value: 1, param: 0},
             %{id: 4, value: 1, param: 0}
           ]
  end
end
