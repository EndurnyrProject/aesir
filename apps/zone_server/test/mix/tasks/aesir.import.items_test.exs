defmodule Mix.Tasks.Aesir.Import.ItemsTest do
  use ExUnit.Case, async: false
  use Mimic

  alias Aesir.ZoneServer.Mmo.ItemManagement.Importer
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups
  alias Aesir.ZoneServer.Mmo.ItemManagement.Items, as: RuntimeItems
  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.Transpiler
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

    test "stores a flat direct status lifecycle only when both hooks transpile" do
      assert {%ItemDefinition{on_equip: on_equip, on_unequip: on_unequip}, nil} =
               Items.apply_transpile(
                 definition(%{type: :armor}),
                 nil,
                 "sc_start SC_SUMMER,INFINITE_TICK,0;",
                 "sc_end SC_SUMMER;"
               )

      assert on_equip == [{:status_start, :sc_summer, :infinite, 0}]
      assert on_unequip == [{:status_end, :sc_summer}]
    end

    test "keeps an ordinary finite Script status start without an UnEquipScript" do
      assert {%ItemDefinition{on_equip: [{:status_start, :sc_summer, 5_000, 1}], on_unequip: nil},
              nil} =
               Items.apply_transpile(
                 definition(%{type: :armor}),
                 "sc_start SC_SUMMER,5000,1;"
               )
    end

    test "rejects an EquipScript lifecycle start when its pair is missing" do
      item = definition(%{type: :armor})

      assert {^item,
              {:on_unequip, 501, "Red Potion",
               {:unsupported,
                {:status_lifecycle_mismatch, %{on_equip: [:sc_summer], on_unequip: []}}}}} =
               Items.apply_transpile(
                 item,
                 nil,
                 "sc_start SC_SUMMER,INFINITE_TICK,0;",
                 nil
               )
    end

    test "attributes an unequip resolver failure without storing either lifecycle program" do
      assert {%ItemDefinition{on_equip: nil, on_unequip: nil},
              {:on_unequip, 501, "Red Potion", {:unsupported, {:unresolved_param, "SC_NOT_REAL"}}}} =
               Items.apply_transpile(
                 definition(%{type: :armor}),
                 nil,
                 "sc_start SC_SUMMER,INFINITE_TICK,0;",
                 "sc_end SC_NOT_REAL;"
               )
    end

    test "attributes an equip resolver failure without storing either lifecycle program" do
      assert {%ItemDefinition{on_equip: nil, on_unequip: nil},
              {:on_equip, 501, "Red Potion", {:unsupported, {:unresolved_param, "SC_NOT_REAL"}}}} =
               Items.apply_transpile(
                 definition(%{type: :armor}),
                 nil,
                 "sc_start SC_NOT_REAL,INFINITE_TICK,0;",
                 "sc_end SC_SUMMER;"
               )
    end

    test "preserves the exact parser failure for a malformed direct lifecycle start" do
      equip_script = "sc_start SC_SUMMER,"
      assert {:error, reason} = Transpiler.transpile_equip(equip_script)

      assert {%ItemDefinition{on_equip: nil, on_unequip: nil},
              {:on_equip, 501, "Red Potion", ^reason}} =
               Items.apply_transpile(
                 definition(%{type: :armor}),
                 nil,
                 equip_script,
                 "sc_end SC_SUMMER;"
               )
    end

    test "preserves a lexer-stage failure after a direct lifecycle start" do
      equip_script = ~S'sc_start SC_SUMMER,1000,0; "'
      assert {:error, reason} = Transpiler.transpile_equip(equip_script)

      assert {%ItemDefinition{on_equip: nil, on_unequip: nil},
              {:on_equip, 501, "Red Potion", ^reason}} =
               Items.apply_transpile(
                 definition(%{type: :armor}),
                 nil,
                 equip_script,
                 "sc_end SC_SUMMER;"
               )
    end

    test "preserves the exact unequip parser failure" do
      unequip_script = "sc_end SC_SUMMER,"
      assert {:error, reason} = Transpiler.transpile_equip(unequip_script, :unequip)

      assert {%ItemDefinition{on_equip: nil, on_unequip: nil},
              {:on_unequip, 501, "Red Potion", ^reason}} =
               Items.apply_transpile(
                 definition(%{type: :armor}),
                 nil,
                 "sc_start SC_SUMMER,INFINITE_TICK,0;",
                 unequip_script
               )
    end

    test "rejects mismatched status lifecycle programs atomically" do
      assert {%ItemDefinition{on_equip: nil, on_unequip: nil},
              {:on_unequip, 501, "Red Potion",
               {:unsupported,
                {:status_lifecycle_mismatch,
                 %{on_equip: [:sc_summer], on_unequip: [:sc_moonstar]}}}}} =
               Items.apply_transpile(
                 definition(%{type: :armor}),
                 nil,
                 "sc_start SC_SUMMER,INFINITE_TICK,0;",
                 "sc_end SC_MOONSTAR;"
               )
    end

    test "ignores an unrelated UnEquipScript without storing or failing it" do
      assert {%ItemDefinition{on_equip: [{:bonus, :vit, 1}], on_unequip: nil}, nil} =
               Items.apply_transpile(
                 definition(%{type: :armor}),
                 "bonus bVit,1;",
                 nil,
                 "heal 0,-100;"
               )
    end

    test "ignores an UnEquipScript status end without a lifecycle EquipScript" do
      assert {%ItemDefinition{on_equip: [{:bonus, :vit, 1}], on_unequip: nil}, nil} =
               Items.apply_transpile(
                 definition(%{type: :armor}),
                 "bonus bVit,1;",
                 nil,
                 "sc_end SC_HIDING;"
               )
    end

    test "ignores nested autobonus status text as a non-lifecycle EquipScript" do
      equip_script = ~S'autobonus "{ sc_start SC_SUMMER,1000,0; }",100,1000;'

      assert {%ItemDefinition{on_equip: nil, on_unequip: nil}, nil} =
               Items.apply_transpile(
                 definition(%{type: :armor}),
                 nil,
                 equip_script,
                 nil
               )
    end

    test "ignores comments and strings containing sc_start" do
      equip_script = ~S'// sc_start SC_SUMMER,1000,0;
      showscript "sc_start SC_SUMMER,1000,0";'

      assert {%ItemDefinition{on_equip: nil, on_unequip: nil}, nil} =
               Items.apply_transpile(
                 definition(%{type: :armor}),
                 nil,
                 equip_script,
                 nil
               )
    end

    test "ignores malformed quoted and commented sc_start text" do
      item = definition(%{type: :armor})

      assert {^item, nil} =
               Items.apply_transpile(item, nil, ~S'showscript "sc_start SC_SUMMER,', nil)

      assert {^item, nil} =
               Items.apply_transpile(item, nil, "/* sc_start SC_SUMMER,1000,0;", nil)
    end

    test "rejects opposite conditional lifecycle branches atomically" do
      equip_script = """
      if (getrefine() > 5) {
        sc_start SC_SUMMER,INFINITE_TICK,0;
      } else {
        sc_start SC_MOONSTAR,INFINITE_TICK,0;
      }
      """

      unequip_script = """
      if (getrefine() > 5) {
        sc_end SC_MOONSTAR;
      } else {
        sc_end SC_SUMMER;
      }
      """

      assert {%ItemDefinition{on_equip: nil, on_unequip: nil},
              {:on_equip, 501, "Red Potion",
               {:unsupported,
                {:non_flat_status_lifecycle,
                 %{allowed: :status_start, instruction: {:if, _, _, _}}}}}} =
               Items.apply_transpile(
                 definition(%{type: :armor}),
                 nil,
                 equip_script,
                 unequip_script
               )
    end

    test "rejects an EquipScript bonus mixed with a direct status start" do
      assert {%ItemDefinition{on_equip: nil, on_unequip: nil},
              {:on_equip, 501, "Red Potion",
               {:unsupported,
                {:non_flat_status_lifecycle,
                 %{allowed: :status_start, instruction: {:bonus, :vit, 1}}}}}} =
               Items.apply_transpile(
                 definition(%{type: :armor}),
                 nil,
                 "bonus bVit,1; sc_start SC_SUMMER,INFINITE_TICK,0;",
                 "sc_end SC_SUMMER;"
               )
    end

    test "matches duplicate flat starts and ends by unique status ID" do
      assert {%ItemDefinition{on_equip: on_equip, on_unequip: on_unequip}, nil} =
               Items.apply_transpile(
                 definition(%{type: :armor}),
                 nil,
                 "sc_start SC_SUMMER,1000,0; sc_start SC_SUMMER,2000,1;",
                 "sc_end SC_SUMMER;"
               )

      assert length(on_equip) == 2
      assert length(on_unequip) == 1
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
               Items.apply_transpile(definition(%{type: :weapon}), "bonus bClassChange,2;")
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

      equipment =
        "apps/zone_server/priv/db/pre-re/items/equip.yml"
        |> YamlElixir.read_from_file!()
        |> Map.new(&{&1["id"], &1})

      assert equipment[2776]["on_equip"] ==
               "status_start(ctx, :sc_summer, :infinite, 0)"

      assert equipment[2776]["on_unequip"] == "status_end(ctx, :sc_summer)"
      assert equipment[2777]["on_equip"] == "status_start(ctx, :sc_summer, 5000, 1)"
      refute Map.has_key?(equipment[2777], "on_unequip")
      assert equipment[2778]["on_equip"] == "bonus(ctx, :vit, 1)"
      refute Map.has_key?(equipment[2778], "on_unequip")
      refute Map.has_key?(equipment[2779], "on_equip")
      refute Map.has_key?(equipment[2779], "on_unequip")

      report = File.read!("apps/zone_server/priv/db/pre-re/items/_transpile_report.md")

      assert report =~ "| on_use | 1 | 1 | 1 | 0 |"
      assert report =~ "| on_equip | 4 | 3 | 3 | 0 |"
      assert report =~ "| on_unequip | 1 | 1 | 1 | 0 |"
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
      script = "bonus bAtkEle,Ele_Fire; bonus bClassChange,2;"

      assert {:ok, %ItemDefinition{attack_element: :fire} = def} =
               Importer.to_definition(fireblend(script))

      assert {%ItemDefinition{attack_element: :fire, on_equip: nil},
              {:on_equip, 1140, "Fireblend", {:unsupported, {:unknown_bonus_key, "bClassChange"}}}} =
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
      },
      %{
        "Id" => 2776,
        "AegisName" => "Cool_Towel",
        "Name" => "Adventurer's Trusty Towel",
        "Type" => "Armor",
        "EquipScript" => "sc_start SC_SUMMER,INFINITE_TICK,0;",
        "UnEquipScript" => "sc_end SC_SUMMER;"
      },
      %{
        "Id" => 2777,
        "AegisName" => "Ordinary_Status",
        "Name" => "Ordinary Status",
        "Type" => "Armor",
        "Script" => "sc_start SC_SUMMER,5000,1;"
      },
      %{
        "Id" => 2778,
        "AegisName" => "Unrelated_Unequip",
        "Name" => "Unrelated Unequip",
        "Type" => "Armor",
        "Script" => "bonus bVit,1;",
        "UnEquipScript" => "heal 0,-100;"
      },
      %{
        "Id" => 2779,
        "AegisName" => "Unrelated_Equip_Lifecycle",
        "Name" => "Unrelated Equip Lifecycle",
        "Type" => "Armor",
        "EquipScript" => "bonus bVit,2;",
        "UnEquipScript" => "sc_end SC_HIDING;"
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
