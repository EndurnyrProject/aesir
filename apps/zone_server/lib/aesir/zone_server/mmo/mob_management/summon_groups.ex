defmodule Aesir.ZoneServer.Mmo.MobManagement.SummonGroups do
  @moduledoc """
  Mode-scoped random monster groups (the `MOBG_*` pools): the Dead Branch, the
  Poring Box, the equipment polymorph pool and the like.

  A pick draws an entry uniformly, then rolls its per-million acceptance rate;
  a monster that does not exist or is a clone is skipped. After three attempts
  per entry the group's default monster is used. This is rejection sampling,
  not a weighted-total draw. The monster level cap is not applied (the
  reference's `random_monster_checklv` ships off).
  """

  alias Aesir.ZoneServer.Mmo.DataLoader
  alias Aesir.ZoneServer.Mmo.MobManagement.Mobs

  @typedoc "A default monster and its candidate IDs with per-million acceptance rates."
  @type pool :: %{default: pos_integer(), entries: [{pos_integer(), non_neg_integer()}]}
  @typedoc "An inclusive uniform draw from 1 through the supplied upper bound."
  @type rng :: (pos_integer() -> pos_integer())

  # The `MOBG_*` order: a negative monster id `-1 - type` selects the group at
  # index `type`.
  @groups ~w(branch_of_dead_tree poring_box bloody_dead_branch red_pouch_of_surprise
             classchange taekwon_mission)

  @clone_ids 3_999..20_020

  @doc """
  Picks a monster of group `type` (the `MOBG_*` index: the monster id `-1 - type`
  of a script's monster command), or `0` when the group is unknown or empty.
  """
  @spec pick(non_neg_integer(), rng()) :: non_neg_integer()
  def pick(type, rng \\ &:rand.uniform/1)

  def pick(type, rng) when type in 0..5 do
    case Map.fetch(index(), Enum.at(@groups, type)) do
      {:ok, pool} -> choose(pool, rng)
      :error -> 0
    end
  end

  def pick(_type, _rng), do: 0

  @doc "Chooses from a supplied pool with the bounded rejection recipe."
  @spec choose(pool(), rng()) :: non_neg_integer()
  def choose(%{entries: []}, _rng), do: 0

  def choose(%{default: default, entries: entries}, rng) do
    choices = List.to_tuple(entries)
    choose(choices, default, tuple_size(choices) * 3, rng)
  end

  defp choose(_entries, default, 0, _rng) do
    if valid?(default), do: default, else: 0
  end

  defp choose(entries, default, attempts, rng) do
    {id, rate} = elem(entries, rng.(tuple_size(entries)) - 1)

    if valid?(id) and (rate >= 1_000_000 or rng.(1_000_000) <= rate),
      do: id,
      else: choose(entries, default, attempts - 1, rng)
  end

  defp valid?(id), do: id not in @clone_ids and match?({:ok, _}, Mobs.by_id(id))

  @doc "Reloads the groups after their YAML sources change."
  @spec reload() :: :ok
  def reload do
    :persistent_term.put(__MODULE__, load())
    :ok
  end

  defp index do
    case :persistent_term.get(__MODULE__, nil) do
      nil ->
        groups = load()
        :persistent_term.put(__MODULE__, groups)
        groups

      groups ->
        groups
    end
  end

  defp load do
    DataLoader.load("mob_summon/groups.yml", "summon_groups_v1.etf", fn sources ->
      sources
      |> Enum.flat_map(&DataLoader.parse_file/1)
      |> Enum.reduce(%{}, &merge_row/2)
      |> Map.new(fn {name, {default, entries}} ->
        {name, %{default: default, entries: Enum.sort(entries)}}
      end)
    end)
  end

  defp merge_row(row, groups) do
    {default, entries} = Map.get(groups, row["group"], {nil, %{}})
    entries = Enum.reduce(Map.get(row, "entries", []), entries, &put_entry/2)
    Map.put(groups, row["group"], {Map.get(row, "default", default), entries})
  end

  defp put_entry(entry, acc) do
    id = Map.fetch!(entry, "id")
    rate = Map.fetch!(entry, "rate")

    if rate == 0, do: Map.delete(acc, id), else: Map.put(acc, id, rate)
  end
end
