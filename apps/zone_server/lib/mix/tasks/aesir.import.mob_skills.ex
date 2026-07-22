defmodule Mix.Tasks.Aesir.Import.MobSkills do
  @shortdoc "Imports rAthena mob_skill_db into priv/db/mob_skills/mob_skills.yml"
  @moduledoc """
  One-time importer: converts rAthena's renewal `mob_skill_db.txt` into our own
  YAML at `apps/zone_server/priv/db/mob_skills/mob_skills.yml`, grouped by mob id.

      mix aesir.import.mob_skills [<rathena_root>]

  `<rathena_root>` defaults to `../rathena`. Global rows (`-1`/`-2`/`-3`) are
  written under the reserved keys `global_boss`/`global_normal`/`global_all` and
  expanded per-mob at load time, not baked here. Fails loudly on any token
  outside the rAthena header vocabulary - this is a dev tool, run only when
  syncing rAthena.

  After writing, it prints a coverage manifest: total rows, distinct skills, and
  which skills are `:castable` (resolve in the live skill catalog with an active
  module and are not denylisted), `:denylisted` (resolve but are denied, with the
  reason), or `:unresolved` (no catalog entry / no active module) - see
  `MobSkill.Importer.classify/1` - with the row-coverage %, the denylisted skills
  and their reasons, and the top unresolved skills by row count.
  """
  use Mix.Task

  alias Aesir.ZoneServer.Mmo.MobSkill.Importer

  @out_dir Path.join(~w(apps zone_server priv db mob_skills))
  @top_unresolved 20

  @impl Mix.Task
  def run(args) do
    rathena = List.first(args) || "../rathena"
    src = Path.join([rathena, "db", "re", "mob_skill_db.txt"])
    File.mkdir_p!(@out_dir)

    grouped =
      case Importer.to_rows(File.read!(src)) do
        {:ok, grouped} -> grouped
        {:error, reason} -> Mix.raise("failed to import mob skills: #{inspect(reason)}")
      end

    out = Path.join(@out_dir, "mob_skills.yml")
    File.write!(out, Ymlr.document!(grouped))

    Mix.shell().info("mob_skills: #{map_size(grouped)} mob keys -> #{out}")
    report(grouped)
  end

  @spec report(%{String.t() => [Importer.row()]}) :: :ok
  defp report(grouped) do
    rows = grouped |> Map.values() |> List.flatten()
    total = length(rows)
    skill_rows = Enum.group_by(rows, & &1.skill)

    classified =
      Enum.map(skill_rows, fn {skill, rows_for_skill} ->
        {skill, length(rows_for_skill), Importer.classify(hd(rows_for_skill).skill_id)}
      end)

    castable = Enum.filter(classified, fn {_s, _c, class} -> class == :castable end)

    denylisted =
      Enum.filter(classified, fn {_s, _c, class} -> match?({:denylisted, _}, class) end)

    unresolved = Enum.filter(classified, fn {_s, _c, class} -> class == :unresolved end)
    castable_rows = sum_rows(castable)

    Mix.shell().info("  rows: #{total}   distinct skills: #{map_size(skill_rows)}")

    Mix.shell().info(
      "  castable skills: #{length(castable)}   denylisted skills: #{length(denylisted)}   " <>
        "unresolved skills: #{length(unresolved)}   " <>
        "row coverage: #{percent(castable_rows, total)}% (#{castable_rows}/#{total})"
    )

    Mix.shell().info("  denylisted skills (rows, reason):")

    Enum.each(denylisted, fn {skill, count, {:denylisted, reason}} ->
      Mix.shell().info("    #{skill}: #{count} (#{reason})")
    end)

    Mix.shell().info("  top unresolved skills by row count:")

    Enum.each(top_unresolved(unresolved), fn {skill, count} ->
      Mix.shell().info("    #{skill}: #{count}")
    end)

    :ok
  end

  @spec sum_rows([{String.t(), non_neg_integer(), Importer.classification()}]) ::
          non_neg_integer()
  defp sum_rows(classified),
    do: Enum.reduce(classified, 0, fn {_s, c, _class}, acc -> acc + c end)

  @spec top_unresolved([{String.t(), non_neg_integer(), Importer.classification()}]) ::
          [{String.t(), non_neg_integer()}]
  defp top_unresolved(unresolved) do
    unresolved
    |> Enum.map(fn {skill, count, _class} -> {skill, count} end)
    |> Enum.sort_by(fn {_skill, count} -> -count end)
    |> Enum.take(@top_unresolved)
  end

  @spec percent(non_neg_integer(), non_neg_integer()) :: float()
  defp percent(_num, 0), do: 0.0
  defp percent(num, total), do: Float.round(num * 100 / total, 1)
end
