defmodule Mix.Tasks.Aesir.Import.ItemGroups do
  @shortdoc "Imports Renewal item groups into priv/db/item_groups/item_groups.yml"
  @moduledoc """
  Imports Renewal item-group data into the local item-group database.

      mix aesir.import.item_groups [<source_root>]

  Item names that are absent from the local item catalog are dropped. Output is
  sorted so re-running the task against the same source produces identical
  files.

  Two source attributes are intentionally NOT imported (spec non-goals):
  `RandomOptionGroup` (needs a random-option roller subsystem) and `Stacked`
  (`Stacked: false` means the box grants separate, non-stacking rows). The grant
  core treats such entries as ordinary stackables for now.
  """
  use Mix.Task

  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.ItemManagement.Items

  @out_dir Path.join(~w(apps zone_server priv db item_groups))
  @out_file Path.join(@out_dir, "item_groups.yml")
  @source_db Path.join(~w(db re item_group_db.yml))

  @entry_attributes %{
    "Amount" => "amount",
    "Announced" => "announced",
    "Bound" => "bound",
    "Duration" => "duration",
    "GradeMaximum" => "grade_maximum",
    "GradeMinimum" => "grade_minimum",
    "Identify" => "identify",
    "Named" => "named",
    "Rate" => "rate",
    "RefineMaximum" => "refine_maximum",
    "RefineMinimum" => "refine_minimum",
    "UniqueId" => "unique_id"
  }

  @impl Mix.Task
  @spec run([String.t()]) :: :ok
  def run(args) do
    source_root = List.first(args) || "../rathena"

    {groups, resolved, dropped} =
      source_root
      |> Path.join(@source_db)
      |> YamlElixir.read_from_file!()
      |> Map.fetch!("Body")
      |> convert()

    File.mkdir_p!(@out_dir)
    File.write!(@out_file, Ymlr.document!(groups, sort_maps: true))
    report(resolved, dropped)
  end

  @spec convert([map()]) :: {[map()], non_neg_integer(), [String.t()]}
  defp convert(groups) do
    {groups, resolved, dropped} =
      Enum.reduce(groups, {[], 0, []}, fn group, {groups, resolved, dropped} ->
        {subgroups, subgroup_resolved, subgroup_dropped} = convert_subgroups(group)

        {
          [%{"key" => group_key(group), "subgroups" => subgroups} | groups],
          resolved + subgroup_resolved,
          subgroup_dropped ++ dropped
        }
      end)

    {Enum.sort_by(groups, & &1["key"]), resolved, Enum.sort(dropped)}
  end

  @spec convert_subgroups(map()) :: {[map()], non_neg_integer(), [String.t()]}
  defp convert_subgroups(group) do
    group
    |> Map.fetch!("SubGroups")
    |> Enum.reduce({[], 0, []}, fn subgroup, {subgroups, resolved, dropped} ->
      {entries, entry_resolved, entry_dropped} = convert_entries(subgroup)

      {
        [
          %{
            "algorithm" => algorithm(Map.get(subgroup, "Algorithm")),
            "entries" => entries,
            "number" => Map.fetch!(subgroup, "SubGroup")
          }
          | subgroups
        ],
        resolved + entry_resolved,
        entry_dropped ++ dropped
      }
    end)
    |> then(fn {subgroups, resolved, dropped} ->
      {Enum.sort_by(subgroups, & &1["number"]), resolved, dropped}
    end)
  end

  @spec convert_entries(map()) :: {[map()], non_neg_integer(), [String.t()]}
  defp convert_entries(subgroup) do
    subgroup
    |> Map.fetch!("List")
    |> Enum.reduce({[], 0, []}, fn entry, {entries, resolved, dropped} ->
      case resolve(Map.fetch!(entry, "Item")) do
        {:ok, item} ->
          {[{Map.fetch!(entry, "Index"), entry_map(entry, item)} | entries], resolved + 1,
           dropped}

        :error ->
          {entries, resolved, [Map.fetch!(entry, "Item") | dropped]}
      end
    end)
    |> then(fn {entries, resolved, dropped} ->
      {entries |> Enum.sort_by(&elem(&1, 0)) |> Enum.map(&elem(&1, 1)), resolved, dropped}
    end)
  end

  @spec entry_map(map(), ItemDefinition.t()) :: map()
  defp entry_map(entry, item) do
    @entry_attributes
    |> Enum.reduce(%{"item_id" => item.id}, fn {source_key, target_key}, output ->
      case Map.fetch(entry, source_key) do
        {:ok, value} -> Map.put(output, target_key, value)
        :error -> output
      end
    end)
  end

  @spec group_key(map()) :: String.t()
  defp group_key(group), do: group |> Map.fetch!("Group") |> String.downcase()

  @spec algorithm(String.t() | nil) :: String.t()
  defp algorithm(nil), do: "shared_pool"
  defp algorithm("All"), do: "all"
  defp algorithm("Random"), do: "random"
  defp algorithm("SharedPool"), do: "shared_pool"
  defp algorithm(value), do: Mix.raise("unknown item-group algorithm: #{inspect(value)}")

  @spec resolve(String.t()) :: {:ok, ItemDefinition.t()} | :error
  defp resolve(aegis), do: Items.by_aegis(aegis)

  @spec report(non_neg_integer(), [String.t()]) :: :ok
  defp report(resolved, dropped) do
    Mix.shell().info("item_groups: resolved #{resolved} entries, dropped #{length(dropped)}")

    unless dropped == [] do
      Mix.shell().info("  unresolved: #{dropped |> Enum.uniq() |> Enum.join(", ")}")
    end

    :ok
  end
end
