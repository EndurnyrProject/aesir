defmodule Aesir.ZoneServer.Mmo.ItemManagement.RandomOptions.Roller do
  @moduledoc """
  Rolls an item's random options from a random option group, as the
  reference's group apply does.

  The item's options start empty. Fixed slot `i` picks one of its candidates
  uniformly, applying it when a chance roll out of 10,000 passes, up to three
  times the candidate count; when every pick fails, one more uniform pick
  applies without a chance roll. Then each position below `max_random` (at
  most five) that is still empty takes one uniform pick from the random list,
  applied only when its chance roll passes; positions the fixed slots took
  count toward `max_random`. An applied option takes a value rolled inclusively
  in its range and the entry's parameter. Empty positions left by failed random
  picks are closed up so the filled slots are contiguous.
  """

  alias Aesir.Commons.Models.ItemOptions
  alias Aesir.ZoneServer.Mmo.ItemManagement.RandomOptions.Entry
  alias Aesir.ZoneServer.Mmo.ItemManagement.RandomOptions.Group

  @typedoc "A uniform roll in `1..n`: a module with `uniform/1` or a function."
  @type rng() :: module() | (pos_integer() -> pos_integer())

  @chance_base 10_000

  @doc "Rolls the options an item gets from `group`."
  @spec roll(Group.t(), rng()) :: ItemOptions.t()
  def roll(%Group{} = group, rng \\ :rand) do
    fixed = Enum.map(group.slots, &roll_slot(&1, rng))

    fixed
    |> pad()
    |> roll_random(group, rng)
    |> Enum.reject(&is_nil/1)
  end

  defp roll_slot(candidates, rng) do
    Enum.find_value(1..(length(candidates) * 3), fn _attempt ->
      candidate = pick(candidates, rng)
      if chance?(candidate, rng), do: apply_entry(candidate, rng)
    end) || apply_entry(pick(candidates, rng), rng)
  end

  defp roll_random(slots, %Group{max_random: max_random, random: random}, rng) do
    slots
    |> Enum.with_index()
    |> Enum.map(fn
      {nil, position} when position < max_random ->
        candidate = pick(random, rng)
        if chance?(candidate, rng), do: apply_entry(candidate, rng)

      {slot, _position} ->
        slot
    end)
  end

  defp pad(slots), do: slots ++ List.duplicate(nil, ItemOptions.max_options() - length(slots))

  defp pick(candidates, rng), do: Enum.at(candidates, uniform(rng, length(candidates)) - 1)

  defp chance?(%Entry{chance: chance}, rng), do: uniform(rng, @chance_base) <= chance

  defp apply_entry(%Entry{} = entry, rng) do
    %{
      id: entry.option_id,
      value: entry.min + uniform(rng, entry.max - entry.min + 1) - 1,
      param: entry.param
    }
  end

  defp uniform(rng, n) when is_function(rng, 1), do: rng.(n)
  defp uniform(rng, n) when is_atom(rng), do: rng.uniform(n)
end
