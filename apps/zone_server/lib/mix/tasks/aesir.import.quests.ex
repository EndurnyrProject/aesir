defmodule Mix.Tasks.Aesir.Import.Quests do
  @shortdoc "Imports the selected rAthena quest DB into mode-scoped YAML"
  @moduledoc """
  Converts canonical `db/quest_db.yml` plus its selected mode imports into
  `apps/zone_server/priv/db/<mode>/quests/quests.yml`.

      mix aesir.import.quests [<rathena_root>] [--mode re|pre-re]

  `<rathena_root>` defaults to `../rathena`. Target `Mob`/`MapMobTargets`
  names and Drop `Mob`/`Item` names are resolved case-insensitively against
  the same mode's rAthena `mob_db` and `item_db`, and a target `Location`
  against `db/map_index.txt`. Rows are read as
  `QuestManagement.Importer` describes: a refused target skips the whole
  quest, a refused drop row or `MapMobTargets` name skips only itself, and
  every skip is reported in the run summary.
  Deterministic and idempotent: re-running against the same rAthena checkout
  produces an identical file. Run only when syncing rAthena.
  """
  use Mix.Task

  alias Mix.Tasks.Aesir.Import

  alias Aesir.ZoneServer.Mmo.QuestManagement.Importer

  @impl Mix.Task
  def run(args) do
    {rathena, mode} = Import.parse!(args)
    out_dir = Import.path("quests", mode)
    src = Path.join([rathena, "db", "quest_db.yml"])
    File.mkdir_p!(out_dir)

    resolvers = source_resolvers(rathena, mode)

    {definitions, dropped} =
      src
      |> Import.read_mode_filtered!(mode)
      |> Enum.map(&Importer.to_definition(&1, resolvers))
      |> Enum.reduce({[], []}, fn {definition, entry_dropped}, {defs, dropped} ->
        {[definition | defs], dropped ++ entry_dropped}
      end)
      |> then(fn {defs, dropped} ->
        {defs |> Enum.reverse() |> Enum.reject(&is_nil/1), dropped}
      end)

    yaml = definitions |> Enum.map(&Importer.to_yaml_map/1) |> Ymlr.document!()
    out = Path.join(out_dir, "quests.yml")
    File.write!(out, yaml)

    Mix.shell().info("quests: #{length(definitions)} -> #{out}")
    report(dropped)
  end

  # Resolves names the way the reference does once its mob and item databases
  # and map index are loaded: a later row for the same id overrides the earlier
  # fields and names compare case-insensitively. The reference picks an
  # unspecified id for a monster name shared by several ids; the lowest id
  # stands in for it so the output stays deterministic. A map name has its
  # `.gat` extension stripped and is cut to 11 characters, and compares
  # case-sensitively.
  @spec source_resolvers(Path.t(), atom()) :: Importer.resolvers()
  defp source_resolvers(rathena, mode) do
    mobs =
      rathena
      |> rows_by_id("mob_db.yml", mode)
      |> Enum.sort_by(fn {id, _row} -> id end, :desc)
      |> Map.new(fn {id, row} -> {String.downcase(row["AegisName"]), id} end)

    items =
      rathena
      |> rows_by_id("item_db.yml", mode)
      |> Map.new(fn {id, row} ->
        type = row |> Map.get("Type", "Etc") |> String.downcase()
        stackable? = type not in ~w(weapon armor petegg petarmor shadowgear)
        {String.downcase(row["AegisName"]), %{id: id, stackable?: stackable?}}
      end)

    maps = map_index(rathena)

    %{
      mob: &Map.fetch(mobs, String.downcase(&1)),
      item: &Map.fetch(items, String.downcase(&1)),
      map?: &MapSet.member?(maps, map_name(&1))
    }
  end

  @spec map_index(Path.t()) :: MapSet.t(String.t())
  defp map_index(rathena) do
    [rathena, "db", "map_index.txt"]
    |> Path.join()
    |> File.stream!()
    |> Stream.reject(&String.starts_with?(&1, "//"))
    |> Stream.map(&(&1 |> String.split() |> List.first()))
    |> Stream.reject(&is_nil/1)
    |> MapSet.new(&map_name/1)
  end

  @spec map_name(String.t()) :: String.t()
  defp map_name(name) do
    name
    |> String.replace(~r/\.gat$/i, "")
    |> String.slice(0, 11)
  end

  @spec rows_by_id(Path.t(), String.t(), atom()) :: %{integer() => map()}
  defp rows_by_id(rathena, file, mode) do
    [rathena, "db", file]
    |> Path.join()
    |> Import.read_mode_filtered!(mode)
    |> Enum.reduce(%{}, fn row, acc ->
      Map.update(acc, Map.fetch!(row, "Id"), row, &Map.merge(&1, row))
    end)
  end

  defp report([]), do: :ok

  defp report(dropped) do
    Mix.shell().info("  dropped #{length(dropped)} refused quest/target/drop reference(s):")

    Enum.each(dropped, fn {quest_id, kind, name} ->
      Mix.shell().info("    quest #{quest_id} #{kind}: #{inspect(name)}")
    end)
  end
end
