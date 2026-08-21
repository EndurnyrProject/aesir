defmodule Mix.Tasks.Aesir.Import.Statpoint do
  @shortdoc "Imports the rAthena renewal statpoint.yml into priv/db/re/statpoint/statpoint.yml"
  @moduledoc """
  One-time importer: converts rAthena's renewal `db/re/statpoint.yml` (schema v2)
  into our own-schema `apps/zone_server/priv/db/re/statpoint/statpoint.yml`.

      mix aesir.import.statpoint [<rathena_root>]

  `<rathena_root>` defaults to `../rathena`. Both columns are cumulative totals
  from base level 1 to that level: `Points` (status points) and `TraitPoints`
  (4th-job trait points). rAthena omits `TraitPoints` below level 201; the
  missing value carries the previous entry forward, so it is 0 through level 200.
  Output is one `%{points, trait_points}` map per level (deterministic, so
  re-running yields no diff).
  """
  use Mix.Task

  @out_file Path.join(~w(apps zone_server priv db statpoint statpoint.yml))
  @source Path.join(~w(db re statpoint.yml))

  @impl Mix.Task
  def run(args) do
    rathena = List.first(args) || "../rathena"

    entries =
      rathena
      |> Path.join(@source)
      |> YamlElixir.read_from_file!()
      |> entries_from_body()

    File.mkdir_p!(Path.dirname(@out_file))
    File.write!(@out_file, Ymlr.document!(entries, sort_maps: true))

    Mix.shell().info("statpoint: wrote #{length(entries)} levels -> #{@out_file}")
  end

  @spec entries_from_body(map()) :: [map()]
  def entries_from_body(%{"Body" => body}) do
    body
    |> Enum.sort_by(&Map.fetch!(&1, "Level"))
    |> Enum.map_reduce(0, fn row, prev_trait ->
      trait = Map.get(row, "TraitPoints", prev_trait)
      {%{"points" => Map.fetch!(row, "Points"), "trait_points" => trait}, trait}
    end)
    |> elem(0)
  end
end
