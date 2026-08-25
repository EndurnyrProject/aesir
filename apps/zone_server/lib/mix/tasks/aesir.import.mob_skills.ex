defmodule Mix.Tasks.Aesir.Import.MobSkills do
  @shortdoc "Imports selected rAthena mob skills into mode-scoped YAML"
  @moduledoc """
  Converts the selected mode's `mob_skill_db.txt` into
  `apps/zone_server/priv/db/<mode>/mob_skills/mob_skills.yml`, grouped by mob id.

      mix aesir.import.mob_skills [<rathena_root>] [--mode re|pre-re]

  `<rathena_root>` defaults to `../rathena`. Global rows (`-1`/`-2`/`-3`) are
  written under the reserved keys `global_boss`/`global_normal`/`global_all` and
  expanded per-mob at load time, not baked here. Fails loudly on any token
  outside the rAthena header vocabulary - this is a dev tool, run only when
  syncing rAthena.

  After writing, it prints a coverage manifest: total rows, distinct skills, and
  which skills are `:castable` (resolve in the live skill catalog with an active
  module and satisfy their mob requirements), `:uncastable` (resolve but have
  missing requirements), or `:unresolved` (no catalog entry / no active module) -
  see `MobSkill.Importer.classify/1` - with the row-coverage %, uncastable skills
  and their missing requirements, and the top unresolved skills by row count.
  """
  use Mix.Task

  alias Mix.Tasks.Aesir.Import

  alias Aesir.ZoneServer.Mmo.MobSkill.Importer

  @top_unresolved 20

  @impl Mix.Task
  def run(args) do
    {rathena, mode} = Import.parse!(args)
    out = Import.path("mob_skills/mob_skills.yml", mode)
    src = Path.join(Import.rathena_db_dir(rathena, mode), "mob_skill_db.txt")
    File.mkdir_p!(Path.dirname(out))

    grouped =
      case Importer.to_rows(File.read!(src)) do
        {:ok, grouped} -> grouped
        {:error, reason} -> Mix.raise("failed to import mob skills: #{inspect(reason)}")
      end

    File.write!(out, grouped |> stable_rows() |> Ymlr.document!())

    Mix.shell().info("mob_skills: #{map_size(grouped)} mob keys -> #{out}")
    report(grouped)
  end

  defp stable_rows(grouped) do
    Map.new(grouped, fn {key, rows} ->
      rows =
        Enum.map(rows, fn row ->
          row |> Map.delete(:skill_id) |> Map.put("skill_id", row.skill_id)
        end)

      {key, rows}
    end)
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

    uncastable =
      Enum.filter(classified, fn {_s, _c, class} -> match?({:uncastable, _}, class) end)

    unresolved = Enum.filter(classified, fn {_s, _c, class} -> class == :unresolved end)
    castable_rows = sum_rows(castable)

    Mix.shell().info("  rows: #{total}   distinct skills: #{map_size(skill_rows)}")

    Mix.shell().info(
      "  castable skills: #{length(castable)}   uncastable skills: #{length(uncastable)}   " <>
        "unresolved skills: #{length(unresolved)}   " <>
        "row coverage: #{percent(castable_rows, total)}% (#{castable_rows}/#{total})"
    )

    Mix.shell().info("  uncastable skills (rows, missing requirements):")

    Enum.each(uncastable, fn {skill, count, {:uncastable, reason}} ->
      Mix.shell().info("    #{skill}: #{count} (#{inspect(reason)})")
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
