defmodule Mix.Tasks.Aesir.Import.Items do
  @shortdoc "Imports rAthena renewal item_db into priv/db/re/items/*.yml"
  @moduledoc """
  One-time importer: converts rAthena's renewal `item_db_{usable,equip,etc}.yml`
  into our own-schema YAML under `apps/zone_server/priv/db/re/items/`.

      mix aesir.import.items [<rathena_root>]

  `<rathena_root>` defaults to `../rathena`. Anchors/merge keys are expanded by
  the parser, so the output is fully flat. Fails loudly on unmapped data - this
  is a dev tool, run only when syncing rAthena.
  """
  use Mix.Task

  alias Mix.Tasks.Aesir.Import

  alias Aesir.ZoneServer.Mmo.ItemManagement.Importer
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.Transpiler

  @equip_types [:armor, :weapon, :shadow_gear, :ammo]
  # A delay-consume item (converters, boxes, cast-on-use consumables) carries the
  # same `Script` an ordinary usable does - it only differs in the cast delay -
  # so it transpiles to `on_use` alongside them.
  @usable_types [:usable, :healing, :delay_consume]

  @sources ~w(usable equip etc)

  @impl Mix.Task
  def run(args) do
    {rathena, mode} = Import.parse!(args)
    out_dir = Import.path("items", mode)
    re_dir = Path.join([rathena, "db", "re"])
    File.mkdir_p!(out_dir)

    entries = Enum.flat_map(@sources, &import_source(&1, re_dir, out_dir))
    summary = summarize(entries)

    report_path = Path.join(out_dir, "_transpile_report.md")
    File.write!(report_path, Importer.build_report(summary))

    Mix.shell().info(summary_line(summary, report_path))
  end

  defp import_source(kind, re_dir, out_dir) do
    src = Path.join(re_dir, "item_db_#{kind}.yml")
    entries = src |> read_body!() |> Enum.map(&transpile_entry/1)
    definitions = Enum.map(entries, &elem(&1, 0))
    yaml = definitions |> Enum.map(&Importer.to_yaml_map/1) |> Ymlr.document!()
    out = Path.join(out_dir, "#{kind}.yml")
    File.write!(out, yaml)
    Mix.shell().info("#{kind}: #{length(definitions)} items -> #{out}")
    entries
  end

  defp transpile_entry(entry) do
    script = Map.get(entry, "Script")
    {definition, failure} = apply_transpile(to_definition!(entry), script)
    {definition, script, failure}
  end

  @doc false
  @spec apply_transpile(ItemDefinition.t(), String.t() | nil) ::
          {ItemDefinition.t(), Importer.failure() | nil}
  def apply_transpile(%ItemDefinition{type: type} = definition, script)
      when type in @usable_types and is_binary(script) do
    case Transpiler.transpile(script) do
      {:ok, dsl} -> {%{definition | on_use: dsl}, nil}
      {:error, reason} -> {definition, {:on_use, definition.id, definition.name, reason}}
    end
  end

  def apply_transpile(%ItemDefinition{type: type} = definition, script)
      when type in @equip_types and is_binary(script) do
    case Transpiler.transpile_equip(script) do
      {:ok, []} -> {definition, nil}
      {:ok, program} -> {%{definition | on_equip: program}, nil}
      {:error, reason} -> {definition, {:on_equip, definition.id, definition.name, reason}}
    end
  end

  def apply_transpile(%ItemDefinition{} = definition, _script), do: {definition, nil}

  @spec summarize([{ItemDefinition.t(), String.t() | nil, Importer.failure() | nil}]) ::
          Importer.report()
  defp summarize(entries) do
    base = %{on_use: blank_hook(), on_equip: blank_hook()}
    stats = Enum.reduce(entries, base, &tally/2)
    failures = entries |> Enum.map(&elem(&1, 2)) |> Enum.reject(&is_nil/1)
    Map.put(stats, :failures, failures)
  end

  defp blank_hook, do: %{considered: 0, with_script: 0, transpiled: 0}

  defp tally({%ItemDefinition{type: type} = definition, script, _failure}, acc) do
    case hook_for_type(type) do
      nil ->
        acc

      hook ->
        Map.update!(acc, hook, fn stats ->
          %{
            considered: stats.considered + 1,
            with_script: stats.with_script + count_if(is_binary(script)),
            transpiled: stats.transpiled + count_if(transpiled?(definition, hook))
          }
        end)
    end
  end

  defp hook_for_type(type) when type in @usable_types, do: :on_use
  defp hook_for_type(type) when type in @equip_types, do: :on_equip
  defp hook_for_type(_type), do: nil

  defp transpiled?(%ItemDefinition{on_use: on_use}, :on_use), do: on_use != nil
  defp transpiled?(%ItemDefinition{on_equip: on_equip}, :on_equip), do: on_equip != nil

  defp count_if(true), do: 1
  defp count_if(false), do: 0

  defp summary_line(%{on_use: on_use, on_equip: on_equip, failures: failures}, report_path) do
    {on_use_failures, on_equip_failures} =
      Enum.split_with(failures, fn {hook, _id, _name, _reason} -> hook == :on_use end)

    "on_use #{on_use.transpiled}/#{on_use.with_script} transpiled " <>
      "(#{length(on_use_failures)} unsupported), " <>
      "on_equip #{on_equip.transpiled}/#{on_equip.with_script} transpiled " <>
      "(#{length(on_equip_failures)} unsupported) -> #{report_path}"
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
