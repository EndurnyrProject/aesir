defmodule Mix.Tasks.Aesir.Import.Guild do
  @shortdoc "Imports renewal guild exp and skill-tree data into priv/db/re/guild/"
  @moduledoc """
  One-time importer: converts the reference renewal `exp_guild.yml` and
  `guild_skill_tree.yml` into our-schema YAML at
  `apps/zone_server/priv/db/re/guild/{exp.yml,skill_tree.yml}`.

      mix aesir.import.guild [<rathena_root>]

  `<rathena_root>` defaults to `../rathena`. Skill names are resolved to their
  numeric guild-skill ids (10000-10019); an unknown name is an error. Missing
  input files are an error - no partial output is written. Deterministic and
  idempotent: re-running against the same checkout produces identical files.
  """
  use Mix.Task

  @out_dir Path.join(~w(apps zone_server priv db guild))

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
    rathena = List.first(args) || "../rathena"
    exp_src = Path.join([rathena, "db", "re", "exp_guild.yml"])
    tree_src = Path.join([rathena, "db", "re", "guild_skill_tree.yml"])

    exp = exp_src |> read_body!() |> Enum.map(&convert_exp/1)
    tree = tree_src |> read_body!() |> Enum.map(&convert_skill/1)

    File.mkdir_p!(@out_dir)
    write!(Path.join(@out_dir, "exp.yml"), exp)
    write!(Path.join(@out_dir, "skill_tree.yml"), tree)

    Mix.shell().info("guild: #{length(exp)} exp levels, #{length(tree)} skills -> #{@out_dir}")
  end

  defp read_body!(path) do
    unless File.exists?(path), do: Mix.raise("missing input file: #{path}")

    case YamlElixir.read_from_file!(path) do
      %{"Body" => body} when is_list(body) -> body
      _ -> Mix.raise("expected a Body list in #{path}")
    end
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
