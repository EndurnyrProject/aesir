defmodule Mix.Tasks.Aesir.Import.Mobs do
  @shortdoc "Imports the selected rAthena mob DB into mode-scoped YAML"
  @moduledoc """
  Converts canonical `db/mob_db.yml` plus its selected mode imports into
  `apps/zone_server/priv/db/<mode>/mobs/mobs.yml`.

      mix aesir.import.mobs [<rathena_root>] [--mode re|pre-re]

  `<rathena_root>` defaults to `../rathena`. Unmapped data fails loudly.
  """
  use Mix.Task

  alias Mix.Tasks.Aesir.Import

  alias Aesir.ZoneServer.Mmo.MobManagement.Importer

  @impl Mix.Task
  def run(args) do
    {rathena, mode} = Import.parse!(args)
    out_dir = Import.path("mobs", mode)
    src = Path.join([rathena, "db", "mob_db.yml"])
    File.mkdir_p!(out_dir)

    definitions = src |> Import.read_mode_filtered!(mode) |> Enum.map(&to_definition!/1)
    yaml = definitions |> Enum.map(&Importer.to_yaml_map/1) |> Ymlr.document!()
    out = Path.join(out_dir, "mobs.yml")
    File.write!(out, yaml)
    Mix.shell().info("mobs: #{length(definitions)} -> #{out}")
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
