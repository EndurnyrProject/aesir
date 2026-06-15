defmodule Aesir.ZoneServer.Mmo.ItemManagement.ImporterTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.ItemManagement.Importer
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.ItemManagement.Loader

  describe "to_definition/1" do
    test "maps a weapon, converting Type/SubType/Jobs/Locations to atoms" do
      entry = %{
        "Id" => 1201,
        "AegisName" => "Knife",
        "Name" => "Knife",
        "Type" => "Weapon",
        "SubType" => "Dagger",
        "Buy" => 50,
        "Weight" => 400,
        "Attack" => 17,
        "Range" => 1,
        "Slots" => 3,
        "Jobs" => %{"Swordman" => true, "BardDancer" => true},
        "Locations" => %{"Right_Hand" => true},
        "WeaponLevel" => 1,
        "EquipLevelMin" => 1,
        "Refineable" => true
      }

      assert {:ok,
              %ItemDefinition{
                id: 1201,
                aegis_name: "Knife",
                name: "Knife",
                type: :weapon,
                subtype: :dagger,
                buy: 50,
                weight: 400,
                attack: 17,
                range: 1,
                slots: 3,
                jobs: [:bard_dancer, :swordman],
                locations: [:right_hand],
                weapon_level: 1,
                equip_level_min: 1,
                refineable: true
              }} = Importer.to_definition(entry)
    end

    test "maps a healing item and applies defaults for absent fields" do
      entry = %{
        "Id" => 501,
        "AegisName" => "Red_Potion",
        "Name" => "Red Potion",
        "Type" => "Healing",
        "Buy" => 10,
        "Weight" => 70
      }

      assert {:ok,
              %ItemDefinition{
                id: 501,
                aegis_name: "Red_Potion",
                name: "Red Potion",
                type: :healing,
                subtype: nil,
                buy: 10,
                weight: 70,
                attack: 0,
                slots: 0,
                jobs: [],
                locations: [],
                weapon_level: nil,
                refineable: false
              }} = Importer.to_definition(entry)
    end

    test "defaults missing Type to :etc (rAthena default)" do
      entry = %{"Id" => 909, "AegisName" => "Jellopy", "Name" => "Jellopy", "Weight" => 1}

      assert {:ok, %ItemDefinition{type: :etc}} = Importer.to_definition(entry)
    end

    test "returns an error for an unknown Type" do
      entry = %{"Id" => 1, "AegisName" => "X", "Name" => "X", "Type" => "Bogus"}

      assert {:error, {:unknown_type, "Bogus"}} = Importer.to_definition(entry)
    end

    test "normalizes inconsistent Type casing in the source data" do
      for casing <- ["DelayConsume", "Delayconsume"] do
        entry = %{"Id" => 1, "AegisName" => "X", "Name" => "X", "Type" => casing}
        assert {:ok, %ItemDefinition{type: :delay_consume}} = Importer.to_definition(entry)
      end
    end

    test "maps weapon SubType to the WeaponTypes atom vocabulary" do
      entry = %{
        "Id" => 1,
        "AegisName" => "S",
        "Name" => "S",
        "Type" => "Weapon",
        "SubType" => "1hSword"
      }

      assert {:ok, %ItemDefinition{subtype: :one_handed_sword}} = Importer.to_definition(entry)
    end

    test "returns an error for an unknown SubType" do
      entry = %{
        "Id" => 1,
        "AegisName" => "S",
        "Name" => "S",
        "Type" => "Weapon",
        "SubType" => "Bogus"
      }

      assert {:error, {:unknown_subtype, "Bogus"}} = Importer.to_definition(entry)
    end
  end

  describe "to_yaml_map/1" do
    test "stringifies keys/atoms and omits default-valued fields" do
      definition = %ItemDefinition{
        id: 1201,
        aegis_name: "Knife",
        name: "Knife",
        type: :weapon,
        subtype: :dagger,
        weight: 400,
        attack: 17,
        jobs: [:bard_dancer, :swordman],
        locations: [:right_hand],
        refineable: true
      }

      map = Importer.to_yaml_map(definition)

      assert %{
               "id" => 1201,
               "aegis_name" => "Knife",
               "name" => "Knife",
               "type" => "weapon",
               "subtype" => "dagger",
               "weight" => 400,
               "attack" => 17,
               "jobs" => ["bard_dancer", "swordman"],
               "locations" => ["right_hand"],
               "refineable" => true
             } = map

      refute Map.has_key?(map, "magic_attack")
      refute Map.has_key?(map, "sell")
      refute Map.has_key?(map, "armor_level")
    end

    @tag :tmp_dir
    test "round-trips a definition back through the Loader", %{tmp_dir: dir} do
      definition = %ItemDefinition{
        id: 1201,
        aegis_name: "Angel's_Knife",
        name: "Angel's Knife: the \"best\"",
        type: :weapon,
        subtype: :dagger,
        weight: 400,
        attack: 17,
        jobs: [:bard_dancer, :swordman],
        locations: [:right_hand],
        refineable: true
      }

      yaml = Ymlr.document!([Importer.to_yaml_map(definition)])
      File.write!(Path.join(dir, "items.yml"), yaml)

      assert %{by_id: %{1201 => ^definition}} = Loader.load(dir)
    end
  end
end
