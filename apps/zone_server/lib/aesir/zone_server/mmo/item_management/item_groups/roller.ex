defmodule Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups.Roller do
  @moduledoc """
  Selects concrete grants from item-group catalog entries.

  A requested `:all` subgroup is sampled like a random subgroup so `roll_n/4`
  always returns the requested number of grants.
  """

  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups.Entry
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups.Group
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups.ItemGroupPool
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups.SubGroup

  @type rng() :: module() | (pos_integer() -> pos_integer())

  @doc "Returns all guaranteed grants and one grant from each selectable subgroup."
  @spec roll_full(Group.t(), rng()) :: [Group.grant()]
  def roll_full(group, rng \\ :rand) do
    Enum.flat_map(group.subgroups, fn
      %SubGroup{algorithm: :all} = subgroup ->
        Enum.map(subgroup.entries, &grant(&1, nil, rng))

      %SubGroup{algorithm: :random} = subgroup ->
        [subgroup.entries |> weighted_pick(rng) |> grant(nil, rng)]

      %SubGroup{algorithm: :shared_pool, number: sub} ->
        roll_n(group, sub, 1, rng)
    end)
  end

  @doc "Returns the requested number of grants from one subgroup."
  @spec roll_n(Group.t(), non_neg_integer(), pos_integer(), rng()) :: [Group.grant()]
  def roll_n(group, sub, count, rng \\ :rand) when count > 0 do
    case Enum.find(group.subgroups, &(&1.number == sub)) do
      %SubGroup{algorithm: algorithm} = subgroup when algorithm in [:random, :all] ->
        List.duplicate(nil, count)
        |> Enum.map(fn _ -> subgroup.entries |> weighted_pick(rng) |> grant(nil, rng) end)

      %SubGroup{algorithm: :shared_pool} = subgroup ->
        draw_pool(group.key, sub, count, subgroup, rng)

      nil ->
        []
    end
  end

  @spec draw_pool(atom(), non_neg_integer(), pos_integer(), SubGroup.t(), rng()) ::
          [Group.grant()]
  defp draw_pool(group_key, sub, count, subgroup, rng) do
    case ItemGroupPool.draw(group_key, sub, count) do
      {:ok, item_ids} ->
        Enum.map(item_ids, fn item_id ->
          entry = Enum.find(subgroup.entries, &(&1.item_id == item_id))
          grant(entry, {sub, [item_id]}, rng)
        end)

      {:error, :empty} ->
        []
    end
  end

  @doc "Returns one weighted catalog item id without depleting shared-pool state."
  @spec pick_id(Group.t(), non_neg_integer(), rng()) :: {:ok, pos_integer()} | :error
  def pick_id(group, sub, rng \\ :rand) do
    with %SubGroup{entries: entries} <- Enum.find(group.subgroups, &(&1.number == sub)),
         true <- Enum.any?(entries, &(&1.rate > 0)) do
      {:ok, weighted_pick(entries, rng).item_id}
    else
      _ -> :error
    end
  end

  @spec weighted_pick([Entry.t()], rng()) :: Entry.t()
  defp weighted_pick(entries, rng) do
    total = Enum.sum_by(entries, & &1.rate)

    if total == 0 do
      raise ArgumentError, "cannot select from an item subgroup with no positive rates"
    end

    roll = uniform(rng, total)

    Enum.reduce_while(entries, roll, fn entry, remaining ->
      if remaining <= entry.rate do
        {:halt, entry}
      else
        {:cont, remaining - entry.rate}
      end
    end)
  end

  @spec grant(Entry.t(), {non_neg_integer(), [pos_integer()]} | nil, rng()) :: Group.grant()
  defp grant(entry, drawn, rng) do
    %{
      item_id: entry.item_id,
      amount: entry.amount,
      identify?: entry.identify?,
      refine: uniform_range(entry.refine_min, entry.refine_max, rng),
      grade: uniform_range(entry.grade_min, entry.grade_max, rng),
      bound: entry.bound,
      unique_id?: entry.unique_id?,
      duration_min: entry.duration_min,
      named?: entry.named?,
      announced?: entry.announced?,
      drawn: drawn
    }
  end

  @spec uniform_range(non_neg_integer(), non_neg_integer(), rng()) :: non_neg_integer()
  defp uniform_range(min, min, _rng), do: min
  defp uniform_range(min, max, rng), do: min + uniform(rng, max - min + 1) - 1

  @spec uniform(rng(), pos_integer()) :: pos_integer()
  defp uniform(rng, max) when is_function(rng, 1), do: rng.(max)
  defp uniform(rng, max) when is_atom(rng), do: rng.uniform(max)
end
