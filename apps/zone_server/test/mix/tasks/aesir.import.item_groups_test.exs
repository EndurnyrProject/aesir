defmodule Mix.Tasks.Aesir.Import.ItemGroupsTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Mix.Tasks.Aesir.Import.ItemGroups, as: Task

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
    source = Path.join([tmp_dir, "db", "re", "item_group_db.yml"])
    File.mkdir_p!(Path.dirname(source))

    File.write!(
      source,
      Ymlr.document!(%{
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
