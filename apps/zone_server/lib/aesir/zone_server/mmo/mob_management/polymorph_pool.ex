defmodule Aesir.ZoneServer.Mmo.MobManagement.PolymorphPool do
  @moduledoc """
  Mode-scoped monster choices for equipment polymorph.

  Each attempt picks an entry uniformly, then rolls its per-million acceptance
  rate. After three attempts per entry the default monster is used. This is
  rejection sampling, not a weighted-total draw.
  """

  alias Aesir.ZoneServer.Mmo.DataLoader
  alias Aesir.ZoneServer.Mmo.MobManagement.Mobs

  @typedoc "A default monster and its candidate IDs with per-million acceptance rates."
  @type pool :: %{default: pos_integer(), entries: [{pos_integer(), non_neg_integer()}]}
  @typedoc "An inclusive uniform draw from 1 through the supplied upper bound."
  @type rng :: (pos_integer() -> pos_integer())

  @doc "Chooses a replacement from the active mode's pool."
  @spec pick(rng()) :: non_neg_integer()
  def pick(rng \\ &:rand.uniform/1), do: choose(index(), rng)

  @doc "Chooses from a supplied pool with the same bounded rejection recipe."
  @spec choose(pool(), rng()) :: non_neg_integer()
  def choose(%{entries: []}, _rng), do: 0

  def choose(%{default: default, entries: entries}, rng) do
    choices = List.to_tuple(entries)
    choose(choices, default, tuple_size(choices) * 3, rng)
  end

  defp choose(_entries, default, 0, _rng) do
    if match?({:ok, _}, Mobs.by_id(default)), do: default, else: 0
  end

  defp choose(entries, default, attempts, rng) do
    {id, rate} = elem(entries, rng.(tuple_size(entries)) - 1)

    if match?({:ok, _}, Mobs.by_id(id)) and (rate >= 1_000_000 or rng.(1_000_000) <= rate),
      do: id,
      else: choose(entries, default, attempts - 1, rng)
  end

  @doc "Reloads the pool after its YAML sources change."
  @spec reload() :: :ok
  def reload do
    :persistent_term.put(__MODULE__, load())
    :ok
  end

  defp index do
    case :persistent_term.get(__MODULE__, nil) do
      nil ->
        pool = load()
        :persistent_term.put(__MODULE__, pool)
        pool

      pool ->
        pool
    end
  end

  defp load do
    DataLoader.load("mob_summon/polymorph.yml", "polymorph_v1.etf", fn sources ->
      {default, entries} =
        sources
        |> Enum.flat_map(&DataLoader.parse_file/1)
        |> Enum.reduce({nil, %{}}, &merge_row/2)

      %{default: default, entries: Enum.sort(entries)}
    end)
  end

  defp merge_row(row, {default, entries}) do
    entries = Enum.reduce(Map.get(row, "entries", []), entries, &put_entry/2)
    {Map.get(row, "default", default), entries}
  end

  defp put_entry(entry, acc) do
    id = Map.fetch!(entry, "id")
    rate = Map.fetch!(entry, "rate")

    if rate == 0, do: Map.delete(acc, id), else: Map.put(acc, id, rate)
  end
end
