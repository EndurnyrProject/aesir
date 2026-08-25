defmodule Mix.Tasks.Aesir.Import.Items do
  @shortdoc "Imports the selected rAthena item DB into mode-scoped YAML"
  @moduledoc """
  Converts canonical `db/item_db.yml` plus its selected mode imports into
  `apps/zone_server/priv/db/<mode>/items/*.yml`. The selected
  `db/item_group_db.yml` supplies item-group symbols during transpilation.

      mix aesir.import.items [<rathena_root>] [--mode re|pre-re]

  `<rathena_root>` defaults to `../rathena`. Output is flat and deterministic;
  unmapped data fails loudly.
  """
  use Mix.Task

  alias Mix.Tasks.Aesir.Import

  alias Aesir.ZoneServer.Mmo.ItemManagement.Importer
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.Resolver
  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.Transpiler

  @equip_types [:armor, :weapon, :shadow_gear, :ammo]
  # A delay-consume item (converters, boxes, cast-on-use consumables) carries the
  # same `Script` an ordinary usable does - it only differs in the cast delay -
  # so it transpiles to `on_use` alongside them.
  @usable_types [:usable, :healing, :delay_consume]

  @sources [:usable, :equip, :etc]
  @source_kinds %{
    "healing" => :usable,
    "usable" => :usable,
    "delayconsume" => :usable,
    "cash" => :usable,
    "weapon" => :equip,
    "armor" => :equip,
    "petegg" => :equip,
    "petarmor" => :equip,
    "shadowgear" => :equip,
    "ammo" => :etc,
    "card" => :etc,
    "etc" => :etc
  }

  @impl Mix.Task
  def run(args) do
    {rathena, mode} = Import.parse!(args)
    out_dir = Import.path("items", mode)
    item_rows = read_source!(rathena, "item_db.yml", mode)
    item_group_rows = read_source!(rathena, "item_group_db.yml", mode)
    source_catalogs = Resolver.source_catalogs(item_rows, item_group_rows)
    File.mkdir_p!(out_dir)

    entries =
      Resolver.with_source_catalogs(source_catalogs, fn ->
        Enum.flat_map(@sources, &import_source(&1, item_rows, out_dir))
      end)

    summary = summarize(entries)

    report_path = Path.join(out_dir, "_transpile_report.md")
    File.write!(report_path, Importer.build_report(summary))

    Mix.shell().info(summary_line(summary, report_path))
  end

  defp import_source(kind, rows, out_dir) do
    entries = rows |> Enum.filter(&(source_kind!(&1) == kind)) |> Enum.map(&transpile_entry/1)
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

  defp read_source!(rathena, file, mode) do
    [rathena, "db", file]
    |> Path.join()
    |> Import.read_mode_filtered!(mode)
  end

  defp source_kind!(entry) do
    type = entry |> Map.get("Type", "Etc") |> String.downcase()

    case Map.fetch(@source_kinds, type) do
      {:ok, kind} -> kind
      :error -> Mix.raise("unknown item source type #{inspect(entry["Type"])}")
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
