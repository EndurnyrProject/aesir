defmodule Mix.Tasks.Aesir.Import.LevelPenalty do
  @shortdoc "Imports the rAthena renewal drop/exp level-penalty tables into priv/db"
  @moduledoc """
  One-time importer: extracts the `Type: Drop`, `Type: Exp`, `Type: Mvp_Drop`
  and `Type: Mvp_Exp` penalties from rAthena's renewal `db/re/level_penalty.yml`
  and writes them as our own-schema `apps/zone_server/priv/db/level_penalty.yml`,
  `apps/zone_server/priv/db/level_penalty_exp.yml`,
  `apps/zone_server/priv/db/level_penalty_mvp_drop.yml` and
  `apps/zone_server/priv/db/level_penalty_mvp_exp.yml`, flat `level_difference
  => percent` mappings consumed by `Aesir.ZoneServer.Mmo.ItemDrop.LevelPenalty`.

      mix aesir.import.level_penalty [<rathena_root>]

  `<rathena_root>` defaults to `../rathena`. A type absent from the source
  (the shipped rAthena database currently defines no MVP-specific breakpoints)
  writes an empty table, which `LevelPenalty` already resolves to a rate of
  100 at every level difference. Output is sorted by level difference so
  re-running yields no diff.
  """
  use Mix.Task

  @out_file Path.join(~w(apps zone_server priv db level_penalty.yml))
  @exp_out_file Path.join(~w(apps zone_server priv db level_penalty_exp.yml))
  @mvp_drop_out_file Path.join(~w(apps zone_server priv db level_penalty_mvp_drop.yml))
  @mvp_exp_out_file Path.join(~w(apps zone_server priv db level_penalty_mvp_exp.yml))
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
    write_table!(table_for(body, "Mvp_Drop"), @mvp_drop_out_file, "mvp_drop")
    write_table!(table_for(body, "Mvp_Exp"), @mvp_exp_out_file, "mvp_exp")
  end

  # `Mvp_Drop`/`Mvp_Exp` are documented by the source schema but ship with no
  # entries, so an absent table is expected and yields no penalty. `Drop`/`Exp`
  # are required: a resync that renames or restructures them must fail loudly
  # rather than silently emit an empty table and disable the penalty worldwide.
  @optional_types ~w(Mvp_Drop Mvp_Exp)

  @spec table_for(map(), String.t()) :: %{integer() => integer()}
  def table_for(%{"Body" => body}, type) do
    case {Enum.find(body, &(&1["Type"] == type)), type in @optional_types} do
      {%{"LevelDifferences" => diffs}, _optional?} ->
        Map.new(diffs, fn %{"Difference" => d, "Rate" => r} -> {d, r} end)

      {nil, true} ->
        %{}

      {nil, false} ->
        raise "level_penalty: required table #{type} missing from source"
    end
  end

  @spec write_table!(%{integer() => integer()}, String.t(), String.t()) :: :ok
  defp write_table!(table, out_file, label) do
    File.mkdir_p!(Path.dirname(out_file))
    File.write!(out_file, Ymlr.document!(table, sort_maps: true))

    Mix.shell().info("level_penalty: wrote #{map_size(table)} #{label} entries -> #{out_file}")
  end
end
