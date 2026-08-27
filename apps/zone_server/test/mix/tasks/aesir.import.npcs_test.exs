defmodule Mix.Tasks.Aesir.Import.NpcsTest do
  use ExUnit.Case, async: false
  use Mimic

  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups
  alias Aesir.ZoneServer.Mmo.ItemManagement.Items
  alias Mix.Tasks.Aesir.Import.Npcs

  setup :set_mimic_private
  setup :verify_on_exit!

  @tag :tmp_dir
  test "resolves items and item groups from the supplied source catalogs", %{tmp_dir: tmp_dir} do
    rathena = Path.join(tmp_dir, "rathena")
    out_root = Path.join(tmp_dir, "out")
    write_catalogs(rathena)
    write_npc(rathena)

    reject(&Items.loaded?/0)
    reject(&Items.by_id/1)
    reject(&Items.by_aegis/1)
    reject(&ItemGroups.loaded?/0)
    reject(&ItemGroups.fetch/1)

    result =
      Npcs.transpile(rathena,
        only: "re/cities/**",
        force: true,
        out_root: out_root
      )

    assert result.failures == []
    assert [output_path] = result.written

    source = File.read!(Path.join(out_root, output_path))
    assert source =~ "ctx |> give_item(501, 1)"
    assert source =~ "|> get_group_item(:test_box)"
  end

  defp write_catalogs(rathena) do
    write_database(rathena, "item_db.yml", "ITEM_DB", [
      %{"Id" => 501, "AegisName" => "Red_Potion"}
    ])

    write_database(rathena, "item_group_db.yml", "ITEM_GROUP_DB", [
      %{"Group" => "TEST_BOX"}
    ])
  end

  defp write_database(rathena, file, type, body) do
    path = Path.join([rathena, "db", file])
    File.mkdir_p!(Path.dirname(path))

    File.write!(
      path,
      Ymlr.document!(%{"Header" => %{"Type" => type, "Version" => 3}, "Body" => body})
    )
  end

  defp write_npc(rathena) do
    path = Path.join([rathena, "npc", "re", "cities", "catalog_npc.txt"])
    File.mkdir_p!(Path.dirname(path))

    File.write!(path, """
    prontera,150,150,4\tscript\tCatalog NPC\t54,{
    getitem Red_Potion,1;
    getgroupitem IG_TEST_BOX;
    close;
    }
    """)
  end
end
