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
                    "Announced" => true
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
end
