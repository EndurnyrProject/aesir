defmodule Mix.Tasks.Aesir.Import.SkillNocast do
  @shortdoc "Imports rAthena's skill_nocast_db map restrictions for the selected mode"
  @moduledoc """
  Imports the skill map-restriction masks of `db/<re|pre-re>/skill_nocast_db.txt`
  into `apps/zone_server/priv/db/<mode>/skill_nocast.yml`.

      mix aesir.import.skill_nocast [<rathena_root>] [--mode re|pre-re]

  Each `SkillID,Flag` line ORs its flag into the skill's mask, as the reference
  loader does, so a skill listed on several lines carries every bit. Comments and
  blank lines are skipped. Rows are sorted by skill id.
  """
  use Mix.Task

  import Bitwise

  alias Mix.Tasks.Aesir.Import

  @impl Mix.Task
  @spec run([String.t()]) :: :ok
  def run(args) do
    {root, mode} = Import.parse!(args)
    mode_dir = if mode == :renewal, do: "re", else: "pre-re"

    rows =
      root
      |> Path.join("db/#{mode_dir}/skill_nocast_db.txt")
      |> File.stream!()
      |> to_rows()

    out = Import.path("skill_nocast.yml", mode)
    File.mkdir_p!(Path.dirname(out))
    File.write!(out, Ymlr.document!(rows))
    Mix.shell().info("skill_nocast: #{length(rows)} skills -> #{out}")
  end

  @doc "ORs every `SkillID,Flag` line into one id and flags row per skill."
  @spec to_rows(Enumerable.t()) :: [map()]
  def to_rows(lines) do
    lines
    |> Enum.reduce(%{}, fn line, masks ->
      case parse(line) do
        {id, flag} -> Map.update(masks, id, flag, &bor(&1, flag))
        nil -> masks
      end
    end)
    |> Enum.sort()
    |> Enum.map(fn {id, flags} -> %{"id" => id, "flags" => flags} end)
  end

  defp parse(line) do
    line = line |> String.split("//", parts: 2) |> hd() |> String.trim()

    with [id, flag | _rest] <- String.split(line, ","),
         {id, ""} <- id |> String.trim() |> Integer.parse(),
         {flag, ""} <- flag |> String.trim() |> Integer.parse() do
      {id, flag}
    else
      _other -> nil
    end
  end
end
