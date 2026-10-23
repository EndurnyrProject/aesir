defmodule Mix.Tasks.Aesir.Import.ItemGroups do
  @shortdoc "Imports selected rAthena item groups into mode-scoped YAML"
  @moduledoc """
  Converts canonical `db/item_group_db.yml` plus its selected mode imports into
  `apps/zone_server/priv/db/<mode>/item_groups/item_groups.yml`.

      mix aesir.import.item_groups [<rathena_root>] [--mode re|pre-re]

  Entries resolve against the selected canonical `db/item_db.yml`; unknown item
  names are dropped and reported. Output is deterministic.

  `Stacked: false` is imported: that entry is granted one unit per add even
  when the item itself is stackable. `RandomOptionGroup` is imported as the
  group's id from the same mode's `db/item_randomopt_group.yml`; an unknown
  group name aborts the import, as the reference loader abandons the row
  part-way through an entry it already stored.
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
    "Stacked" => "stacked",
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
    option_groups = option_group_ids(source_root, mode, item_group_rows)

    {groups, resolved, dropped} =
      Resolver.with_source_catalogs(source_catalogs, fn ->
        convert(item_group_rows, option_groups)
      end)

    File.mkdir_p!(Path.dirname(out_file))
    File.write!(out_file, Ymlr.document!(groups, sort_maps: true))
    report(resolved, dropped)
  end

  # The random option group ids by name, read only when an entry names one.
  defp option_group_ids(source_root, mode, item_group_rows) do
    if Enum.any?(item_group_rows, &names_option_group?/1) do
      source_root
      |> read_source!("item_randomopt_group.yml", mode)
      |> Enum.reduce(%{}, &put_option_group_id/2)
    else
      %{}
    end
  end

  # A repeated id renames its group; a row without a name keeps the old one.
  defp put_option_group_id(%{"Group" => name, "Id" => id}, ids) when is_binary(name),
    do: ids |> Map.reject(fn {_name, other} -> other == id end) |> Map.put(name, id)

  defp put_option_group_id(_row, ids), do: ids

  defp names_option_group?(group) do
    for subgroup <- group["SubGroups"] || [],
        entry <- subgroup["List"] || [],
        reduce: false,
        do: (named? -> named? or Map.has_key?(entry, "RandomOptionGroup"))
  end

  @spec convert([map()], %{String.t() => pos_integer()}) ::
          {[map()], non_neg_integer(), [String.t()]}
  defp convert(groups, option_groups) do
    {groups, resolved, dropped} =
      Enum.reduce(groups, {[], 0, []}, fn group, {groups, resolved, dropped} ->
        {subgroups, subgroup_resolved, subgroup_dropped} =
          convert_subgroups(group, option_groups)

        {
          [%{"key" => group_key(group), "subgroups" => subgroups} | groups],
          resolved + subgroup_resolved,
          subgroup_dropped ++ dropped
        }
      end)

    {Enum.sort_by(groups, & &1["key"]), resolved, Enum.sort(dropped)}
  end

  @spec convert_subgroups(map(), %{String.t() => pos_integer()}) ::
          {[map()], non_neg_integer(), [String.t()]}
  defp convert_subgroups(group, option_groups) do
    group
    |> Map.fetch!("SubGroups")
    |> Enum.reduce({[], 0, []}, fn subgroup, {subgroups, resolved, dropped} ->
      {entries, entry_resolved, entry_dropped} = convert_entries(subgroup, option_groups)

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

  @spec convert_entries(map(), %{String.t() => pos_integer()}) ::
          {[map()], non_neg_integer(), [String.t()]}
  defp convert_entries(subgroup, option_groups) do
    subgroup
    |> Map.fetch!("List")
    |> Enum.reduce({[], 0, []}, fn entry, {entries, resolved, dropped} ->
      case resolve(Map.fetch!(entry, "Item")) do
        {:ok, item} ->
          {[{Map.fetch!(entry, "Index"), entry_map(entry, item, option_groups)} | entries],
           resolved + 1, dropped}

        :error ->
          {entries, resolved, [Map.fetch!(entry, "Item") | dropped]}
      end
    end)
    |> then(fn {entries, resolved, dropped} ->
      {entries |> Enum.sort_by(&elem(&1, 0)) |> Enum.map(&elem(&1, 1)), resolved, dropped}
    end)
  end

  @spec entry_map(map(), integer(), %{String.t() => pos_integer()}) :: map()
  defp entry_map(entry, item_id, option_groups) do
    @entry_attributes
    |> Enum.reduce(%{"item_id" => item_id}, fn {source_key, target_key}, output ->
      case Map.fetch(entry, source_key) do
        {:ok, value} -> Map.put(output, target_key, value)
        :error -> output
      end
    end)
    |> put_option_group(entry, option_groups)
  end

  defp put_option_group(output, %{"RandomOptionGroup" => name}, option_groups) do
    case Map.fetch(option_groups, name) do
      {:ok, id} -> Map.put(output, "random_option_group", id)
      :error -> Mix.raise("unknown random option group #{inspect(name)}")
    end
  end

  defp put_option_group(output, _entry, _option_groups), do: output

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
