defmodule Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups.Roller do
  @moduledoc """
  Selects concrete grants from item-group catalog entries.

  A requested `:all` subgroup is sampled like a random subgroup so `roll_n/4`
  always returns the requested number of grants.
  """

  alias Aesir.Commons.GameMode
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

  @doc """
  Picks one entry from `sub` and shapes it as a single grant of `qty` units.

  This is the reference's single-entry buildin: `:random` picks weighted,
  `:all` picks uniformly, and `:shared_pool` consumes one copy from the pool.
  A `qty` of 0 takes the entry's own amount. Only the item id and the identify
  rule carry over; the entry's other attributes belong to the per-entry grant,
  not this one. Returns `nil` when the subgroup has no selectable entry.
  """
  @spec pick_grant(Group.t(), non_neg_integer(), non_neg_integer(), keyword()) ::
          Group.grant() | nil
  def pick_grant(group, sub, qty, opts \\ []) do
    rng = Keyword.get(opts, :rng, :rand)
    identify? = Keyword.get(opts, :identify?, false)

    case pick_entry(group, sub, rng) do
      {:ok, entry, drawn} -> single_grant(entry, qty, drawn, identify?)
      :error -> nil
    end
  end

  defp pick_entry(%Group{subgroups: subgroups, key: key}, sub, rng) do
    case Enum.find(subgroups, &(&1.number == sub)) do
      %SubGroup{algorithm: :random, entries: entries} -> random_entry(entries, rng)
      %SubGroup{algorithm: :all, entries: entries} -> uniform_entry(entries, rng)
      %SubGroup{algorithm: :shared_pool} = subgroup -> pool_entry(key, sub, subgroup)
      nil -> :error
    end
  end

  defp random_entry(entries, rng) do
    if Enum.any?(entries, &(&1.rate > 0)),
      do: {:ok, weighted_pick(entries, rng), nil},
      else: :error
  end

  defp uniform_entry([], _rng), do: :error

  defp uniform_entry(entries, rng),
    do: {:ok, Enum.at(entries, uniform(rng, length(entries)) - 1), nil}

  defp pool_entry(key, sub, subgroup) do
    case ItemGroupPool.draw(key, sub, 1) do
      {:ok, [item_id]} ->
        case Enum.find(subgroup.entries, &(&1.item_id == item_id)) do
          nil -> :error
          entry -> {:ok, entry, {sub, [item_id]}}
        end

      {:error, :empty} ->
        :error
    end
  end

  defp single_grant(entry, qty, drawn, identify?) do
    %{
      item_id: entry.item_id,
      amount: if(qty > 0, do: qty, else: entry.amount),
      identify?: identify?,
      refine: 0,
      grade: 0,
      refine_min: 0,
      refine_max: 0,
      grade_min: 0,
      grade_max: 0,
      bound: nil,
      unique_id?: false,
      duration_min: 0,
      named?: false,
      announced?: false,
      stacked?: true,
      drawn: drawn
    }
  end

  @doc """
  Returns the item id one entry pick would grant, honoring the subgroup
  algorithm.

  `:random` is weighted, `:all` is uniform, and `:shared_pool` consumes one
  copy, exactly as the reference's `get_random_entry` does for
  `grouprandomitem`.
  """
  @spec pick_id(Group.t(), non_neg_integer(), rng()) :: {:ok, pos_integer()} | :error
  def pick_id(group, sub, rng \\ :rand) do
    case pick_entry(group, sub, rng) do
      {:ok, entry, _drawn} -> {:ok, entry.item_id}
      :error -> :error
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
      refine: roll_refine_range(entry.refine_min, entry.refine_max, rng),
      grade: roll_grade_range(entry.grade_min, entry.grade_max, rng),
      refine_min: entry.refine_min,
      refine_max: entry.refine_max,
      grade_min: entry.grade_min,
      grade_max: entry.grade_max,
      bound: entry.bound,
      unique_id?: entry.unique_id?,
      duration_min: entry.duration_min,
      named?: entry.named?,
      announced?: entry.announced?,
      stacked?: entry.stacked?,
      random_option_group: entry.random_option_group,
      drawn: drawn
    }
  end

  @doc "Rolls a grant's refine level from its entry ranges, as the reference does."
  @spec roll_refine(Group.grant(), rng()) :: non_neg_integer()
  def roll_refine(grant, rng \\ :rand),
    do: roll_refine_range(grant.refine_min, grant.refine_max, rng)

  @doc "Rolls a grant's enchant grade from its entry ranges, as the reference does."
  @spec roll_grade(Group.grant(), rng()) :: non_neg_integer()
  def roll_grade(grant, rng \\ :rand),
    do: roll_grade_range(grant.grade_min, grant.grade_max, rng)

  defp roll_refine_range(min, max, rng) when min > 0 and max > 0,
    do: uniform_range(min, max, rng)

  defp roll_refine_range(min, _max, rng) when min > 0,
    do: uniform_range(min, max_refine(), rng)

  defp roll_refine_range(_min, max, rng) when max > 0, do: uniform_range(1, max, rng)
  defp roll_refine_range(_min, _max, _rng), do: 0

  defp roll_grade_range(min, max, rng) when min > 0 and max > 0,
    do: uniform_range(min, max, rng)

  defp roll_grade_range(min, _max, rng) when min > 0,
    do: uniform_range(min, max_grade(), rng)

  defp roll_grade_range(_min, max, rng) when max > 0, do: uniform_range(0, max, rng)
  defp roll_grade_range(_min, _max, _rng), do: 0

  defp max_refine do
    case GameMode.mode() do
      :pre_renewal -> 10
      _renewal -> 20
    end
  end

  defp max_grade do
    case GameMode.mode() do
      :pre_renewal -> 0
      _renewal -> 4
    end
  end

  @spec uniform_range(non_neg_integer(), non_neg_integer(), rng()) :: non_neg_integer()
  defp uniform_range(min, min, _rng), do: min
  defp uniform_range(min, max, rng), do: min + uniform(rng, max - min + 1) - 1

  @spec uniform(rng(), pos_integer()) :: pos_integer()
  defp uniform(rng, max) when is_function(rng, 1), do: rng.(max)
  defp uniform(rng, max) when is_atom(rng), do: rng.uniform(max)
end
