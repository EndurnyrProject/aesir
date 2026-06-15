defmodule Mix.Tasks.Aesir.Import.Jobs do
  @shortdoc "Imports rAthena renewal job databases into priv/db/jobs/*.yml"
  @moduledoc """
  One-time importer: merges rAthena's renewal `job_stats.yml`, `job_basepoints.yml`,
  `job_aspd.yml` and `job_exp.yml` into our own-schema YAML under
  `apps/zone_server/priv/db/jobs/`, split by class tier.

      mix aesir.import.jobs [<rathena_root>]

  `<rathena_root>` defaults to `../rathena`. Fails loudly on unmapped data - this
  is a dev tool, run only when syncing rAthena.
  """
  use Mix.Task

  alias Aesir.ZoneServer.Mmo.JobManagement.Importer

  @out_dir Path.join(~w(apps zone_server priv db jobs))
  @sources %{
    stats: "job_stats.yml",
    basepoints: "job_basepoints.yml",
    aspd: "job_aspd.yml",
    exp: "job_exp.yml"
  }

  @impl Mix.Task
  def run(args) do
    rathena = List.first(args) || "../rathena"
    re_dir = Path.join([rathena, "db", "re"])
    File.mkdir_p!(@out_dir)

    bodies = Map.new(@sources, fn {key, file} -> {key, read_body!(re_dir, file)} end)

    bodies
    |> Importer.build()
    |> Enum.group_by(&Importer.tier/1)
    |> Enum.each(&write_tier/1)
  end

  defp write_tier({tier, maps}) do
    yaml = maps |> Enum.sort_by(& &1["id"]) |> to_yaml()
    out = Path.join(@out_dir, "jobs_#{tier}.yml")
    File.write!(out, yaml)
    Mix.shell().info("#{tier}: #{length(maps)} jobs -> #{out}")
  end

  # Leads each record with id/name for readability; Ymlr alone sorts keys
  # alphabetically. id is an int and name a snake_case atom string, so both are
  # safe as bare scalars. The rest of the record is rendered by Ymlr and indented.
  defp to_yaml(maps), do: "---\n" <> Enum.map_join(maps, "\n", &record_yaml/1) <> "\n"

  defp record_yaml(map) do
    {head, rest} = Map.split(map, ["id", "name"])
    "- id: #{head["id"]}\n  name: #{head["name"]}\n" <> indent(Ymlr.Encode.to_s!(rest))
  end

  defp indent(yaml) do
    yaml
    |> String.split("\n")
    |> Enum.map_join("\n", fn
      "" -> ""
      line -> "  " <> line
    end)
  end

  defp read_body!(re_dir, file) do
    path = Path.join(re_dir, file)

    case YamlElixir.read_from_file!(path) do
      %{"Body" => body} when is_list(body) -> body
      _ -> Mix.raise("expected a Body list in #{path}")
    end
  end
end
