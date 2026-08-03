defmodule Mix.Tasks.Aesir.Import.Homunculi do
  @shortdoc "Imports Renewal Homunculus data into priv/db/homunculus"
  @moduledoc """
  Imports original and evolved Homunculus species, levels 1 through 99 EXP, and
  skill trees from a local rAthena checkout.

      mix aesir.import.homunculi [<rathena_root>]
  """
  use Mix.Task

  alias Aesir.ZoneServer.Mmo.Homunculus.Catalog
  alias Aesir.ZoneServer.Mmo.Homunculus.Catalogs
  alias Aesir.ZoneServer.Mmo.Homunculus.ExpTable
  alias Aesir.ZoneServer.Mmo.Homunculus.SkillTree

  @out_dir Path.join(~w(apps zone_server priv db homunculus))
  @status_types ~w(hp sp str agi vit int dex luk)

  @impl Mix.Task
  def run(args) do
    root = List.first(args) || "../rathena"
    homunculus_path = Path.join([root, "db", "re", "homunculus_db.yml"])
    exp_path = Path.join([root, "db", "re", "exp_homun.yml"])
    skill_path = Path.join([root, "db", "re", "skill_db.yml"])
    class_path = Path.join([root, "src", "map", "homunculus.hpp"])

    class_ids = class_ids!(class_path)
    skill_ids = skill_ids!(skill_path)

    source_species =
      homunculus_path
      |> read_body!()
      |> Enum.filter(&Map.has_key?(&1, "EvolutionClass"))

    if length(source_species) != 8,
      do: Mix.raise("expected 8 original Homunculus variants in #{homunculus_path}")

    species = Enum.flat_map(source_species, &species_rows(&1, class_ids, skill_ids))
    trees = Enum.flat_map(source_species, &skill_rows(&1, class_ids, skill_ids))

    exp =
      exp_path
      |> read_body!()
      |> Enum.filter(&(&1["Level"] in 1..99))
      |> Enum.map(&%{"level" => &1["Level"], "exp" => &1["Exp"]})

    Catalog.validate!(species)
    ExpTable.validate!(exp)
    SkillTree.validate!(trees, MapSet.new(species, & &1["id"]))
    Catalogs.validate!(species, trees)

    File.mkdir_p!(@out_dir)
    write!("species.yml", species)
    write!("exp.yml", exp)
    write!("skill_trees.yml", trees)
    :ok = Catalogs.reload()
    Mix.shell().info("homunculi: 16 classes, 99 EXP levels, #{length(trees)} skill rows")
  end

  defp species_rows(source, class_ids, skill_ids) do
    class_id = fetch_id!(class_ids, source["Class"], "class")
    evolved_id = fetch_id!(class_ids, source["EvolutionClass"], "class")
    skills = Enum.map(source["SkillTree"], &fetch_id!(skill_ids, &1["Skill"], "skill"))
    common = common_species(source, class_id, evolved_id, skills)

    [
      Map.merge(common, %{
        "id" => class_id,
        "variant" => source["Class"],
        "form" => "original",
        "size" => source["Size"] || "Small"
      }),
      Map.merge(common, %{
        "id" => evolved_id,
        "variant" => source["EvolutionClass"],
        "form" => "evolved",
        "size" => source["EvolutionSize"] || "Medium"
      })
    ]
  end

  defp common_species(source, class_id, evolved_id, skills) do
    %{
      "name" => source["Name"],
      "base_class_id" => class_id,
      "evolution_class_id" => evolved_id,
      "food" => source["Food"] || "Pet_Food",
      "hungry_delay" => source["HungryDelay"] || 60_000,
      "race" => normalize(source["Race"] || "Demihuman"),
      "element" => normalize(source["Element"] || "Neutral"),
      "attack_delay" => source["AttackDelay"] || 700,
      "stats" => stats(source["Status"]),
      "skills" => skills
    }
  end

  defp stats(rows) do
    result =
      Map.new(rows, fn row ->
        {normalize(row["Type"]),
         %{
           "base" => row["Base"] || 1,
           "growth_min" => row["GrowthMinimum"] || 0,
           "growth_max" => row["GrowthMaximum"] || 0,
           "evolution_min" => row["EvolutionMinimum"] || 0,
           "evolution_max" => row["EvolutionMaximum"] || 0
         }}
      end)

    if Enum.sort(Map.keys(result)) != Enum.sort(@status_types),
      do: Mix.raise("expected status rows #{inspect(@status_types)}")

    result
  end

  defp skill_rows(source, class_ids, skill_ids) do
    class_id = fetch_id!(class_ids, source["Class"], "class")
    evolved_id = fetch_id!(class_ids, source["EvolutionClass"], "class")

    for id <- [class_id, evolved_id], skill <- source["SkillTree"] do
      %{
        "class_id" => id,
        "skill_id" => fetch_id!(skill_ids, skill["Skill"], "skill"),
        "skill" => skill["Skill"],
        "max_level" => skill["MaxLevel"],
        "required_level" => skill["RequiredLevel"] || 0,
        "required_intimacy" => (skill["RequiredIntimacy"] || 0) * 100,
        "form" => if(skill["RequireEvolution"] == true, do: "evolved", else: "any"),
        "requires" =>
          Enum.map(skill["Required"] || [], fn required ->
            %{
              "skill_id" => fetch_id!(skill_ids, required["Skill"], "skill"),
              "level" => required["Level"]
            }
          end)
      }
    end
  end

  defp class_ids!(path) do
    {_next, ids} =
      path
      |> File.read!()
      |> String.split("\n")
      |> Enum.reduce({nil, %{}}, fn line, {next, ids} ->
        case Regex.run(~r/^\s*MER_([A-Z0-9_]+)(?:\s*=\s*(\d+))?,\s*$/, line) do
          [_, name, explicit] ->
            id = String.to_integer(explicit)
            {id + 1, Map.put(ids, name, id)}

          [_, name] when is_integer(next) ->
            {next + 1, Map.put(ids, name, next)}

          _ ->
            {next, ids}
        end
      end)

    expected = Enum.to_list(6001..6016)

    original =
      Map.take(
        ids,
        ~w(LIF AMISTR FILIR VANILMIRTH LIF2 AMISTR2 FILIR2 VANILMIRTH2 LIF_H AMISTR_H FILIR_H VANILMIRTH_H LIF_H2 AMISTR_H2 FILIR_H2 VANILMIRTH_H2)
      )

    if original |> Map.values() |> Enum.sort() != expected,
      do: Mix.raise("expected Homunculus class ids 6001..6016 in #{path}")

    original
  end

  defp skill_ids!(path) do
    path
    |> read_body!()
    |> Map.new(fn entry -> {String.upcase(entry["Name"]), entry["Id"]} end)
  end

  defp fetch_id!(ids, name, kind) do
    case Map.fetch(ids, String.upcase(name)) do
      {:ok, id} -> id
      :error -> Mix.raise("unknown #{kind} #{name}")
    end
  end

  defp read_body!(path) do
    case YamlElixir.read_from_file!(path) do
      %{"Body" => body} when is_list(body) -> body
      _ -> Mix.raise("expected a Body list in #{path}")
    end
  end

  defp normalize(value),
    do: value |> Macro.underscore() |> String.replace("demihuman", "demi_human")

  defp write!(name, rows) do
    rows = Enum.sort_by(rows, &sort_key/1)
    File.write!(Path.join(@out_dir, name), Ymlr.document!(rows))
  end

  defp sort_key(%{"id" => id}), do: id
  defp sort_key(%{"level" => level}), do: level
  defp sort_key(%{"class_id" => class_id, "skill_id" => skill_id}), do: {class_id, skill_id}
end
