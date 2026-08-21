defmodule Mix.Tasks.Aesir.Import.Mobs do
  @shortdoc "Imports rAthena renewal mob_db into priv/db/re/mobs/mobs.yml"
  @moduledoc """
  One-time importer: converts rAthena's renewal `mob_db.yml` into our own-schema
  YAML at `apps/zone_server/priv/db/re/mobs/mobs.yml`.

      mix aesir.import.mobs [<rathena_root>]

  `<rathena_root>` defaults to `../rathena`. Fails loudly on unmapped data - this
  is a dev tool, run only when syncing rAthena.
  """
  use Mix.Task

  alias Mix.Tasks.Aesir.Import

  alias Aesir.ZoneServer.Mmo.MobManagement.Importer

  @impl Mix.Task
  def run(args) do
    {rathena, mode} = Import.parse!(args)
    out_dir = Import.path("mobs", mode)
    src = Path.join([rathena, "db", "re", "mob_db.yml"])
    File.mkdir_p!(out_dir)

    definitions = src |> read_body!() |> Enum.map(&to_definition!/1)
    yaml = definitions |> Enum.map(&Importer.to_yaml_map/1) |> Ymlr.document!()
    out = Path.join(out_dir, "mobs.yml")
    File.write!(out, yaml)
    Mix.shell().info("mobs: #{length(definitions)} -> #{out}")
  end

  defp read_body!(path) do
    case YamlElixir.read_from_file!(path) do
      %{"Body" => body} when is_list(body) -> body
      _ -> Mix.raise("expected a Body list in #{path}")
    end
  end

  defp to_definition!(entry) do
    case Importer.to_definition(entry) do
      {:ok, definition} ->
        definition

      {:error, reason} ->
        Mix.raise("failed to import mob #{inspect(entry["Id"])}: #{inspect(reason)}")
    end
  end
end
