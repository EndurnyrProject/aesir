defmodule Mix.Tasks.Aesir.Import.Produce do
  @shortdoc "Imports selected production data into mode-scoped YAML"
  @moduledoc """
  Converts the selected mode's `produce_db.txt` and generated item-group data
  into `apps/zone_server/priv/db/<mode>/produce/*.yml`.

      mix aesir.import.produce [<rathena_root>] [--mode re|pre-re]

  Output is sorted so re-running the task produces byte-identical files.
  """
  use Mix.Task

  alias Mix.Tasks.Aesir.Import

  @doc "Imports production data from the optional source root."
  @spec run([String.t()]) :: :ok
  @impl Mix.Task
  def run(args) do
    {source_root, mode} = Import.parse!(args)
    recipes_out = Import.path("produce/recipes.yml", mode)
    ore_out = Import.path("produce/ore_discovery.yml", mode)
    ore_source = Import.path("item_groups", mode) |> Path.join("item_groups.yml")

    recipes =
      source_root
      |> Import.rathena_db_dir(mode)
      |> Path.join("produce_db.txt")
      |> File.read!()
      |> parse_recipes()

    ore_entries =
      ore_source
      |> YamlElixir.read_from_file!()
      |> ore_entries()

    File.mkdir_p!(Path.dirname(recipes_out))
    File.write!(recipes_out, Ymlr.document!(recipes, sort_maps: true))
    File.write!(ore_out, Ymlr.document!(ore_entries, sort_maps: true))

    Mix.shell().info("produce: wrote #{length(recipes)} recipes -> #{recipes_out}")

    Mix.shell().info("produce: wrote #{length(ore_entries)} ore entries -> #{ore_out}")
  end

  @doc "Parses and normalizes delimited production recipes."
  @spec parse_recipes(String.t()) :: [map()]
  def parse_recipes(contents) do
    contents
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(String.starts_with?(&1, "//") or &1 == ""))
    |> Enum.map(&recipe_entry/1)
    |> Enum.sort_by(& &1["id"])
  end

  @spec recipe_entry(String.t()) :: map()
  defp recipe_entry(line) do
    [id, product_id, item_level, skill_id, skill_level | material_fields] =
      line
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.map(&String.to_integer/1)

    %{
      "id" => id,
      "product_id" => product_id,
      "item_level" => item_level,
      "skill_id" => skill_id,
      "skill_level" => skill_level,
      "materials" => materials(material_fields)
    }
  end

  @spec materials([integer()]) :: [map()]
  defp materials(fields) do
    fields
    |> Enum.chunk_every(2)
    |> Enum.map(fn [item_id, amount] -> %{"item_id" => item_id, "amount" => amount} end)
  end

  @spec ore_entries([map()]) :: [map()]
  defp ore_entries(groups) do
    groups
    |> Enum.find(&(Map.fetch!(&1, "key") == "ore"))
    |> Map.fetch!("subgroups")
    |> Enum.flat_map(&Map.fetch!(&1, "entries"))
    |> Enum.map(&ore_entry/1)
    |> Enum.sort_by(& &1["item_id"])
  end

  @spec ore_entry(map()) :: map()
  defp ore_entry(%{"item_id" => item_id, "rate" => rate}) do
    %{"item_id" => item_id, "rate" => rate}
  end
end
