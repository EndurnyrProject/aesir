defmodule Mix.Tasks.Aesir.Import.Guild do
  @shortdoc "Imports mode-selected guild EXP and skill-tree data"
  @moduledoc """
  Converts the mode-selected `exp_guild.yml` and `guild_skill_tree.yml` into
  our-schema YAML under `apps/zone_server/priv/db/<mode>/guild/`.

      mix aesir.import.guild [<rathena_root>] [--mode re|pre-re]

  `<rathena_root>` defaults to `../rathena`. Skill names are resolved to their
  numeric guild-skill IDs; an unknown name is an error. Missing input files are
  errors and no partial output is written. Re-running against the same checkout
  is deterministic and idempotent.
  """
  use Mix.Task

  alias Mix.Tasks.Aesir.Import

  @skill_ids %{
    "GD_APPROVAL" => 10_000,
    "GD_KAFRACONTRACT" => 10_001,
    "GD_GUARDRESEARCH" => 10_002,
    "GD_GUARDUP" => 10_003,
    "GD_EXTENSION" => 10_004,
    "GD_GLORYGUILD" => 10_005,
    "GD_LEADERSHIP" => 10_006,
    "GD_GLORYWOUNDS" => 10_007,
    "GD_SOULCOLD" => 10_008,
    "GD_HAWKEYES" => 10_009,
    "GD_BATTLEORDER" => 10_010,
    "GD_REGENERATION" => 10_011,
    "GD_RESTORE" => 10_012,
    "GD_EMERGENCYCALL" => 10_013,
    "GD_DEVELOPMENT" => 10_014,
    "GD_ITEMEMERGENCYCALL" => 10_015,
    "GD_GUILD_STORAGE" => 10_016,
    "GD_CHARGESHOUT_FLAG" => 10_017,
    "GD_CHARGESHOUT_BEATING" => 10_018,
    "GD_EMERGENCY_MOVE" => 10_019
  }

  @impl Mix.Task
  def run(args) do
    {rathena, mode} = Import.parse!(args)
    exp_out = Import.path("guild/exp.yml", mode)
    tree_out = Import.path("guild/skill_tree.yml", mode)
    exp_src = Path.join([rathena, "db", "exp_guild.yml"])
    tree_src = Path.join([rathena, "db", "guild_skill_tree.yml"])

    exp = exp_src |> Import.read_mode_filtered!(mode) |> Enum.map(&convert_exp/1)
    tree = tree_src |> Import.read_mode_filtered!(mode) |> Enum.map(&convert_skill/1)

    File.mkdir_p!(Path.dirname(exp_out))
    write!(exp_out, exp)
    write!(tree_out, tree)

    Mix.shell().info(
      "guild: #{length(exp)} exp levels, #{length(tree)} skills -> #{Path.dirname(exp_out)}"
    )
  end

  defp convert_exp(%{"Level" => level, "Exp" => exp}), do: %{level: level, exp: exp}

  defp convert_skill(%{"Id" => name} = entry) do
    %{
      id: skill_id!(name),
      name: name,
      max_level: Map.get(entry, "MaxLevel", 0),
      prerequisites:
        entry
        |> Map.get("Required", [])
        |> Enum.map(fn %{"Id" => req, "Level" => level} ->
          %{id: skill_id!(req), level: level}
        end)
    }
  end

  defp skill_id!(name) do
    case Map.fetch(@skill_ids, name) do
      {:ok, id} -> id
      :error -> Mix.raise("unknown guild skill name: #{name}")
    end
  end

  defp write!(path, entries), do: File.write!(path, Ymlr.document!(entries))
end
