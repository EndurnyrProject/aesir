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

  alias Aesir.ZoneServer.Npc.Transpiler.Parser
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
    equip_script = Map.get(entry, "EquipScript")
    unequip_script = Map.get(entry, "UnEquipScript")
    lifecycle_candidate? = lifecycle_candidate?(equip_script)

    {definition, failure} =
      apply_transpile(to_definition!(entry), script, equip_script, unequip_script)

    scripts =
      hook_scripts(definition.type, script, equip_script, unequip_script, lifecycle_candidate?)

    {definition, scripts, failure}
  end

  defp hook_scripts(type, script, _equip_script, _unequip_script, _lifecycle_candidate?)
       when type in @usable_types,
       do: %{on_use: script}

  defp hook_scripts(type, script, equip_script, unequip_script, lifecycle_candidate?)
       when type in @equip_types do
    on_equip =
      cond do
        is_binary(script) -> script
        lifecycle_candidate? -> equip_script
        true -> nil
      end

    %{
      on_equip: on_equip,
      on_unequip: if(lifecycle_candidate?, do: unequip_script),
      lifecycle_candidate?: lifecycle_candidate?
    }
  end

  defp hook_scripts(_type, _script, _equip_script, _unequip_script, _lifecycle_candidate?),
    do: %{}

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
      when type in @equip_types and is_binary(script),
      do: transpile_ordinary_equipment(definition, script)

  def apply_transpile(%ItemDefinition{} = definition, _script), do: {definition, nil}

  defp transpile_ordinary_equipment(definition, script) do
    case Transpiler.transpile_equip(script) do
      {:ok, []} -> {definition, nil}
      {:ok, program} -> {%{definition | on_equip: program}, nil}
      {:error, reason} -> {definition, failure(definition, :on_equip, reason)}
    end
  end

  @doc false
  @spec apply_transpile(
          ItemDefinition.t(),
          String.t() | nil,
          String.t() | nil,
          String.t() | nil
        ) :: {ItemDefinition.t(), Importer.failure() | nil}
  def apply_transpile(
        %ItemDefinition{type: type} = definition,
        script,
        equip_script,
        unequip_script
      )
      when type in @equip_types do
    ordinary_result =
      if is_binary(script),
        do: transpile_ordinary_equipment(definition, script),
        else: {definition, nil}

    case ordinary_result do
      {definition, nil} -> maybe_apply_lifecycle(definition, equip_script, unequip_script)
      {_definition, _failure} = result -> result
    end
  end

  def apply_transpile(%ItemDefinition{} = definition, script, _equip_script, _unequip_script),
    do: apply_transpile(definition, script)

  defp maybe_apply_lifecycle(definition, equip_script, unequip_script) do
    if lifecycle_candidate?(equip_script),
      do: apply_lifecycle(definition, equip_script, unequip_script),
      else: {definition, nil}
  end

  defp lifecycle_candidate?(script) when is_binary(script) do
    case Parser.parse_body(script) do
      {:ok, ast} -> lifecycle_status_start?(ast)
      {:error, _reason} -> lifecycle_status_start_token?(script)
    end
  end

  defp lifecycle_candidate?(_script), do: false

  defp lifecycle_status_start_token?(script) do
    ~r{//[^\r\n]*|/\*.*?(?:\*/|\z)|"(?:\\.|[^"\\])*(?:"|\z)|[A-Za-z_][A-Za-z0-9_]*}s
    |> Regex.scan(script, capture: :first)
    |> Enum.any?(fn [token] -> String.downcase(token) == "sc_start" end)
  end

  defp lifecycle_status_start?({:cmd, command, _args}),
    do: String.downcase(command) == "sc_start"

  defp lifecycle_status_start?(value) when is_tuple(value),
    do: value |> Tuple.to_list() |> lifecycle_status_start?()

  defp lifecycle_status_start?(value) when is_list(value),
    do: Enum.any?(value, &lifecycle_status_start?/1)

  defp lifecycle_status_start?(_value), do: false

  defp apply_lifecycle(definition, equip_script, unequip_script) do
    with {:ok, equip_program} <- transpile_hook(equip_script, :on_equip, :equip),
         :ok <- validate_flat_lifecycle(equip_program, :on_equip, :status_start),
         {:ok, unequip_program} <- transpile_hook(unequip_script, :on_unequip, :unequip),
         :ok <- validate_flat_lifecycle(unequip_program, :on_unequip, :status_end),
         :ok <- validate_status_lifecycle(equip_program, unequip_program) do
      on_equip = List.wrap(definition.on_equip) ++ equip_program

      {%{
         definition
         | on_equip: empty_to_nil(on_equip),
           on_unequip: empty_to_nil(unequip_program)
       }, nil}
    else
      {:error, {hook, reason}} -> {definition, failure(definition, hook, reason)}
    end
  end

  defp transpile_hook(script, hook, context) when is_binary(script) do
    case Transpiler.transpile_equip(script, context) do
      {:ok, program} -> {:ok, program}
      {:error, reason} -> {:error, {hook, reason}}
    end
  end

  defp transpile_hook(_script, _hook, _context), do: {:ok, []}

  defp validate_flat_lifecycle(program, hook, allowed) do
    case Enum.find(program, &(not lifecycle_instruction?(&1, allowed))) do
      nil ->
        :ok

      instruction ->
        {:error,
         {hook,
          {:unsupported,
           {:non_flat_status_lifecycle, %{allowed: allowed, instruction: instruction}}}}}
    end
  end

  defp lifecycle_instruction?({:status_start, _status, _duration, _value}, :status_start),
    do: true

  defp lifecycle_instruction?({:status_end, _status}, :status_end), do: true
  defp lifecycle_instruction?(_instruction, _allowed), do: false

  defp validate_status_lifecycle(on_equip, on_unequip) do
    starts = status_ids(on_equip, :start)
    ends = status_ids(on_unequip, :end)

    if starts == ends,
      do: :ok,
      else:
        {:error,
         {:on_unequip,
          {:unsupported, {:status_lifecycle_mismatch, %{on_equip: starts, on_unequip: ends}}}}}
  end

  defp status_ids(program, :start) do
    program
    |> Enum.map(fn {:status_start, status, _duration, _value} -> status end)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp status_ids(program, :end) do
    program
    |> Enum.map(fn {:status_end, status} -> status end)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp empty_to_nil([]), do: nil
  defp empty_to_nil(program), do: program

  defp failure(definition, hook, reason), do: {hook, definition.id, definition.name, reason}

  @spec summarize([{ItemDefinition.t(), map(), Importer.failure() | nil}]) :: Importer.report()
  defp summarize(entries) do
    base = %{on_use: blank_hook(), on_equip: blank_hook(), on_unequip: blank_hook()}
    stats = Enum.reduce(entries, base, &tally/2)
    failures = entries |> Enum.map(&elem(&1, 2)) |> Enum.reject(&is_nil/1)
    Map.put(stats, :failures, failures)
  end

  defp blank_hook, do: %{considered: 0, with_script: 0, transpiled: 0}

  defp tally({%ItemDefinition{type: type} = definition, scripts, _failure}, acc)
       when type in @usable_types do
    tally_hook(acc, definition, scripts, :on_use)
  end

  defp tally({%ItemDefinition{type: type} = definition, scripts, _failure}, acc)
       when type in @equip_types do
    acc = tally_hook(acc, definition, scripts, :on_equip)

    if scripts.lifecycle_candidate?,
      do: tally_hook(acc, definition, scripts, :on_unequip),
      else: acc
  end

  defp tally({_definition, _scripts, _failure}, acc), do: acc

  defp tally_hook(acc, definition, scripts, hook) do
    Map.update!(acc, hook, fn stats ->
      %{
        considered: stats.considered + 1,
        with_script: stats.with_script + count_if(is_binary(Map.fetch!(scripts, hook))),
        transpiled: stats.transpiled + count_if(transpiled?(definition, hook))
      }
    end)
  end

  defp transpiled?(%ItemDefinition{on_use: on_use}, :on_use), do: on_use != nil
  defp transpiled?(%ItemDefinition{on_equip: on_equip}, :on_equip), do: on_equip != nil
  defp transpiled?(%ItemDefinition{on_unequip: on_unequip}, :on_unequip), do: on_unequip != nil

  defp count_if(true), do: 1
  defp count_if(false), do: 0

  defp summary_line(
         %{on_use: on_use, on_equip: on_equip, on_unequip: on_unequip, failures: failures},
         report_path
       ) do
    failure_counts = Enum.frequencies_by(failures, &elem(&1, 0))

    "on_use #{on_use.transpiled}/#{on_use.with_script} transpiled " <>
      "(#{Map.get(failure_counts, :on_use, 0)} unsupported), " <>
      "on_equip #{on_equip.transpiled}/#{on_equip.with_script} transpiled " <>
      "(#{Map.get(failure_counts, :on_equip, 0)} unsupported), " <>
      "on_unequip #{on_unequip.transpiled}/#{on_unequip.with_script} transpiled " <>
      "(#{Map.get(failure_counts, :on_unequip, 0)} unsupported) -> #{report_path}"
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
