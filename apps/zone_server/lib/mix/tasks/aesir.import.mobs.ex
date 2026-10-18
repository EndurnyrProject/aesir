defmodule Mix.Tasks.Aesir.Import.Mobs do
  @shortdoc "Imports the selected rAthena mob DB into mode-scoped YAML"
  @moduledoc """
  Converts canonical `db/mob_db.yml` plus its selected mode imports into
  `apps/zone_server/priv/db/<mode>/mobs/mobs.yml` and the equipment-polymorph
  pool under `mob_summon/polymorph.yml`.

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

    definitions = src |> Import.read_mode_filtered!(mode) |> Enum.map(&to_definition!(&1, mode))
    yaml = definitions |> Enum.map(&Importer.to_yaml_map/1) |> Ymlr.document!()
    out = Path.join(out_dir, "mobs.yml")
    File.write!(out, yaml)
    Mix.shell().info("mobs: #{length(definitions)} -> #{out}")
    import_polymorph_pool(rathena, mode, definitions)
  end

  defp import_polymorph_pool(rathena, mode, definitions) do
    names = Map.new(definitions, &{&1.aegis_name, &1.id})

    groups =
      [rathena, "db", "mob_summon.yml"]
      |> Path.join()
      |> Import.read_mode_filtered!(mode)
      |> Enum.filter(&(String.downcase(&1["Group"]) == "branch_of_dead_tree"))

    {default, entries} =
      Enum.reduce(groups, {nil, %{}}, fn group, {default, entries} ->
        default = if group["Default"], do: Map.fetch!(names, group["Default"]), else: default
        entries = Enum.reduce(Map.get(group, "Summon", []), entries, &put_entry(&1, &2, names))
        {default, entries}
      end)

    if default == nil, do: Mix.raise("missing polymorph pool default")

    entries =
      entries |> Enum.sort() |> Enum.map(fn {id, rate} -> %{"id" => id, "rate" => rate} end)

    output = Import.path("mob_summon/polymorph.yml", mode)
    File.mkdir_p!(Path.dirname(output))
    File.write!(output, Ymlr.document!([%{"default" => default, "entries" => entries}]))
    Mix.shell().info("polymorph: #{length(entries)} -> #{output}")
  end

  defp put_entry(entry, acc, names) do
    id = Map.fetch!(names, entry["Mob"])
    rate = Map.fetch!(entry, "Rate")

    if rate == 0, do: Map.delete(acc, id), else: Map.put(acc, id, rate)
  end

  defp to_definition!(entry, mode) do
    case Importer.to_definition(entry, mode) do
      {:ok, definition} ->
        definition

      {:error, reason} ->
        Mix.raise("failed to import mob #{inspect(entry["Id"])}: #{inspect(reason)}")
    end
  end
end
