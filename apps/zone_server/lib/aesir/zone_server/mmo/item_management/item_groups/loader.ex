defmodule Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups.Loader do
  @moduledoc """
  Builds the item-group index from our-schema YAML files in the item_groups domain.

  Cache mechanics live in `Aesir.ZoneServer.Mmo.DataLoader`. Plain functions
  only - no process.
  """

  alias Aesir.ZoneServer.Mmo.DataLoader
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups.Entry
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups.Group
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups.SubGroup

  @type index() :: %{atom() => Group.t()}

  @cache_file "item_groups_v1.etf"

  @entry_fields %{
    "amount" => :amount,
    "announced" => :announced?,
    "bound" => :bound,
    "duration" => :duration_min,
    "grade_maximum" => :grade_max,
    "grade_minimum" => :grade_min,
    "identify" => :identify?,
    "item_id" => :item_id,
    "named" => :named?,
    "rate" => :rate,
    "refine_maximum" => :refine_max,
    "refine_minimum" => :refine_min,
    "unique_id" => :unique_id?
  }

  @spec load() :: index()
  def load, do: "item_groups" |> DataLoader.load(@cache_file, &build/1) |> index()

  @spec build([Path.t()]) :: [Group.t()]
  defp build(sources) do
    sources
    |> Enum.flat_map(&DataLoader.parse_file/1)
    |> Enum.map(&to_group!/1)
    |> DataLoader.merge_by_key(& &1.key)
  end

  @spec index([Group.t()]) :: index()
  defp index(groups), do: Map.new(groups, &{&1.key, &1})

  @spec to_group!(map()) :: Group.t()
  defp to_group!(group) do
    %Group{
      key: group |> Map.fetch!("key") |> String.to_atom(),
      subgroups: group |> Map.fetch!("subgroups") |> Enum.map(&to_subgroup!/1)
    }
  end

  @spec to_subgroup!(map()) :: SubGroup.t()
  defp to_subgroup!(subgroup) do
    %SubGroup{
      number: Map.fetch!(subgroup, "number"),
      algorithm: subgroup |> Map.fetch!("algorithm") |> String.to_atom(),
      entries: subgroup |> Map.fetch!("entries") |> Enum.map(&to_entry!/1)
    }
  end

  @spec to_entry!(map()) :: Entry.t()
  defp to_entry!(entry) do
    attrs =
      Map.new(entry, fn {key, value} ->
        field = Map.fetch!(@entry_fields, key)
        {field, convert(field, value)}
      end)

    struct!(Entry, attrs)
  end

  @spec convert(atom(), term()) :: term()
  defp convert(:bound, nil), do: nil
  defp convert(:bound, value), do: String.to_atom(value)
  defp convert(_field, value), do: value
end
