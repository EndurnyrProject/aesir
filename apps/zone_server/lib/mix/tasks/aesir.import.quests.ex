defmodule Mix.Tasks.Aesir.Import.Quests do
  @shortdoc "Imports the selected rAthena quest DB into mode-scoped YAML"
  @moduledoc """
  Converts canonical `db/quest_db.yml` plus its selected mode imports into
  `apps/zone_server/priv/db/<mode>/quests/quests.yml`.

      mix aesir.import.quests [<rathena_root>] [--mode re|pre-re]

  `<rathena_root>` defaults to `../rathena`. Target `Mob`/`MapMobTargets`
  names and Drop `Mob`/`Item` names are resolved against the imported
  mob/item db; a name that doesn't resolve is dropped (the whole target for
  an unresolvable `Mob`, a single entry for `MapMobTargets`/`Drop`) and
  reported in the run summary - the quest itself is always kept.
  Deterministic and idempotent: re-running against the same rAthena checkout
  produces an identical file. Run only when syncing rAthena.
  """
  use Mix.Task

  alias Mix.Tasks.Aesir.Import

  alias Aesir.ZoneServer.Mmo.QuestManagement.Importer

  @impl Mix.Task
  def run(args) do
    {rathena, mode} = Import.parse!(args)
    out_dir = Import.path("quests", mode)
    src = Path.join([rathena, "db", "quest_db.yml"])
    File.mkdir_p!(out_dir)

    {definitions, dropped} =
      src
      |> Import.read_mode_filtered!(mode)
      |> Enum.map(&Importer.to_definition/1)
      |> Enum.reduce({[], []}, fn {definition, entry_dropped}, {defs, dropped} ->
        {[definition | defs], dropped ++ entry_dropped}
      end)
      |> then(fn {defs, dropped} -> {Enum.reverse(defs), dropped} end)

    yaml = definitions |> Enum.map(&Importer.to_yaml_map/1) |> Ymlr.document!()
    out = Path.join(out_dir, "quests.yml")
    File.write!(out, yaml)

    Mix.shell().info("quests: #{length(definitions)} -> #{out}")
    report(dropped)
  end

  defp report([]), do: :ok

  defp report(dropped) do
    Mix.shell().info("  dropped #{length(dropped)} unresolvable target/drop reference(s):")

    Enum.each(dropped, fn {quest_id, kind, name} ->
      Mix.shell().info("    quest #{quest_id} #{kind}: #{inspect(name)}")
    end)
  end
end
