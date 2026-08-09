defmodule Aesir.ZoneServer.Mmo.MobManagement.ImporterTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Aesir.ZoneServer.Mmo.MobManagement.Importer
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDrop

  defp entry(overrides) do
    Map.merge(%{"Id" => 1001, "AegisName" => "TEST", "Name" => "Test Mob"}, overrides)
  end

  describe "to_definition/1 mode derivation" do
    test "an Ai type that decodes to MD_AGGRESSIVE yields :aggressive" do
      {:ok, definition} = Importer.to_definition(entry(%{"Ai" => 4}))

      assert :aggressive in definition.modes
    end

    test "a boss class still yields :boss" do
      {:ok, definition} = Importer.to_definition(entry(%{"Class" => "Boss"}))

      assert :boss in definition.modes
    end

    test "boss + aggressive-decoding Ai + explicit aggressive dedup" do
      {:ok, definition} =
        Importer.to_definition(
          entry(%{"Class" => "Boss", "Ai" => 4, "Modes" => %{"Aggressive" => true}})
        )

      assert Enum.count(definition.modes, &(&1 == :aggressive)) == 1
      assert Enum.count(definition.modes, &(&1 == :boss)) == 1
      assert definition.modes == Enum.uniq(definition.modes)
    end

    test "a non-aggressive Ai type (6, empty bitmask) yields no derived modes" do
      {:ok, definition} = Importer.to_definition(entry(%{"Ai" => 6}))

      assert definition.modes == []
    end

    test "missing Ai defaults to no derived modes" do
      {:ok, definition} = Importer.to_definition(entry(%{}))

      assert definition.modes == []
    end
  end

  describe "to_definition/1 RaceGroups" do
    test "resolves true groups into sorted atoms" do
      {:ok, definition} =
        Importer.to_definition(entry(%{"RaceGroups" => %{"Orc" => true, "Goblin" => true}}))

      assert definition.race_groups == [:goblin, :orc]
    end

    test "excludes false groups" do
      {:ok, definition} =
        Importer.to_definition(entry(%{"RaceGroups" => %{"Goblin" => true, "Orc" => false}}))

      assert definition.race_groups == [:goblin]
    end

    test "warns and skips unknown groups while resolving known groups" do
      log =
        capture_log(fn ->
          assert {:ok, %{race_groups: [:goblin]}} =
                   Importer.to_definition(
                     entry(%{"RaceGroups" => %{"Goblin" => true, "Unknown" => true}})
                   )
        end)

      assert log =~ "Unknown secondary monster group: Unknown"
    end

    test "ignores sibling flags when no RaceGroups map exists" do
      {:ok, definition} = Importer.to_definition(entry(%{"Mvp" => true}))

      assert definition.race_groups == []
    end

    test "encodes groups and omits the empty default" do
      {:ok, definition} = Importer.to_definition(entry(%{}))

      assert Importer.to_yaml_map(%{definition | race_groups: [:golem]})["race_groups"] == [
               "golem"
             ]

      refute Map.has_key?(Importer.to_yaml_map(definition), "race_groups")
    end
  end

  describe "to_definition/1 MVP reward fields" do
    test "MvpExp parses to mvp_exp" do
      {:ok, definition} = Importer.to_definition(entry(%{"MvpExp" => 109_044}))

      assert definition.mvp_exp == 109_044
    end

    test "missing MvpExp defaults mvp_exp to 0" do
      {:ok, definition} = Importer.to_definition(entry(%{}))

      assert definition.mvp_exp == 0
    end

    test "MvpDrops parses into MobDrop structs" do
      {:ok, definition} =
        Importer.to_definition(
          entry(%{
            "MvpDrops" => [
              %{"Item" => "Bs_Making_S", "Rate" => 5000},
              %{"Item" => "Baphomet_Doll", "Rate" => 2500, "RandomOptionGroup" => "some_group"}
            ]
          })
        )

      assert definition.mvp_drops == [
               %MobDrop{item: "Bs_Making_S", rate: 5000},
               %MobDrop{item: "Baphomet_Doll", rate: 2500, random_option_group: "some_group"}
             ]
    end

    test "missing MvpDrops defaults mvp_drops to []" do
      {:ok, definition} = Importer.to_definition(entry(%{}))

      assert definition.mvp_drops == []
    end

    test "MvpDrops and Drops stay strictly separate" do
      {:ok, definition} =
        Importer.to_definition(
          entry(%{
            "Drops" => [%{"Item" => "Jellopy", "Rate" => 7000}],
            "MvpDrops" => [%{"Item" => "Bs_Making_S", "Rate" => 5000}]
          })
        )

      assert definition.drops == [%MobDrop{item: "Jellopy", rate: 7000}]
      assert definition.mvp_drops == [%MobDrop{item: "Bs_Making_S", rate: 5000}]
    end
  end
end
