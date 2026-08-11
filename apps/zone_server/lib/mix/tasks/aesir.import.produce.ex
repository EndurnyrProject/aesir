defmodule Mix.Tasks.Aesir.Import.Produce do
  @shortdoc "Imports production recipes and the ore discovery table"
  @moduledoc """
  Imports production recipes and the ore discovery table into local YAML data.

      mix aesir.import.produce [<source_root>]

  Output is sorted so re-running the task produces byte-identical files.
  """
  use Mix.Task

  @out_dir Path.join(~w(apps zone_server priv db produce))
  @recipes_source Path.join(~w(db re produce_db.txt))
  @ore_source Path.join(~w(apps zone_server priv db item_groups item_groups.yml))

  @doc "Imports production data from the optional source root."
  @spec run([String.t()]) :: :ok
  @impl Mix.Task
  def run(args) do
    source_root = List.first(args) || "../rathena"

    recipes =
      source_root
      |> Path.join(@recipes_source)
      |> File.read!()
      |> parse_recipes()

    ore_entries =
      @ore_source
      |> YamlElixir.read_from_file!()
      |> ore_entries()

    File.mkdir_p!(@out_dir)
    File.write!(Path.join(@out_dir, "recipes.yml"), Ymlr.document!(recipes, sort_maps: true))

    File.write!(
      Path.join(@out_dir, "ore_discovery.yml"),
      Ymlr.document!(ore_entries, sort_maps: true)
    )

    Mix.shell().info("produce: wrote #{length(recipes)} recipes -> #{@out_dir}/recipes.yml")

    Mix.shell().info(
      "produce: wrote #{length(ore_entries)} ore entries -> #{@out_dir}/ore_discovery.yml"
    )
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
