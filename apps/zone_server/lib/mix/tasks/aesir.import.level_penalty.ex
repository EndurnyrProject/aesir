defmodule Mix.Tasks.Aesir.Import.LevelPenalty do
  @shortdoc "Imports the rAthena renewal drop/exp level-penalty tables into priv/db"
  @moduledoc """
  One-time importer: extracts the `Type: Drop` and `Type: Exp` penalties from
  rAthena's renewal `db/re/level_penalty.yml` and writes them as our own-schema
  `apps/zone_server/priv/db/level_penalty.yml` and
  `apps/zone_server/priv/db/level_penalty_exp.yml`, flat `level_difference =>
  percent` mappings consumed by `Aesir.ZoneServer.Mmo.ItemDrop.LevelPenalty`.

      mix aesir.import.level_penalty [<rathena_root>]

  `<rathena_root>` defaults to `../rathena`. `Mvp_Exp` and `Mvp_Drop` are out of
  scope. Output is sorted by level difference so re-running yields no diff.
  """
  use Mix.Task

  @out_file Path.join(~w(apps zone_server priv db level_penalty.yml))
  @exp_out_file Path.join(~w(apps zone_server priv db level_penalty_exp.yml))
  @source Path.join(~w(db re level_penalty.yml))

  @impl Mix.Task
  def run(args) do
    rathena = List.first(args) || "../rathena"

    body =
      rathena
      |> Path.join(@source)
      |> YamlElixir.read_from_file!()

    write_table!(table_for(body, "Drop"), @out_file, "drop")
    write_table!(table_for(body, "Exp"), @exp_out_file, "exp")
  end

  @spec table_for(map(), String.t()) :: %{integer() => integer()}
  def table_for(%{"Body" => body}, type) do
    %{"LevelDifferences" => diffs} = Enum.find(body, &(&1["Type"] == type))
    Map.new(diffs, fn %{"Difference" => d, "Rate" => r} -> {d, r} end)
  end

  @spec write_table!(%{integer() => integer()}, String.t(), String.t()) :: :ok
  defp write_table!(table, out_file, label) do
    File.mkdir_p!(Path.dirname(out_file))
    File.write!(out_file, Ymlr.document!(table, sort_maps: true))

    Mix.shell().info("level_penalty: wrote #{map_size(table)} #{label} entries -> #{out_file}")
  end
end
