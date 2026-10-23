defmodule Mix.Tasks.Aesir.Import.QuestsTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Aesir.ZoneServer.DbTestSetup
  alias Aesir.ZoneServer.Mmo.QuestManagement.Importer
  alias Aesir.ZoneServer.Mmo.QuestManagement.Loader
  alias Aesir.ZoneServer.Mmo.QuestManagement.QuestDefinition
  alias Mix.Tasks.Aesir.Import.Quests, as: Task

  @fixture [
    %{"Id" => 100, "Title" => "Timed Quest", "TimeLimit" => "4h"},
    %{
      "Id" => 200,
      "Title" => "Filtered Hunt",
      "Targets" => [
        %{"Mob" => "SCORPION", "Count" => 10},
        %{"Id" => 1, "Count" => 50, "Race" => "DemiHuman", "MinLevel" => 140},
        %{"Mob" => "DOES_NOT_EXIST_MOB", "Count" => 5}
      ]
    },
    %{
      "Id" => 300,
      "Title" => "Bone Collection",
      "Drops" => [
        %{"Mob" => "SCORPION", "Item" => "Boody_Red", "Count" => 1, "Rate" => 5000}
      ]
    }
  ]

  describe "to_definition/1" do
    test "carries the raw TimeLimit string through unchanged" do
      {definition, dropped} = Importer.to_definition(Enum.at(@fixture, 0))

      assert %QuestDefinition{id: 100, title: "Timed Quest", time_limit: "4h"} = definition
      assert dropped == []
    end

    test "skips the whole quest when a Target Mob does not resolve" do
      {definition, dropped} = Importer.to_definition(Enum.at(@fixture, 1))

      assert definition == nil
      assert dropped == [{200, :target_mob, "DOES_NOT_EXIST_MOB"}]
    end

    test "resolves a named Target mob and keeps a filter-only target's fields" do
      entry = %{Enum.at(@fixture, 1) | "Targets" => Enum.take(Enum.at(@fixture, 1)["Targets"], 2)}
      {definition, dropped} = Importer.to_definition(entry)

      assert %QuestDefinition{id: 200, targets: targets} = definition

      assert targets == [
               %{mob_id: 1001, count: 10},
               %{count: 50, race: "DemiHuman", min_level: 140}
             ]

      assert dropped == []
    end

    test "resolves Drop mob and item aegis names to ids" do
      {definition, dropped} = Importer.to_definition(Enum.at(@fixture, 2))

      assert %QuestDefinition{id: 300, drops: drops} = definition
      assert drops == [%{mob_id: 1001, item_id: 990, count: 1, rate: 5000}]
      assert dropped == []
    end
  end

  describe "golden-file round trip" do
    @tag :tmp_dir
    test "the emitted YAML parses back through the real Loader with the same data", %{
      tmp_dir: root
    } do
      {definitions, _dropped} =
        Enum.map_reduce(@fixture, [], fn entry, acc ->
          {definition, dropped} = Importer.to_definition(entry)
          {definition, acc ++ dropped}
        end)

      yaml =
        definitions
        |> Enum.reject(&is_nil/1)
        |> Enum.map(&Importer.to_yaml_map/1)
        |> Ymlr.document!()

      {:ok, tmp_dir: dir} = DbTestSetup.configure_root(%{tmp_dir: root}, "quests")
      File.write!(Path.join(dir, "quests.yml"), yaml)

      assert %{by_id: by_id} = Loader.load()

      assert %QuestDefinition{id: 100, time_limit: "4h"} = Map.fetch!(by_id, 100)

      refute Map.has_key?(by_id, 200)

      assert %QuestDefinition{
               id: 300,
               drops: [%{mob_id: 1001, item_id: 990, count: 1, rate: 5000}]
             } =
               Map.fetch!(by_id, 300)
    end
  end

  describe "map_mob_targets/drops with unresolvable names" do
    test "an unresolvable MapMobTargets name is dropped from the list, keeping the rest of the target" do
      entry = %{
        "Id" => 400,
        "Title" => "Illusion Hunt",
        "Targets" => [
          %{
            "Id" => 1,
            "Count" => 100,
            "Location" => "pay_d03_i",
            "MapMobTargets" => %{"SCORPION" => true, "NOT_A_MOB" => true}
          }
        ]
      }

      {definition, dropped} = Importer.to_definition(entry)

      assert %QuestDefinition{
               targets: [%{count: 100, map: "pay_d03_i", mobs_allowed: [1001]}]
             } = definition

      assert dropped == [{400, :map_mob_target, "NOT_A_MOB"}]
    end

    test "a Count of 0 keeps the target with a count of 0" do
      entry = %{
        "Id" => 500,
        "Title" => "Zero Objective",
        "Targets" => [%{"Mob" => "SCORPION", "Count" => 0}]
      }

      {definition, dropped} = Importer.to_definition(entry)

      assert definition.targets == [%{mob_id: 1001, count: 0}]
      assert dropped == []
    end

    test "an unresolvable Drop mob name is dropped, keeping the quest" do
      entry = %{
        "Id" => 600,
        "Title" => "Bad Drop Mob",
        "Drops" => [%{"Mob" => "NOT_A_MOB", "Item" => "Boody_Red", "Rate" => 5000}]
      }

      {definition, dropped} = Importer.to_definition(entry)

      assert definition.drops == []
      assert dropped == [{600, :drop_mob, "NOT_A_MOB"}]
    end

    test "an unresolvable Drop item name is dropped, keeping the quest" do
      entry = %{
        "Id" => 700,
        "Title" => "Bad Drop Item",
        "Drops" => [%{"Mob" => "SCORPION", "Item" => "NOT_AN_ITEM", "Rate" => 5000}]
      }

      {definition, dropped} = Importer.to_definition(entry)

      assert definition.drops == []
      assert dropped == [{700, :drop_item, "NOT_AN_ITEM"}]
    end
  end

  describe "rows read in the reference's parse order" do
    @resolvers %{
      mob: &__MODULE__.mob/1,
      item: &__MODULE__.item/1,
      map?: &__MODULE__.map?/1
    }

    def mob("PORING"), do: {:ok, 1002}
    def mob("poring"), do: {:ok, 1002}
    def mob("LUNATIC"), do: {:ok, 1063}
    def mob(_name), do: :error

    def item("Jellopy"), do: {:ok, %{id: 909, stackable?: true}}
    def item("Knife"), do: {:ok, %{id: 1201, stackable?: false}}
    def item(_name), do: :error

    def map?(name), do: name == "prontera"

    defp quest(fields), do: Map.merge(%{"Id" => 900, "Title" => "Parse"}, fields)

    defp convert(fields), do: Importer.to_definition(quest(fields), @resolvers)

    test "a repeated target key merges into the first target and lists it again" do
      {definition, []} =
        convert(%{
          "Targets" => [
            %{"Mob" => "PORING", "Count" => 5},
            %{"Mob" => "LUNATIC", "Count" => 2},
            %{"Mob" => "poring", "Count" => 9, "Race" => "Brute"}
          ]
        })

      assert definition.targets == [
               %{mob_id: 1002, count: 9},
               %{mob_id: 1063, count: 2},
               %{mob_id: 1002, count: 9}
             ]
    end

    test "a repeated Id merges its filters and MapMobTargets, false removing a monster" do
      {definition, []} =
        convert(%{
          "Targets" => [
            %{"Id" => 1, "Count" => 5, "MinLevel" => 10, "MapMobTargets" => %{"PORING" => true}},
            %{
              "Id" => 1,
              "Size" => "Large",
              "MapMobTargets" => %{"PORING" => false, "LUNATIC" => true}
            }
          ]
        })

      target = %{count: 5, min_level: 10, size: "Large", mobs_allowed: [1063]}
      assert definition.targets == [target, target]
    end

    test "a MaxLevel below MinLevel becomes 275, and MaxLevel alone sets the minimum to 1" do
      {definition, []} =
        convert(%{
          "Targets" => [
            %{"Id" => 1, "Count" => 1, "MinLevel" => 90, "MaxLevel" => 80},
            %{"Id" => 2, "Count" => 1, "MaxLevel" => 80}
          ]
        })

      assert definition.targets == [
               %{count: 1, min_level: 90, max_level: 275},
               %{count: 1, min_level: 1, max_level: 80}
             ]
    end

    test "the minimum is set at the end of each row, so a later MinLevel keeps the earlier MaxLevel" do
      {definition, []} =
        convert(%{
          "Targets" => [
            %{"Id" => 1, "Count" => 1, "MaxLevel" => 80},
            %{"Id" => 1, "MinLevel" => 150}
          ]
        })

      assert [%{min_level: 150, max_level: 80}, _same] = definition.targets
    end

    test "filters on a Mob target are not read" do
      {definition, []} =
        convert(%{"Targets" => [%{"Mob" => "PORING", "Count" => 1, "Race" => "Nope"}]})

      assert definition.targets == [%{mob_id: 1002, count: 1}]
    end

    test "a refused target skips the whole quest" do
      refusals = [
        {[
           %{"Id" => 1, "Count" => 1},
           %{"Id" => 2, "Count" => 1},
           %{"Id" => 3, "Count" => 1},
           %{"Id" => 4, "Count" => 1}
         ], "more than 3 targets"},
        {[%{"Count" => 1}], "target without Mob or Id"},
        {[%{"Id" => 0, "Count" => 1}], "target Id 0"},
        {[%{"Id" => 1}], "new target without Count"},
        {[%{"Id" => 1, "Count" => 1, "Race" => "Player_Human"}], "Race Player_Human"},
        {[%{"Id" => 1, "Count" => 1, "Size" => "Huge"}], "Size Huge"},
        {[%{"Id" => 1, "Count" => 1, "Element" => "Weapon"}], "Element Weapon"},
        {[%{"Id" => 1, "Count" => 70_000}], "Count 70000"},
        {[%{"Id" => 1, "Count" => 1, "MapMobTargets" => %{"PORING" => "yes"}}],
         ~s(MapMobTargets PORING: "yes")}
      ]

      for {targets, reason} <- refusals do
        assert {nil, [{900, :invalid, ^reason}]} = convert(%{"Targets" => targets})
      end
    end

    test "race, size and element names compare case-insensitively" do
      {definition, []} =
        convert(%{
          "Targets" => [
            %{
              "Id" => 1,
              "Count" => 1,
              "Race" => "demihuman",
              "Size" => "ALL",
              "Element" => "Dark"
            }
          ]
        })

      assert [%{race: "demihuman", size: "ALL", element: "Dark"}] = definition.targets
    end

    test "a repeated drop monster merges into the first drop and lists it again" do
      {definition, []} =
        convert(%{
          "Drops" => [
            %{"Mob" => "PORING", "Item" => "Jellopy", "Rate" => 100, "Count" => 4},
            %{"Item" => "Jellopy", "Rate" => 50},
            %{"Mob" => "PORING", "Item" => "Knife", "Count" => 3}
          ]
        })

      knife = %{mob_id: 1002, item_id: 1201, count: 1, rate: 100}

      assert definition.drops == [
               knife,
               %{mob_id: 0, item_id: 909, count: 1, rate: 50},
               knife
             ]
    end

    test "a new drop without Item or Rate, or with an unknown name, skips only that row" do
      {definition, dropped} =
        convert(%{
          "Drops" => [
            %{"Mob" => "PORING", "Rate" => 100},
            %{"Mob" => "PORING", "Item" => "Jellopy"},
            %{"Mob" => "NOPE", "Item" => "Jellopy", "Rate" => 1},
            %{"Item" => "Nope", "Rate" => 1},
            %{"Mob" => "LUNATIC", "Item" => "Jellopy", "Rate" => 1}
          ]
        })

      assert definition.drops == [%{mob_id: 1063, item_id: 909, count: 1, rate: 1}]

      assert dropped == [
               {900, :drop_invalid, "no Item"},
               {900, :drop_invalid, "no Rate"},
               {900, :drop_mob, "NOPE"},
               {900, :drop_item, "Nope"}
             ]
    end

    test "an unknown Item on a repeated drop leaves the earlier drop as it was" do
      {definition, [{900, :drop_item, "Nope"}]} =
        convert(%{
          "Drops" => [
            %{"Item" => "Jellopy", "Rate" => 100},
            %{"Item" => "Nope", "Rate" => 5, "Count" => 9}
          ]
        })

      assert definition.drops == [%{mob_id: 0, item_id: 909, count: 1, rate: 100}]
    end

    test "a Location must be All or in the map index" do
      assert {%QuestDefinition{targets: [%{map: "prontera"}, %{map: "all"}]}, []} =
               convert(%{
                 "Targets" => [
                   %{"Id" => 1, "Count" => 1, "Location" => "prontera"},
                   %{"Id" => 2, "Count" => 1, "Location" => "all"}
                 ]
               })

      assert {nil, [{900, :invalid, "Location nowhere"}]} =
               convert(%{"Targets" => [%{"Id" => 1, "Count" => 1, "Location" => "nowhere"}]})
    end

    test "a numeric name is read as text and fails to resolve; a non-scalar one skips the quest" do
      assert {nil, [{900, :target_mob, "1002"}]} =
               convert(%{"Targets" => [%{"Mob" => 1002, "Count" => 1}]})

      assert {%QuestDefinition{drops: []}, [{900, :drop_item, "909"}]} =
               convert(%{"Drops" => [%{"Item" => 909, "Rate" => 1}]})

      assert {nil, [{900, :invalid, "MapName [1]"}]} =
               convert(%{"Targets" => [%{"Id" => 1, "Count" => 1, "MapName" => [1]}]})
    end

    test "a malformed drop value skips the whole quest" do
      assert {nil, [{900, :invalid, "drop Rate -1"}]} =
               convert(%{"Drops" => [%{"Item" => "Jellopy", "Rate" => -1}]})
    end
  end

  describe "run/1 against a reference tree" do
    @out_file Path.join(~w(apps zone_server priv db re quests quests.yml))

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

    defp write_db(root, file, type, body) do
      File.mkdir_p!(Path.join([root, "db", "re"]))

      File.write!(
        Path.join([root, "db", file]),
        Ymlr.document!(%{
          "Header" => %{"Type" => type, "Version" => 1},
          "Footer" => %{"Imports" => [%{"Path" => "db/re/#{file}", "Mode" => "Renewal"}]}
        })
      )

      File.write!(
        Path.join([root, "db", "re", file]),
        Ymlr.document!(%{"Header" => %{"Type" => type, "Version" => 1}, "Body" => body})
      )
    end

    @tag :tmp_dir
    test "resolves names against the same mode's reference databases and map index", %{
      tmp_dir: root
    } do
      write_db(root, "mob_db.yml", "MOB_DB", [
        %{"Id" => 1063, "AegisName" => "LUNATIC"},
        %{"Id" => 1002, "AegisName" => "LUNATIC"},
        %{"Id" => 1113, "AegisName" => "OLD_NAME"},
        %{"Id" => 1113, "AegisName" => "DROPS"}
      ])

      write_db(root, "item_db.yml", "ITEM_DB", [
        %{"Id" => 909, "AegisName" => "Jellopy"},
        %{"Id" => 1201, "AegisName" => "Knife", "Type" => "Weapon"}
      ])

      File.write!(
        Path.join([root, "db", "map_index.txt"]),
        "// header\nprontera\t1\nprt_fild01.gat\n"
      )

      write_db(root, "quest_db.yml", "QUEST_DB", [
        %{
          "Id" => 1,
          "Title" => "Resolved",
          "Targets" => [
            %{"Mob" => "lunatic", "Count" => 2},
            %{"Id" => 1, "Count" => 3, "Location" => "prt_fild01"}
          ],
          "Drops" => [
            %{"Mob" => "drops", "Item" => "knife", "Count" => 5, "Rate" => 100},
            %{"Mob" => "OLD_NAME", "Item" => "Jellopy", "Rate" => 100}
          ]
        },
        %{
          "Id" => 2,
          "Title" => "Unknown Map",
          "Targets" => [%{"Id" => 1, "Count" => 1, "Location" => "nowhere"}]
        }
      ])

      output = capture_io(fn -> Task.run([root, "--mode", "re"]) end)

      assert YamlElixir.read_from_file!(@out_file) == [
               %{
                 "id" => 1,
                 "title" => "Resolved",
                 "targets" => [
                   %{"mob_id" => 1002, "count" => 2},
                   %{"count" => 3, "map" => "prt_fild01"}
                 ],
                 "drops" => [%{"mob_id" => 1113, "item_id" => 1201, "count" => 1, "rate" => 100}]
               }
             ]

      assert output =~ ~s(quest 1 drop_mob: "OLD_NAME")
      assert output =~ ~s(quest 2 invalid: "Location nowhere")
    end
  end
end
