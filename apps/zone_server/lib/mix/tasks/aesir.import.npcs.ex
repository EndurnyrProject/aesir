defmodule Mix.Tasks.Aesir.Import.Npcs do
  @shortdoc "Transpiles rAthena npc/re scripts into Elixir NPC modules"
  @moduledoc """
  Transpiles rAthena's renewal NPC scripts (`npc/re/**/*.txt`) into Elixir NPC
  modules under `apps/zone_server/lib/aesir/zone_server/content/npc/`.

      mix aesir.import.npcs [<rathena_root>] [--only <glob>]

  `<rathena_root>` defaults to `../rathena`. `--only` limits the run to source
  files matching the glob relative to `npc/re/` (e.g. `--only "cities/*"`).

  Re-runs are incremental and safe: a manifest
  (`apps/zone_server/priv/npc_transpile/manifest.json`) records the source and
  output hashes per entry; unchanged sources are skipped, changed sources with
  untouched output regenerate in place, and anything hand-edited (or colliding
  with a hand-written module) lands under `content/npc/_conflicts/` for manual
  merging. A full report is written to
  `apps/zone_server/priv/npc_transpile/_transpile_report.md`.
  """
  use Mix.Task

  alias Aesir.ZoneServer.Npc.Transpiler

  @report_path Path.join(~w(apps zone_server priv npc_transpile _transpile_report.md))

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.config")
    {opts, rest, _} = OptionParser.parse(args, strict: [only: :string])
    rathena = List.first(rest) || "../rathena"

    unless File.dir?(Path.join(rathena, "npc")) do
      Mix.raise("rAthena root not found at #{rathena} (no npc/ directory)")
    end

    result = Transpiler.run(rathena, only: opts[:only])

    File.mkdir_p!(Path.dirname(@report_path))
    File.write!(@report_path, report(result))

    Mix.shell().info(
      "npcs: #{length(result.written)} written, #{result.skipped} skipped, " <>
        "#{length(result.conflicts)} conflicts, #{length(result.failures)} failures " <>
        "-> #{@report_path}"
    )
  end

  defp report(result) do
    """
    # NPC transpile report

    ## Totals

    | metric | count |
    | --- | --- |
    | script/floating entries | #{result.totals.scripts} |
    | global functions | #{result.totals.functions} |
    | duplicate placements | #{result.totals.duplicates} |
    | written | #{length(result.written)} |
    | skipped (unchanged) | #{result.skipped} |
    | conflicts | #{length(result.conflicts)} |
    | failures | #{length(result.failures)} |

    ## Stubbed buildins by call sites

    Implementing one of these (DSL op + `CommandMap` entry) upgrades every
    affected NPC on the next run.

    | buildin | call sites |
    | --- | --- |
    #{stub_rows(result.stubs)}

    ## Conflicts

    #{conflict_rows(result.conflicts)}

    ## Failures

    #{failure_rows(result.failures)}

    ## Unresolved sprite constants (fell back to sprite #{46})

    #{list_or_none(result.unresolved_sprites)}

    ## Orphan duplicates (source NPC not in npc)

    #{list_or_none(result.orphan_duplicates)}

    ## Skipped statement types

    #{skipped_rows(result.skipped_types)}
    """
  end

  defp stub_rows(stubs) when map_size(stubs) == 0, do: "| - | - |"

  defp stub_rows(stubs) do
    stubs
    |> Enum.sort_by(&(-elem(&1, 1)))
    |> Enum.map_join("\n", fn {name, count} -> "| #{name} | #{count} |" end)
  end

  defp conflict_rows([]), do: "None."

  defp conflict_rows(conflicts) do
    Enum.map_join(conflicts, "\n", fn {original, conflict} ->
      "- `#{original}` -> `#{conflict}`"
    end)
  end

  defp failure_rows([]), do: "None."

  defp failure_rows(failures) do
    Enum.map_join(failures, "\n", fn {_kind, file, line, reason} ->
      "- `#{file}:#{line}` — #{inspect(reason) |> String.slice(0, 160)}"
    end)
  end

  defp list_or_none([]), do: "None."
  defp list_or_none(items), do: Enum.map_join(items, "\n", &"- `#{&1}`")

  defp skipped_rows(types) when map_size(types) == 0, do: "None."

  defp skipped_rows(types) do
    Enum.map_join(types, "\n", fn {type, count} -> "- #{type}: #{count}" end)
  end
end
