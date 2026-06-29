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
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.Transpiler

  @type failure :: {integer(), String.t(), term()}

  @sources ~w(usable equip etc)
  @out_dir Path.join(~w(apps zone_server priv db items))

  @impl Mix.Task
  def run(args) do
    rathena = List.first(args) || "../rathena"
    re_dir = Path.join([rathena, "db", "re"])
    File.mkdir_p!(@out_dir)

    results = Enum.map(@sources, &import_source(&1, re_dir))
    transpiled = results |> Enum.map(&elem(&1, 0)) |> Enum.sum()
    failures = Enum.flat_map(results, &elem(&1, 1))

    report_path = Path.join(@out_dir, "_transpile_report.md")
    File.write!(report_path, build_report(failures))

    Mix.shell().info(
      "transpiled #{transpiled}/#{transpiled + length(failures)} scripts, " <>
        "#{length(failures)} unsupported -> #{report_path}"
    )
  end

  defp import_source(kind, re_dir) do
    src = Path.join(re_dir, "item_db_#{kind}.yml")
    results = src |> read_body!() |> Enum.map(&transpile_entry/1)
    definitions = Enum.map(results, &elem(&1, 0))
    failures = results |> Enum.map(&elem(&1, 1)) |> Enum.reject(&is_nil/1)
    transpiled = Enum.count(definitions, &(&1.on_use != nil))
    yaml = definitions |> Enum.map(&Importer.to_yaml_map/1) |> Ymlr.document!()
    out = Path.join(@out_dir, "#{kind}.yml")
    File.write!(out, yaml)
    Mix.shell().info("#{kind}: #{length(definitions)} items -> #{out}")
    {transpiled, failures}
  end

  defp transpile_entry(entry) do
    apply_transpile(to_definition!(entry), Map.get(entry, "Script"))
  end

  @doc false
  @spec apply_transpile(ItemDefinition.t(), String.t() | nil) ::
          {ItemDefinition.t(), failure() | nil}
  def apply_transpile(%ItemDefinition{type: type} = definition, script)
      when type in [:usable, :healing] and is_binary(script) do
    case Transpiler.transpile(script) do
      {:ok, dsl} -> {%{definition | on_use: dsl}, nil}
      {:error, reason} -> {definition, {definition.id, definition.name, reason}}
    end
  end

  def apply_transpile(%ItemDefinition{} = definition, _script), do: {definition, nil}

  @doc false
  @spec build_report([failure()]) :: String.t()
  def build_report([]) do
    "# Transpile report\n\nAll usable item scripts transpiled.\n"
  end

  def build_report(failures) do
    rows =
      Enum.map_join(failures, "\n", fn {id, name, reason} ->
        "| #{id} | #{name} | #{inspect(reason)} |"
      end)

    """
    # Transpile report

    | id | name | reason |
    | --- | --- | --- |
    #{rows}
    """
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
