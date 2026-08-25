defmodule Mix.Tasks.Aesir.Import.ItemGroups do
  @shortdoc "Imports selected rAthena item groups into mode-scoped YAML"
  @moduledoc """
  Converts canonical `db/item_group_db.yml` plus its selected mode imports into
  `apps/zone_server/priv/db/<mode>/item_groups/item_groups.yml`.

      mix aesir.import.item_groups [<rathena_root>] [--mode re|pre-re]

  Entries resolve against the selected canonical `db/item_db.yml`; unknown item
  names are dropped and reported. Output is deterministic.

  Two source attributes are intentionally NOT imported (spec non-goals):
  `RandomOptionGroup` (needs a random-option roller subsystem) and `Stacked`
  (`Stacked: false` means the box grants separate, non-stacking rows). The grant
  core treats such entries as ordinary stackables for now.
  """
  use Mix.Task

  alias Mix.Tasks.Aesir.Import

  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.Resolver

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
    {source_root, mode} = Import.parse!(args)
    out_file = Import.path("item_groups", mode) |> Path.join("item_groups.yml")
    item_rows = read_source!(source_root, "item_db.yml", mode)
    item_group_rows = read_source!(source_root, "item_group_db.yml", mode)
    source_catalogs = Resolver.source_catalogs(item_rows, item_group_rows)

    {groups, resolved, dropped} =
      Resolver.with_source_catalogs(source_catalogs, fn -> convert(item_group_rows) end)

    File.mkdir_p!(Path.dirname(out_file))
    File.write!(out_file, Ymlr.document!(groups, sort_maps: true))
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

  @spec entry_map(map(), integer()) :: map()
  defp entry_map(entry, item_id) do
    @entry_attributes
    |> Enum.reduce(%{"item_id" => item_id}, fn {source_key, target_key}, output ->
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

  defp read_source!(source_root, file, mode) do
    [source_root, "db", file]
    |> Path.join()
    |> Import.read_mode_filtered!(mode)
  end

  @spec resolve(String.t()) :: {:ok, integer()} | :error
  defp resolve(aegis) do
    case Resolver.resolve_item(aegis) do
      {:ok, id} -> {:ok, id}
      {:error, _reason} -> :error
    end
  end

  @spec report(non_neg_integer(), [String.t()]) :: :ok
  defp report(resolved, dropped) do
    Mix.shell().info("item_groups: resolved #{resolved} entries, dropped #{length(dropped)}")

    unless dropped == [] do
      Mix.shell().info("  unresolved: #{dropped |> Enum.uniq() |> Enum.join(", ")}")
    end

    :ok
  end
end
