defmodule Aesir.ZoneServer.Mmo.Homunculus.Growth do
  @moduledoc """
  Random Homunculus level-growth and evolution rolls.
  """

  @stats ~w(hp sp str agi vit int dex luk)
  @base_stats ~w(str agi vit int dex luk)

  @type rolls :: %{
          hp: non_neg_integer(),
          sp: non_neg_integer(),
          str: non_neg_integer(),
          agi: non_neg_integer(),
          vit: non_neg_integer(),
          int: non_neg_integer(),
          dex: non_neg_integer(),
          luk: non_neg_integer()
        }
  @type opts :: [roll: (non_neg_integer(), non_neg_integer() -> non_neg_integer())]

  @doc """
  Rolls one independent per-level increase for every canonical stat.

  The six base-stat growth ranges use tenths; their rolled fractional part is
  discarded before applying the increase to Aesir's whole-stat state.
  """
  @spec level(map(), opts()) :: rolls()
  def level(species, opts \\ []) do
    species
    |> roll_ranges(:growth_min, :growth_max, opts)
    |> Map.new(fn
      {stat, value} when stat in @base_stats -> {String.to_existing_atom(stat), div(value, 10)}
      {stat, value} -> {String.to_existing_atom(stat), value}
    end)
  end

  @doc "Rolls one independent evolution bonus for every canonical stat."
  @spec evolution(map(), opts()) :: rolls()
  def evolution(species, opts \\ []) do
    species
    |> roll_ranges(:evolution_min, :evolution_max, opts)
    |> Map.new(fn {stat, value} -> {String.to_existing_atom(stat), value} end)
  end

  defp roll_ranges(species, min_key, max_key, opts) do
    roll = Keyword.get(opts, :roll, &(:rand.uniform(&2 - &1 + 1) + &1 - 1))

    Map.new(@stats, fn stat ->
      range = Map.fetch!(species.stats, stat)
      min = Map.fetch!(range, min_key)
      max = Map.fetch!(range, max_key)
      value = roll.(min, max)

      unless is_integer(value) and value in min..max do
        raise ArgumentError, "growth roll must be within the requested inclusive range"
      end

      {stat, value}
    end)
  end
end
