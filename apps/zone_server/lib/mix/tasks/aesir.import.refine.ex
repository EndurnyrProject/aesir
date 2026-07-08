defmodule Mix.Tasks.Aesir.Import.Refine do
  @shortdoc "Imports the rAthena renewal refine.yml into priv/db/refine/refine.yml"
  @moduledoc """
  One-time importer: converts rAthena's renewal `db/re/refine.yml` (schema v2)
  into our own-schema `apps/zone_server/priv/db/refine/refine.yml`.

      mix aesir.import.refine [<rathena_root>]

  `<rathena_root>` defaults to `../rathena`. Groups (`Armor`/`Weapon`/
  `Shadow_Armor`/`Shadow_Weapon`), item levels (`Levels[].Level`) and refine
  levels (`RefineLevels[].Level`) are preserved as-is; only the key casing is
  normalized to our `snake_case` convention. Ore/blessing material names are
  kept as aegis strings - resolving them to nameids happens at load time, not
  during import. Output is deterministic so re-running yields no diff.
  """
  use Mix.Task

  @out_file Path.join(~w(apps zone_server priv db refine refine.yml))
  @source Path.join(~w(db re refine.yml))

  @groups %{
    "Armor" => "armor",
    "Weapon" => "weapon",
    "Shadow_Armor" => "shadow_armor",
    "Shadow_Weapon" => "shadow_weapon"
  }

  @cost_types %{"Normal" => "normal", "HD" => "hd", "Enriched" => "enriched"}

  @impl Mix.Task
  def run(args) do
    rathena = List.first(args) || "../rathena"

    groups =
      rathena
      |> Path.join(@source)
      |> YamlElixir.read_from_file!()
      |> groups_from_body()

    File.mkdir_p!(Path.dirname(@out_file))
    File.write!(@out_file, Ymlr.document!(groups, sort_maps: true))

    Mix.shell().info("refine: wrote #{length(groups)} groups -> #{@out_file}")
  end

  @spec groups_from_body(map()) :: [map()]
  def groups_from_body(%{"Body" => body}) do
    Enum.map(body, &group_entry/1)
  end

  @spec group_entry(map()) :: map()
  defp group_entry(%{"Group" => group, "Levels" => levels}) do
    %{"group" => Map.fetch!(@groups, group), "levels" => Enum.map(levels, &level_entry/1)}
  end

  @spec level_entry(map()) :: map()
  defp level_entry(%{"Level" => level, "RefineLevels" => refine_levels}) do
    %{"level" => level, "refine_levels" => Enum.map(refine_levels, &refine_level_entry/1)}
  end

  @spec refine_level_entry(map()) :: map()
  defp refine_level_entry(entry) do
    %{
      "level" => Map.fetch!(entry, "Level"),
      "bonus" => Map.get(entry, "Bonus", 0),
      "random_bonus" => Map.get(entry, "RandomBonus", 0),
      "blacksmith_blessing_amount" => Map.get(entry, "BlacksmithBlessingAmount", 0),
      "broadcast_success" => Map.get(entry, "BroadcastSuccess", false),
      "broadcast_failure" => Map.get(entry, "BroadcastFailure", false),
      "chances" => entry |> Map.get("Chances", []) |> Enum.map(&chance_entry/1)
    }
  end

  @spec chance_entry(map()) :: map()
  defp chance_entry(entry) do
    %{
      "type" => Map.fetch!(@cost_types, Map.fetch!(entry, "Type")),
      "rate" => Map.get(entry, "Rate", 0),
      "price" => Map.get(entry, "Price", 0),
      "material" => Map.fetch!(entry, "Material"),
      "breaking_rate" => Map.get(entry, "BreakingRate", 0),
      "downgrade_amount" => Map.get(entry, "DowngradeAmount", 0)
    }
  end
end
