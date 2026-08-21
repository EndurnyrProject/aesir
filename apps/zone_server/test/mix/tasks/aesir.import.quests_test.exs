defmodule Mix.Tasks.Aesir.Import.QuestsTest do
  use ExUnit.Case, async: false

  alias Aesir.ZoneServer.Mmo.QuestManagement.Importer
  alias Aesir.ZoneServer.Mmo.QuestManagement.Loader
  alias Aesir.ZoneServer.Mmo.QuestManagement.QuestDefinition

  setup context do
    Aesir.ZoneServer.DbTestSetup.configure_root(context, "quests")
  end

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

    test "resolves a named Target mob and keeps a filter-only target's fields, dropping the target with an unresolvable Mob" do
      {definition, dropped} = Importer.to_definition(Enum.at(@fixture, 1))

      assert %QuestDefinition{id: 200, targets: targets} = definition

      assert targets == [
               %{mob_id: 1001, count: 10},
               %{count: 50, race: "DemiHuman", min_level: 140}
             ]

      assert dropped == [{200, :target_mob, "DOES_NOT_EXIST_MOB"}]
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
      tmp_dir: dir
    } do
      {definitions, _dropped} =
        Enum.map_reduce(@fixture, [], fn entry, acc ->
          {definition, dropped} = Importer.to_definition(entry)
          {definition, acc ++ dropped}
        end)

      yaml = definitions |> Enum.map(&Importer.to_yaml_map/1) |> Ymlr.document!()
      File.write!(Path.join(dir, "quests.yml"), yaml)

      assert %{by_id: by_id} = Loader.load()

      assert %QuestDefinition{id: 100, time_limit: "4h"} = Map.fetch!(by_id, 100)

      assert %QuestDefinition{
               id: 200,
               targets: [
                 %{mob_id: 1001, count: 10},
                 %{count: 50, race: "DemiHuman", min_level: 140}
               ]
             } = Map.fetch!(by_id, 200)

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

    test "a Count of 0 skips the target on import" do
      entry = %{
        "Id" => 500,
        "Title" => "Skipped Objective",
        "Targets" => [%{"Mob" => "SCORPION", "Count" => 0}]
      }

      {definition, dropped} = Importer.to_definition(entry)

      assert definition.targets == []
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
end
