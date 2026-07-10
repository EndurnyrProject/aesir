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
  which skills map to a real archetype (`MobSkill.Catalog`) vs `:stub`, with the
  row-coverage %, per-archetype skill counts, and the top stubbed skills by row
  count.
  """
  use Mix.Task

  alias Aesir.ZoneServer.Mmo.MobSkill.Catalog
  alias Aesir.ZoneServer.Mmo.MobSkill.Importer

  @out_dir Path.join(~w(apps zone_server priv db mob_skills))
  @top_stubs 20

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
    skill_counts = Enum.frequencies_by(rows, & &1.skill)
    classified = Enum.map(skill_counts, fn {skill, count} -> {skill, count, archetype(skill)} end)

    {mapped, stubbed} = Enum.split_with(classified, fn {_s, _c, arch} -> arch != :stub end)
    mapped_rows = sum_rows(mapped)

    Mix.shell().info("  rows: #{total}   distinct skills: #{map_size(skill_counts)}")

    Mix.shell().info(
      "  mapped skills: #{length(mapped)}   stub skills: #{length(stubbed)}   " <>
        "row coverage: #{percent(mapped_rows, total)}% (#{mapped_rows}/#{total})"
    )

    Mix.shell().info("  per-archetype (distinct skills / rows):")

    Enum.each(per_archetype(mapped), fn {arch, skills, arch_rows} ->
      Mix.shell().info("    #{arch}: #{skills} / #{arch_rows}")
    end)

    Mix.shell().info("  top stubbed skills by row count:")

    Enum.each(top_stubs(stubbed), fn {skill, count} ->
      Mix.shell().info("    #{skill}: #{count}")
    end)

    :ok
  end

  @spec archetype(String.t()) :: atom()
  defp archetype(skill) do
    case Catalog.archetype_for(skill) do
      {arch, _params} -> arch
      :stub -> :stub
    end
  end

  @spec sum_rows([{String.t(), non_neg_integer(), atom()}]) :: non_neg_integer()
  defp sum_rows(classified), do: Enum.reduce(classified, 0, fn {_s, c, _a}, acc -> acc + c end)

  @spec per_archetype([{String.t(), non_neg_integer(), atom()}]) ::
          [{atom(), non_neg_integer(), non_neg_integer()}]
  defp per_archetype(mapped) do
    mapped
    |> Enum.group_by(fn {_s, _c, arch} -> arch end)
    |> Enum.map(fn {arch, entries} -> {arch, length(entries), sum_rows(entries)} end)
    |> Enum.sort_by(fn {_arch, _skills, arch_rows} -> -arch_rows end)
  end

  @spec top_stubs([{String.t(), non_neg_integer(), atom()}]) :: [{String.t(), non_neg_integer()}]
  defp top_stubs(stubbed) do
    stubbed
    |> Enum.map(fn {skill, count, _arch} -> {skill, count} end)
    |> Enum.sort_by(fn {_skill, count} -> -count end)
    |> Enum.take(@top_stubs)
  end

  @spec percent(non_neg_integer(), non_neg_integer()) :: float()
  defp percent(_num, 0), do: 0.0
  defp percent(num, total), do: Float.round(num * 100 / total, 1)
end
