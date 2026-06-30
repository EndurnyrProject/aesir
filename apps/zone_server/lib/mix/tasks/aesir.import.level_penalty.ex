defmodule Mix.Tasks.Aesir.Import.LevelPenalty do
  @shortdoc "Imports the rAthena renewal drop level-penalty table into priv/db/level_penalty.yml"
  @moduledoc """
  One-time importer: extracts the `Type: Drop` penalties from rAthena's renewal
  `db/re/level_penalty.yml` and writes them as our own-schema
  `apps/zone_server/priv/db/level_penalty.yml`, a flat `level_difference => percent`
  mapping consumed by `Aesir.ZoneServer.Mmo.ItemDrop.LevelPenalty`.

      mix aesir.import.level_penalty [<rathena_root>]

  `<rathena_root>` defaults to `../rathena`. Only `Type: Drop` is kept (Exp,
  Mvp_Exp and Mvp_Drop are out of scope). Output is sorted by level difference so
  re-running yields no diff.
  """
  use Mix.Task

  @out_file Path.join(~w(apps zone_server priv db level_penalty.yml))
  @source Path.join(~w(db re level_penalty.yml))

  @impl Mix.Task
  def run(args) do
    rathena = List.first(args) || "../rathena"

    table =
      rathena
      |> Path.join(@source)
      |> YamlElixir.read_from_file!()
      |> drop_table()

    File.mkdir_p!(Path.dirname(@out_file))
    File.write!(@out_file, Ymlr.document!(table, sort_maps: true))

    Mix.shell().info("level_penalty: wrote #{map_size(table)} drop entries -> #{@out_file}")
  end

  @spec drop_table(map()) :: %{integer() => integer()}
  defp drop_table(%{"Body" => body}) do
    %{"LevelDifferences" => diffs} = Enum.find(body, &(&1["Type"] == "Drop"))
    Map.new(diffs, fn %{"Difference" => d, "Rate" => r} -> {d, r} end)
  end
end
