defmodule Mix.Tasks.Aesir.Import.Quests do
  @shortdoc "Imports rAthena renewal quest_db into priv/db/re/quests/quests.yml"
  @moduledoc """
  One-time importer: converts rAthena's renewal `quest_db.yml` into our
  own-schema YAML at `apps/zone_server/priv/db/re/quests/quests.yml`.

      mix aesir.import.quests [<rathena_root>]

  `<rathena_root>` defaults to `../rathena`. Target `Mob`/`MapMobTargets`
  names and Drop `Mob`/`Item` names are resolved against the imported
  mob/item db; a name that doesn't resolve is dropped (the whole target for
  an unresolvable `Mob`, a single entry for `MapMobTargets`/`Drop`) and
  reported in the run summary - the quest itself is always kept.
  Deterministic and idempotent: re-running against the same rAthena checkout
  produces an identical file. Run only when syncing rAthena.
  """
  use Mix.Task

  alias Aesir.ZoneServer.Mmo.QuestManagement.Importer

  @out_dir Path.join(~w(apps zone_server priv db quests))

  @impl Mix.Task
  def run(args) do
    rathena = List.first(args) || "../rathena"
    src = Path.join([rathena, "db", "re", "quest_db.yml"])
    File.mkdir_p!(@out_dir)

    {definitions, dropped} =
      src
      |> read_body!()
      |> Enum.map(&Importer.to_definition/1)
      |> Enum.reduce({[], []}, fn {definition, entry_dropped}, {defs, dropped} ->
        {[definition | defs], dropped ++ entry_dropped}
      end)
      |> then(fn {defs, dropped} -> {Enum.reverse(defs), dropped} end)

    yaml = definitions |> Enum.map(&Importer.to_yaml_map/1) |> Ymlr.document!()
    out = Path.join(@out_dir, "quests.yml")
    File.write!(out, yaml)

    Mix.shell().info("quests: #{length(definitions)} -> #{out}")
    report(dropped)
  end

  defp read_body!(path) do
    case YamlElixir.read_from_file!(path) do
      %{"Body" => body} when is_list(body) -> body
      _ -> Mix.raise("expected a Body list in #{path}")
    end
  end

  defp report([]), do: :ok

  defp report(dropped) do
    Mix.shell().info("  dropped #{length(dropped)} unresolvable target/drop reference(s):")

    Enum.each(dropped, fn {quest_id, kind, name} ->
      Mix.shell().info("    quest #{quest_id} #{kind}: #{inspect(name)}")
    end)
  end
end
