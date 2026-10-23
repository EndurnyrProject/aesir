defmodule Mix.Tasks.Aesir.Import.RandomOptions do
  @shortdoc "Imports rAthena item random options and their groups into mode-scoped YAML"
  @moduledoc """
  Converts `db/item_randomopt_db.yml` and `db/item_randomopt_group.yml`, with
  their selected mode imports, into
  `apps/zone_server/priv/db/<mode>/random_options/{options,groups}.yml`.

      mix aesir.import.random_options [<rathena_root>] [--mode re|pre-re]

  Rows follow the reference loaders: a repeated id merges the fields it sets
  into the earlier row, a new row needs its name (and an option its script),
  and a name another id already uses skips the row. A group row is dropped
  when one of its options names an unknown option, a `MinValue`, `MaxValue` or
  `Param` is outside the 16-bit range, a slot number is outside 1..5, a chance
  is outside 1..10000, or `MaxRandom` is not an unsigned 16-bit value; an
  existing group keeps what the failed row applied before the failure. A slot
  past the fifth is ignored, `MaxRandom` is capped to 5, a `Param` is stored in
  8 bits and an option's `MaxValue` below its `MinValue` becomes `MinValue + 1`
  (wrapping in 16 bits). Group options refer to options by id.

  Option scripts go through the equip-script transpiler with
  `getrandomoptinfo` reading the running option. A script it cannot express is
  kept as a row without a program and listed in the report. A group whose
  slots are not numbered 1..n, that has a slot without options, or that may
  draw from an empty random list, has no defined reference behaviour and
  aborts the import.

  Output is deterministic: rows sorted by id.
  """
  use Mix.Task

  alias Aesir.ZoneServer.Mmo.ItemManagement.EquipScript
  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.Transpiler
  alias Mix.Tasks.Aesir.Import

  @max_options 5
  @max_chance 10_000

  @typedoc "What the import kept out or could not express, by row."
  @type report :: %{
          skipped_options: [{integer() | nil, String.t()}],
          unsupported_scripts: [{integer(), String.t(), term()}],
          skipped_groups: [{integer() | nil, String.t()}]
        }

  @impl Mix.Task
  @spec run([String.t()]) :: :ok
  def run(args) do
    {source_root, mode} = Import.parse!(args)
    option_rows = read_source!(source_root, "item_randomopt_db.yml", mode)
    group_rows = read_source!(source_root, "item_randomopt_group.yml", mode)
    {options, groups, report} = convert(option_rows, group_rows)

    write!(Import.path("random_options/options.yml", mode), options)
    write!(Import.path("random_options/groups.yml", mode), groups)
    print_report(options, groups, report)
  end

  @doc """
  Converts the selected option and group source rows into the output rows and
  the report, in source order.
  """
  @spec convert([map()], [map()]) :: {[map()], [map()], report()}
  def convert(option_rows, group_rows) do
    {options, skipped_options} = Enum.reduce(option_rows, {%{}, []}, &merge_option/2)
    {option_out, unsupported} = option_output(options)
    names = Map.new(options, fn {id, option} -> {option.name, id} end)
    {groups, skipped_groups} = Enum.reduce(group_rows, {%{}, []}, &merge_group(&1, &2, names))

    {option_out, Enum.map(Enum.sort(groups), &group_output/1),
     %{
       skipped_options: Enum.reverse(skipped_options),
       unsupported_scripts: unsupported,
       skipped_groups: Enum.reverse(skipped_groups)
     }}
  end

  defp merge_option(row, {options, skipped}) do
    id = row["Id"]
    existing = Map.get(options, id)
    name = Map.get(row, "Option", existing && existing.name)
    script = Map.get(row, "Script", existing && existing.script)

    cond do
      not is_integer(id) ->
        {options, [{id, "missing Id"} | skipped]}

      is_nil(existing) and (is_nil(row["Option"]) or is_nil(row["Script"])) ->
        {options, [{id, "missing Option or Script"} | skipped]}

      name_taken?(options, id, name, & &1.name) ->
        {options, [{id, "duplicate option name #{name}"} | skipped]}

      true ->
        {Map.put(options, id, %{name: name, script: script}), skipped}
    end
  end

  defp option_output(options) do
    options
    |> Enum.sort()
    |> Enum.map_reduce([], fn {id, %{name: name, script: script}}, unsupported ->
      case Transpiler.transpile_equip(script) do
        {:ok, program} ->
          {%{"id" => id, "name" => name, "script" => EquipScript.to_source(program)}, unsupported}

        {:error, reason} ->
          {%{"id" => id, "name" => name, "script" => nil}, [{id, name, reason} | unsupported]}
      end
    end)
    |> then(fn {rows, unsupported} -> {rows, Enum.reverse(unsupported)} end)
  end

  defp merge_group(row, {groups, skipped}, names) do
    id = row["Id"]
    existing = Map.get(groups, id)

    cond do
      not is_integer(id) ->
        {groups, [{id, "missing Id"} | skipped]}

      is_nil(existing) and is_nil(row["Group"]) ->
        {groups, [{id, "missing Group"} | skipped]}

      true ->
        base = existing || %{name: nil, slots: %{}, max_random: 0, random: []}

        case apply_group(row, base, groups, id, names) do
          {:ok, group} ->
            {Map.put(groups, id, group), skipped}

          {:error, partial, reason} ->
            {keep_partial(groups, id, existing, partial), [{id, reason} | skipped]}
        end
    end
  end

  # A row that fails part-way keeps the fields an existing group already took
  # from it, as the reference loader mutates the stored row in place; a new
  # group is never stored.
  defp keep_partial(groups, _id, nil, _partial), do: groups
  defp keep_partial(groups, id, _existing, partial), do: Map.put(groups, id, partial)

  defp apply_group(row, group, groups, id, names) do
    with {:ok, group} <- group_name(row, group, groups, id),
         {:ok, group} <- group_slots(row, group, names),
         {:ok, group} <- group_max_random(row, group) do
      group_random(row, group, names)
    end
  end

  defp group_name(%{"Group" => name}, group, groups, id) do
    if name_taken?(groups, id, name, & &1.name),
      do: {:error, group, "duplicate group name #{name}"},
      else: {:ok, %{group | name: name}}
  end

  defp group_name(_row, group, _groups, _id), do: {:ok, group}

  defp group_slots(%{"Slots" => slots}, group, names) when is_list(slots) do
    Enum.reduce_while(slots, {:ok, group}, fn slot, {:ok, group} ->
      cond do
        map_size(group.slots) >= @max_options ->
          {:halt, {:ok, group}}

        slot["Slot"] not in 1..@max_options ->
          {:halt, {:error, group, "invalid slot #{inspect(slot["Slot"])}"}}

        not is_list(slot["Options"]) ->
          {:halt, {:error, group, "slot #{slot["Slot"]} has no Options"}}

        true ->
          put_slot(group, slot, names)
      end
    end)
  end

  defp group_slots(_row, group, _names), do: {:ok, group}

  defp put_slot(group, slot, names) do
    case entries(slot["Options"], names) do
      {:ok, entries} -> {:cont, {:ok, put_in(group.slots[slot["Slot"]], entries)}}
      {:error, _parsed, reason} -> {:halt, {:error, group, reason}}
    end
  end

  defp group_max_random(%{"MaxRandom" => max}, group) when max in 0..65_535,
    do: {:ok, %{group | max_random: min(max, @max_options)}}

  defp group_max_random(%{"MaxRandom" => max}, group),
    do: {:error, group, "invalid MaxRandom #{inspect(max)}"}

  defp group_max_random(_row, group), do: {:ok, group}

  # The reference clears the list and appends each entry as it parses, so a
  # failed entry leaves the ones before it.
  defp group_random(%{"Random" => random}, group, names) when is_list(random) do
    case entries(random, names) do
      {:ok, entries} -> {:ok, %{group | random: entries}}
      {:error, parsed, reason} -> {:error, %{group | random: parsed}, reason}
    end
  end

  defp group_random(_row, group, _names), do: {:ok, group}

  defp entries(options, names) do
    Enum.reduce_while(options, {:ok, []}, fn option, {:ok, acc} ->
      case entry(option, names) do
        {:ok, entry} -> {:cont, {:ok, [entry | acc]}}
        {:error, reason} -> {:halt, {:error, Enum.reverse(acc), reason}}
      end
    end)
    |> case do
      {:ok, acc} -> {:ok, Enum.reverse(acc)}
      error -> error
    end
  end

  defp entry(option, names) do
    with {:ok, id} <- option_id(option, names),
         {:ok, min_value} <- int16(option, "MinValue"),
         {:ok, max_value} <- int16(option, "MaxValue"),
         {:ok, param} <- int16(option, "Param"),
         {:ok, chance} <- chance(option) do
      {:ok,
       %{
         "option" => id,
         "min" => min_value,
         "max" => if(min_value > max_value, do: int16_wrap(min_value + 1), else: max_value),
         "param" => int8(param),
         "chance" => chance
       }}
    end
  end

  defp int16(option, key) do
    case Map.get(option, key, 0) do
      value when value in -32_768..32_767 -> {:ok, value}
      value -> {:error, "invalid #{key} #{inspect(value)}"}
    end
  end

  defp int16_wrap(value) do
    <<cast::signed-16>> = <<value::16>>
    cast
  end

  # The parameter is read as a 16-bit value and stored in an 8-bit field.
  defp int8(value) do
    <<cast::signed-8>> = <<value::8>>
    cast
  end

  defp option_id(%{"Option" => name}, names) do
    case Map.fetch(names, name) do
      {:ok, id} -> {:ok, id}
      :error -> {:error, "unknown option #{name}"}
    end
  end

  defp option_id(_option, _names), do: {:error, "missing Option"}

  defp chance(%{"Chance" => chance}) when chance in 1..@max_chance, do: {:ok, chance}
  defp chance(%{"Chance" => chance}), do: {:error, "invalid chance #{inspect(chance)}"}
  defp chance(_option), do: {:ok, 0}

  defp name_taken?(rows, id, name, name_of),
    do: Enum.any?(rows, fn {other, row} -> other != id and name_of.(row) == name end)

  defp group_output({id, group}) do
    slot_numbers = group.slots |> Map.keys() |> Enum.sort()

    unless slot_numbers == Enum.to_list(1..length(slot_numbers)//1) do
      Mix.raise("random option group #{id}: slots #{inspect(slot_numbers)} are not 1..n")
    end

    if Enum.any?(Map.values(group.slots), &(&1 == [])) do
      Mix.raise("random option group #{id}: a slot has no options")
    end

    if group.max_random > 0 and group.random == [] do
      Mix.raise("random option group #{id}: MaxRandom #{group.max_random} with no Random list")
    end

    %{
      "id" => id,
      "name" => group.name,
      "slots" => Enum.map(slot_numbers, &Map.fetch!(group.slots, &1)),
      "max_random" => group.max_random,
      "random" => group.random
    }
  end

  defp read_source!(source_root, file, mode) do
    [source_root, "db", file]
    |> Path.join()
    |> Import.read_mode_filtered!(mode)
  end

  defp write!(path, rows) do
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, Ymlr.document!(rows, sort_maps: true))
  end

  defp print_report(options, groups, report) do
    shell = Mix.shell()

    shell.info(
      "random_options: #{length(options)} options " <>
        "(#{length(report.unsupported_scripts)} without a program), #{length(groups)} groups"
    )

    for {id, name, reason} <- report.unsupported_scripts,
        do: shell.info("  unsupported script #{id} #{name}: #{inspect(reason)}")

    for {id, reason} <- report.skipped_options,
        do: shell.info("  skipped option #{inspect(id)}: #{reason}")

    for {id, reason} <- report.skipped_groups,
        do: shell.info("  skipped group #{inspect(id)}: #{reason}")

    :ok
  end
end
