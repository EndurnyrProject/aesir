defmodule Mix.Tasks.Aesir.Import.Statpoint do
  @shortdoc "Imports selected rAthena stat points into mode-scoped YAML"
  @moduledoc """
  Converts canonical `db/statpoint.yml` plus its selected mode import into
  `apps/zone_server/priv/db/<mode>/statpoint/statpoint.yml`.

      mix aesir.import.statpoint [<rathena_root>] [--mode re|pre-re]

  `<rathena_root>` defaults to `../rathena`. Both columns are cumulative totals
  from base level 1 to that level: `Points` (status points) and `TraitPoints`
  (4th-job trait points). rAthena omits `TraitPoints` below level 201; the
  missing value carries the previous entry forward, so it is 0 through level 200.
  Output is one `%{points, trait_points}` map per level (deterministic, so
  re-running yields no diff).
  """
  use Mix.Task

  alias Mix.Tasks.Aesir.Import

  @impl Mix.Task
  def run(args) do
    {rathena, mode} = Import.parse!(args)
    out_file = Import.path("statpoint", mode) |> Path.join("statpoint.yml")

    entries =
      rathena
      |> Path.join("db/statpoint.yml")
      |> Import.read_mode_filtered!(mode)
      |> then(&entries_from_body(%{"Body" => &1}))

    File.mkdir_p!(Path.dirname(out_file))
    File.write!(out_file, Ymlr.document!(entries, sort_maps: true))

    Mix.shell().info("statpoint: wrote #{length(entries)} levels -> #{out_file}")
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
