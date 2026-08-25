defmodule Mix.Tasks.Aesir.Import.ItemsTest do
  use ExUnit.Case, async: false
  use Mimic

  alias Aesir.ZoneServer.Mmo.ItemManagement.Importer
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups
  alias Aesir.ZoneServer.Mmo.ItemManagement.Items, as: RuntimeItems
  alias Mix.Tasks.Aesir.Import.Items

  setup :set_mimic_private
  setup :verify_on_exit!

  @pre_files Enum.map(
               ~w(usable equip etc),
               &Path.join(["apps", "zone_server", "priv", "db", "pre-re", "items", "#{&1}.yml"])
             ) ++
               [
                 Path.join(~w(apps zone_server priv db pre-re items _transpile_report.md))
               ]

  defp definition(attrs) do
    struct(
      ItemDefinition,
      Map.merge(%{id: 501, aegis_name: "Red_Potion", name: "Red Potion"}, attrs)
    )
  end

  describe "apply_transpile/2 (on_use)" do
    test "sets on_use from a supported usable script" do
      assert {%ItemDefinition{on_use: "heal(ctx, hp: 45)"}, nil} =
               Items.apply_transpile(definition(%{type: :usable}), "itemheal 45,0;")
    end

    test "keeps Stone of Sage active without a transpile failure" do
      stone =
        definition(%{
          id: 12_040,
          aegis_name: "Stone_Of_Intelligence_",
          name: "Stone of Sage",
          type: :usable
        })

      assert {%ItemDefinition{id: 12_040, on_use: "homevolution(ctx)"}, nil} =
               Items.apply_transpile(stone, "homevolution;")
    end

    test "keeps on_use nil and records an :on_use failure for an unsupported script" do
      assert {%ItemDefinition{on_use: nil}, {:on_use, 501, "Red Potion", {:unsupported, _}}} =
               Items.apply_transpile(definition(%{type: :usable}), "produce 1;")
    end

    test "skips usable items without a script" do
      assert {%ItemDefinition{on_use: nil}, nil} =
               Items.apply_transpile(definition(%{type: :usable}), nil)
    end
  end

  describe "apply_transpile/2 (on_equip)" do
    test "sets on_equip for a clean armor script" do
      assert {%ItemDefinition{on_equip: [{:bonus, :smatk, 3}]}, nil} =
               Items.apply_transpile(definition(%{type: :armor}), "bonus bSMatk,3;")
    end

    test "sets on_equip for a clean weapon script" do
      assert {%ItemDefinition{on_equip: [{:bonus, :patk, 20}]}, nil} =
               Items.apply_transpile(definition(%{type: :weapon}), "bonus bPAtk,20;")
    end

    test "leaves on_equip nil for a card (cards are excluded)" do
      assert {%ItemDefinition{on_equip: nil}, nil} =
               Items.apply_transpile(definition(%{type: :card}), "bonus bSMatk,3;")
    end

    test "leaves on_equip nil with no failure for a comment/assignment-only script" do
      assert {%ItemDefinition{on_equip: nil}, nil} =
               Items.apply_transpile(definition(%{type: :armor}), ".@r = getrefine();")
    end

    test "records an :on_equip failure for an out-of-vocabulary equip script" do
      assert {%ItemDefinition{on_equip: nil}, {:on_equip, 501, "Red Potion", {:unsupported, _}}} =
               Items.apply_transpile(definition(%{type: :weapon}), "bonus bNoRegen,2;")
    end

    test "skips equip items without a script" do
      assert {%ItemDefinition{on_equip: nil}, nil} =
               Items.apply_transpile(definition(%{type: :armor}), nil)
    end
  end

  describe "apply_transpile/2 (other types)" do
    test "skips etc items entirely" do
      assert {%ItemDefinition{on_use: nil, on_equip: nil}, nil} =
               Items.apply_transpile(definition(%{type: :etc}), "itemheal 45,0;")
    end
  end

  describe "mode-selected source import" do
    @tag :tmp_dir
    test "bootstraps pre-renewal output without runtime catalogs", %{tmp_dir: tmp_dir} do
      originals = Map.new(@pre_files, &{&1, File.read(&1)})

      on_exit(fn ->
        Enum.each(originals, fn
          {path, {:ok, contents}} -> File.write!(path, contents)
          {path, {:error, :enoent}} -> File.rm(path)
        end)

        File.rmdir(Path.join(~w(apps zone_server priv db pre-re items)))
      end)

      write_source_fixture(tmp_dir)
      reject(&RuntimeItems.loaded?/0)
      reject(&RuntimeItems.by_id/1)
      reject(&RuntimeItems.by_aegis/1)
      reject(&ItemGroups.loaded?/0)
      reject(&ItemGroups.fetch/1)

      Items.run([tmp_dir, "--mode", "pre-re"])

      [item] =
        "apps/zone_server/priv/db/pre-re/items/usable.yml"
        |> YamlElixir.read_from_file!()

      assert item["id"] == 501
      assert item["on_use"] =~ "give_item(ctx, 501, 1)"
      assert item["on_use"] =~ "get_group_item(ctx, :pre_box)"
    end
  end

  describe "bAtkEle carve-out" do
    defp fireblend(script) do
      %{
        "Id" => 1140,
        "AegisName" => "Fireblend",
        "Name" => "Fireblend",
        "Type" => "Weapon",
        "SubType" => "1hSword",
        "Script" => script
      }
    end

    test "keeps attack_element even when the script is rejected as a whole" do
      script = "bonus bAtkEle,Ele_Fire; bonus bNoRegen,2;"

      assert {:ok, %ItemDefinition{attack_element: :fire} = def} =
               Importer.to_definition(fireblend(script))

      assert {%ItemDefinition{attack_element: :fire, on_equip: nil},
              {:on_equip, 1140, "Fireblend", {:unsupported, {:unknown_bonus_key, "bNoRegen"}}}} =
               Items.apply_transpile(def, script)
    end

    test "a transpilable script sets both attack_element and the :set instruction" do
      script = "bonus bAtkEle,Ele_Fire;"

      assert {:ok, %ItemDefinition{attack_element: :fire} = def} =
               Importer.to_definition(fireblend(script))

      assert {%ItemDefinition{attack_element: :fire, on_equip: [{:set, :atk_ele, :fire}]}, nil} =
               Items.apply_transpile(def, script)
    end
  end

  defp write_source_fixture(root) do
    write_root(root, "item_db.yml", "ITEM_DB", "db/pre-re/item_db.yml")
    write_root(root, "item_group_db.yml", "ITEM_GROUP_DB", "db/pre-re/item_group_db.yml")

    write_body(root, "item_db.yml", "ITEM_DB", [
      %{
        "Id" => 501,
        "AegisName" => "Pre_Potion",
        "Name" => "Pre Potion",
        "Type" => "Usable",
        "Script" => "getitem Pre_Potion,1; getgroupitem IG_PRE_BOX;"
      }
    ])

    write_body(root, "item_group_db.yml", "ITEM_GROUP_DB", [
      %{"Group" => "PRE_BOX", "SubGroups" => []}
    ])
  end

  defp write_root(root, file, type, import) do
    path = Path.join([root, "db", file])
    File.mkdir_p!(Path.dirname(path))

    File.write!(
      path,
      Ymlr.document!(%{
        "Header" => %{"Type" => type, "Version" => 3},
        "Footer" => %{"Imports" => [%{"Path" => import, "Mode" => "Prerenewal"}]}
      })
    )
  end

  defp write_body(root, file, type, body) do
    path = Path.join([root, "db", "pre-re", file])
    File.mkdir_p!(Path.dirname(path))

    File.write!(
      path,
      Ymlr.document!(%{"Header" => %{"Type" => type, "Version" => 3}, "Body" => body})
    )
  end
end
