defmodule Mix.Tasks.Aesir.Import.ItemGroupsTest do
  use ExUnit.Case, async: false
  use Mimic

  import ExUnit.CaptureIO

  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups
  alias Aesir.ZoneServer.Mmo.ItemManagement.Items
  alias Mix.Tasks.Aesir.Import.ItemGroups, as: Task

  setup :set_mimic_private
  setup :verify_on_exit!

  @out_file Path.join(~w(apps zone_server priv db re item_groups item_groups.yml))

  setup do
    original = File.read(@out_file)

    on_exit(fn ->
      case original do
        {:ok, contents} -> File.write!(@out_file, contents)
        {:error, :enoent} -> File.rm(@out_file)
      end
    end)

    :ok
  end

  @tag :tmp_dir
  test "writes sorted resolved groups deterministically and reports dropped entries", %{
    tmp_dir: tmp_dir
  } do
    item_root = Path.join([tmp_dir, "db", "item_db.yml"])
    item_source = Path.join([tmp_dir, "db", "re", "item_db.yml"])
    group_root = Path.join([tmp_dir, "db", "item_group_db.yml"])
    group_source = Path.join([tmp_dir, "db", "re", "item_group_db.yml"])
    File.mkdir_p!(Path.dirname(group_source))

    File.write!(
      item_root,
      Ymlr.document!(%{
        "Header" => %{"Type" => "ITEM_DB", "Version" => 3},
        "Footer" => %{
          "Imports" => [%{"Path" => "db/re/item_db.yml", "Mode" => "Renewal"}]
        }
      })
    )

    File.write!(
      item_source,
      Ymlr.document!(%{
        "Header" => %{"Type" => "ITEM_DB", "Version" => 3},
        "Body" => [
          %{"Id" => 501, "AegisName" => "Red_Potion"},
          %{"Id" => 909, "AegisName" => "Jellopy"}
        ]
      })
    )

    File.write!(
      group_root,
      Ymlr.document!(%{
        "Header" => %{"Type" => "ITEM_GROUP_DB", "Version" => 3},
        "Footer" => %{
          "Imports" => [%{"Path" => "db/re/item_group_db.yml", "Mode" => "Renewal"}]
        }
      })
    )

    File.write!(
      group_source,
      Ymlr.document!(%{
        "Header" => %{"Type" => "ITEM_GROUP_DB", "Version" => 3},
        "Body" => [
          %{
            "Group" => "ZETA",
            "SubGroups" => [
              %{
                "SubGroup" => 2,
                "Algorithm" => "Random",
                "List" => [
                  %{"Index" => 2, "Item" => "Red_Potion", "Rate" => 20},
                  %{"Index" => 1, "Item" => "Jellopy", "Rate" => 10}
                ]
              },
              %{
                "SubGroup" => 1,
                "List" => [
                  %{
                    "Index" => 0,
                    "Item" => "Red_Potion",
                    "Rate" => 1,
                    "Amount" => 2,
                    "Identify" => true,
                    "Duration" => 60,
                    "Bound" => "Account",
                    "UniqueId" => true,
                    "RefineMinimum" => 3,
                    "RefineMaximum" => 5,
                    "GradeMinimum" => 1,
                    "GradeMaximum" => 2,
                    "Named" => true,
                    "Announced" => true,
                    "Stacked" => false
                  },
                  %{"Index" => 1, "Item" => "Unknown_Item", "Rate" => 99}
                ]
              }
            ]
          },
          %{
            "Group" => "ALPHA",
            "SubGroups" => [
              %{
                "SubGroup" => 1,
                "Algorithm" => "All",
                "List" => [%{"Index" => 0, "Item" => "Jellopy", "Rate" => 1}]
              }
            ]
          }
        ]
      })
    )

    reject(&Items.loaded?/0)
    reject(&Items.by_aegis/1)
    reject(&ItemGroups.loaded?/0)
    reject(&ItemGroups.fetch/1)

    output = capture_io(fn -> Task.run([tmp_dir]) end)
    first = File.read!(@out_file)

    capture_io(fn -> Task.run([tmp_dir]) end)

    assert first == File.read!(@out_file)
    assert output =~ "resolved 4 entries, dropped 1"

    assert YamlElixir.read_from_file!(@out_file) == [
             %{
               "key" => "alpha",
               "subgroups" => [
                 %{
                   "algorithm" => "all",
                   "entries" => [%{"item_id" => 909, "rate" => 1}],
                   "number" => 1
                 }
               ]
             },
             %{
               "key" => "zeta",
               "subgroups" => [
                 %{
                   "algorithm" => "shared_pool",
                   "entries" => [
                     %{
                       "amount" => 2,
                       "announced" => true,
                       "bound" => "Account",
                       "duration" => 60,
                       "grade_maximum" => 2,
                       "grade_minimum" => 1,
                       "identify" => true,
                       "item_id" => 501,
                       "named" => true,
                       "rate" => 1,
                       "refine_maximum" => 5,
                       "refine_minimum" => 3,
                       "stacked" => false,
                       "unique_id" => true
                     }
                   ],
                   "number" => 1
                 },
                 %{
                   "algorithm" => "random",
                   "entries" => [
                     %{"item_id" => 909, "rate" => 10},
                     %{"item_id" => 501, "rate" => 20}
                   ],
                   "number" => 2
                 }
               ]
             }
           ]
  end

  @tag :tmp_dir
  test "imports an entry's random option group as its id and aborts on an unknown one", %{
    tmp_dir: tmp_dir
  } do
    write_db!(tmp_dir, "item_db.yml", "ITEM_DB", [%{"Id" => 1201, "AegisName" => "Knife"}])

    write_db!(tmp_dir, "item_randomopt_group.yml", "RANDOM_OPTION_GROUP", [
      %{"Id" => 7, "Group" => "Group_7"}
    ])

    group = fn option_group ->
      [
        %{
          "Group" => "BOX",
          "SubGroups" => [
            %{
              "SubGroup" => 1,
              "List" => [
                %{
                  "Index" => 0,
                  "Item" => "Knife",
                  "Rate" => 1,
                  "RandomOptionGroup" => option_group
                }
              ]
            }
          ]
        }
      ]
    end

    reject(&Items.loaded?/0)
    reject(&Items.by_aegis/1)
    reject(&ItemGroups.loaded?/0)
    reject(&ItemGroups.fetch/1)

    write_db!(tmp_dir, "item_group_db.yml", "ITEM_GROUP_DB", group.("Group_7"))
    capture_io(fn -> Task.run([tmp_dir]) end)

    assert [%{"subgroups" => [%{"entries" => [%{"random_option_group" => 7}]}]}] =
             YamlElixir.read_from_file!(@out_file)

    write_db!(tmp_dir, "item_group_db.yml", "ITEM_GROUP_DB", group.("Group_8"))

    assert_raise Mix.Error, ~r/unknown random option group "Group_8"/, fn ->
      capture_io(fn -> Task.run([tmp_dir]) end)
    end
  end

  defp write_db!(tmp_dir, file, type, body) do
    root = Path.join([tmp_dir, "db", file])
    source = Path.join([tmp_dir, "db", "re", file])
    File.mkdir_p!(Path.dirname(source))
    header = %{"Type" => type, "Version" => 1}

    File.write!(
      root,
      Ymlr.document!(%{
        "Header" => header,
        "Footer" => %{"Imports" => [%{"Path" => "db/re/#{file}", "Mode" => "Renewal"}]}
      })
    )

    File.write!(source, Ymlr.document!(%{"Header" => header, "Body" => body}))
  end
end
