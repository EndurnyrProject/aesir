defmodule Mix.Tasks.Aesir.Import.Items do
  @shortdoc "Imports rAthena renewal item_db into priv/db/items/*.yml"
  @moduledoc """
  One-time importer: converts rAthena's renewal `item_db_{usable,equip,etc}.yml`
  into our own-schema YAML under `apps/zone_server/priv/db/items/`.

      mix aesir.import.items [<rathena_root>]

  `<rathena_root>` defaults to `../rathena`. Anchors/merge keys are expanded by
  the parser, so the output is fully flat. Fails loudly on unmapped data - this
  is a dev tool, run only when syncing rAthena.
  """
  use Mix.Task

  alias Aesir.ZoneServer.Mmo.ItemManagement.Importer

  @sources ~w(usable equip etc)
  @out_dir Path.join(~w(apps zone_server priv db items))

  @impl Mix.Task
  def run(args) do
    rathena = List.first(args) || "../rathena"
    re_dir = Path.join([rathena, "db", "re"])
    File.mkdir_p!(@out_dir)

    Enum.each(@sources, &import_source(&1, re_dir))
  end

  defp import_source(kind, re_dir) do
    src = Path.join(re_dir, "item_db_#{kind}.yml")
    definitions = src |> read_body!() |> Enum.map(&to_definition!/1)
    yaml = definitions |> Enum.map(&Importer.to_yaml_map/1) |> Ymlr.document!()
    out = Path.join(@out_dir, "#{kind}.yml")
    File.write!(out, yaml)
    Mix.shell().info("#{kind}: #{length(definitions)} items -> #{out}")
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
        Mix.raise("failed to import item #{inspect(entry["Id"])}: #{inspect(reason)}")
    end
  end
end
