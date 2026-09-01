defmodule Aesir.ZoneServer.Mmo.ItemManagement.ImporterTest do
  use ExUnit.Case, async: false

  alias Aesir.ZoneServer.Mmo.ItemManagement.Importer
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.ItemManagement.Loader

  setup context do
    Aesir.ZoneServer.DbTestSetup.configure_root(context, "items")
  end

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
                refineable: false,
                bind_on_equip: false
              }} = Importer.to_definition(entry)
    end

    test "maps the account-binding flag" do
      entry = %{
        "Id" => 1201,
        "AegisName" => "Knife",
        "Name" => "Knife",
        "Flags" => %{"BindOnEquip" => true}
      }

      assert {:ok, %ItemDefinition{bind_on_equip: true}} = Importer.to_definition(entry)
    end

    test "maps the no-trade restriction" do
      entry = %{
        "Id" => 1201,
        "AegisName" => "Knife",
        "Name" => "Knife",
        "Trade" => %{"NoTrade" => true}
      }

      assert {:ok, definition = %ItemDefinition{no_trade: true}} = Importer.to_definition(entry)
      assert %{"no_trade" => true} = Importer.to_yaml_map(definition)
    end

    test "defaults missing Trade restriction to false and omits it from YAML" do
      entry = %{"Id" => 1201, "AegisName" => "Knife", "Name" => "Knife"}

      assert {:ok, definition = %ItemDefinition{no_trade: false}} = Importer.to_definition(entry)
      refute Map.has_key?(Importer.to_yaml_map(definition), "no_trade")
    end

    test "maps the no-guild-storage restriction and defaults it to false" do
      restricted = %{
        "Id" => 1201,
        "AegisName" => "Knife",
        "Name" => "Knife",
        "Trade" => %{"NoGuildStorage" => true}
      }

      plain = %{"Id" => 1202, "AegisName" => "Sword", "Name" => "Sword"}

      assert {:ok, %ItemDefinition{no_guild_storage: true}} = Importer.to_definition(restricted)
      assert {:ok, %ItemDefinition{no_guild_storage: false}} = Importer.to_definition(plain)
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

    test "parses bonus bAtkEle into attack_element for each supported element" do
      for {ele_str, expected} <- [
            {"Ele_Fire", :fire},
            {"Ele_Water", :water},
            {"Ele_Wind", :wind},
            {"Ele_Earth", :earth},
            {"Ele_Holy", :holy},
            {"Ele_Dark", :shadow},
            {"Ele_Ghost", :ghost},
            {"Ele_Poison", :poison},
            {"Ele_Undead", :undead},
            {"Ele_Neutral", :neutral}
          ] do
        entry = %{
          "Id" => 1755,
          "AegisName" => "Test_Arrow",
          "Name" => "Test Arrow",
          "Script" => "bonus bAtkEle,#{ele_str};"
        }

        assert {:ok, %ItemDefinition{attack_element: ^expected}} = Importer.to_definition(entry)
      end
    end

    test "attack_element is nil when no Script field" do
      entry = %{"Id" => 1750, "AegisName" => "Arrow", "Name" => "Arrow"}

      assert {:ok, %ItemDefinition{attack_element: nil}} = Importer.to_definition(entry)
    end

    test "attack_element is nil when Script has no bAtkEle bonus" do
      entry = %{
        "Id" => 1758,
        "AegisName" => "Stun_Arrow",
        "Name" => "Stun Arrow",
        "Script" => "bonus2 bAddEff,Eff_Stun,2000;"
      }

      assert {:ok, %ItemDefinition{attack_element: nil}} = Importer.to_definition(entry)
    end
  end

  describe "build_report/1" do
    defp report(failures) do
      %{
        on_use: %{considered: 10, with_script: 6, transpiled: 5},
        on_equip: %{considered: 20, with_script: 12, transpiled: 3},
        on_unequip: %{considered: 20, with_script: 8, transpiled: 2},
        failures: failures
      }
    end

    test "renders a per-hook summary table with derived unsupported counts" do
      failures = [
        {:on_use, 501, "Red Potion", {:unsupported, "produce"}},
        {:on_equip, 1140, "Fireblend", {:unsupported, {:unknown_bonus_key, "bHealPower"}}},
        {:on_equip, 2000, "X", {:unsupported, {:unknown_bonus_key, "bHealPower"}}},
        {:on_unequip, 2776, "Cool Towel", {:unsupported, {:unsupported_command, "heal"}}}
      ]

      out = Importer.build_report(report(failures))

      assert out =~ "| hook | items | with script | transpiled | unsupported |"
      assert out =~ "| on_use | 10 | 6 | 5 | 1 |"
      assert out =~ "| on_equip | 20 | 12 | 3 | 2 |"
      assert out =~ "| on_unequip | 20 | 8 | 2 | 1 |"
    end

    test "renders the on_equip rejection-reason histogram sorted descending" do
      failures =
        [
          {:on_equip, 1, "a", {:unsupported, {:unknown_bonus_key, "bHealPower"}}},
          {:on_equip, 2, "b", {:unsupported, {:unknown_bonus_key, "bHealPower"}}},
          {:on_equip, 3, "c", {:unsupported, {:unknown_bonus_key, "bHealPower"}}},
          {:on_equip, 4, "d", {:unsupported, {:unsupported_command, "bonus2"}}},
          {:on_equip, 5, "e", {:unsupported, {:conditional_assignment, "x"}}}
        ]

      out = Importer.build_report(report(failures))

      assert out =~ "## on_equip rejection reasons"
      assert out =~ "| unknown_bonus_key bHealPower | 3 |"
      assert out =~ "| unsupported_command bonus2 | 1 |"
      assert out =~ "| conditional_assignment | 1 |"

      max_pos = position(out, "unknown_bonus_key bHealPower")
      bonus2_pos = position(out, "unsupported_command bonus2")
      assert max_pos < bonus2_pos
    end

    test "renders both hooks' full failure tables" do
      failures = [
        {:on_use, 501, "Red Potion", {:unsupported, "produce"}},
        {:on_equip, 2198, "Lapine Shield", {:unsupported, {:unknown_bonus_key, "bHealPower"}}},
        {:on_unequip, 2776, "Cool Towel",
         {:unsupported, {:status_lifecycle_mismatch, %{on_equip: [:sc_summer], on_unequip: []}}}}
      ]

      out = Importer.build_report(report(failures))

      assert out =~ "## on_use failures"
      assert out =~ "| 501 | Red Potion | {:unsupported, \"produce\"} |"
      assert out =~ "## on_equip failures"

      assert out =~
               "| 2198 | Lapine Shield | {:unsupported, {:unknown_bonus_key, \"bHealPower\"}} |"

      assert out =~ "## on_unequip failures"

      assert out =~
               "| 2776 | Cool Towel | {:unsupported, {:status_lifecycle_mismatch, %{on_equip: [:sc_summer], on_unequip: []}}} |"
    end

    test "renders placeholders when a hook has no failures" do
      out = Importer.build_report(report([]))

      assert out =~ "## on_equip rejection reasons\n\n_none_"
      assert out =~ "## on_use failures\n\n_none_"
      assert out =~ "## on_equip failures\n\n_none_"
      assert out =~ "## on_unequip failures\n\n_none_"
    end

    defp position(haystack, needle) do
      {index, _} = :binary.match(haystack, needle)
      index
    end
  end

  describe "to_yaml_map/1" do
    test "encodes attack_element as a string and omits nil" do
      elemental = %ItemDefinition{
        id: 1752,
        aegis_name: "Fire_Arrow",
        name: "Fire Arrow",
        attack_element: :fire
      }

      plain = %ItemDefinition{id: 1750, aegis_name: "Arrow", name: "Arrow"}

      assert %{"attack_element" => "fire"} = Importer.to_yaml_map(elemental)
      refute Map.has_key?(Importer.to_yaml_map(plain), "attack_element")
    end

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

    test "emits bind_on_equip only when true" do
      binding = %ItemDefinition{id: 1201, aegis_name: "Knife", name: "Knife", bind_on_equip: true}
      plain = %ItemDefinition{id: 1750, aegis_name: "Arrow", name: "Arrow"}

      assert %{"bind_on_equip" => true} = Importer.to_yaml_map(binding)
      refute Map.has_key?(Importer.to_yaml_map(plain), "bind_on_equip")
    end

    test "encodes on_equip as DSL source via EquipScript.to_source/1 and omits it when nil" do
      program = [{:bonus, :smatk, 3}]

      with_program = %ItemDefinition{id: 490_160, aegis_name: "X", name: "X", on_equip: program}
      without_program = %ItemDefinition{id: 1750, aegis_name: "Arrow", name: "Arrow"}

      assert %{"on_equip" => source} = Importer.to_yaml_map(with_program)
      assert source == "bonus(ctx, :smatk, 3)"
      refute Map.has_key?(Importer.to_yaml_map(without_program), "on_equip")
    end

    test "encodes on_unequip as DSL source via EquipScript.to_source/1 and omits it when nil" do
      program = [{:status_end, :sc_summer}]

      with_program = %ItemDefinition{id: 2776, aegis_name: "X", name: "X", on_unequip: program}
      without_program = %ItemDefinition{id: 1750, aegis_name: "Arrow", name: "Arrow"}

      assert %{"on_unequip" => source} = Importer.to_yaml_map(with_program)
      assert source == "status_end(ctx, :sc_summer)"
      refute Map.has_key?(Importer.to_yaml_map(without_program), "on_unequip")
    end

    @tag :tmp_dir
    test "round-trips paired equipment programs back through the Loader", %{tmp_dir: dir} do
      definition = %ItemDefinition{
        id: 2776,
        aegis_name: "Cool_Towel",
        name: "Adventurer's Trusty Towel",
        type: :armor,
        on_equip: [{:status_start, :sc_summer, :infinite, 0}],
        on_unequip: [{:status_end, :sc_summer}]
      }

      yaml = Ymlr.document!([Importer.to_yaml_map(definition)])
      File.write!(Path.join(dir, "items.yml"), yaml)

      assert %{by_id: %{2776 => ^definition}} = Loader.load()
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

      assert %{by_id: %{1201 => ^definition}} = Loader.load()
    end

    @tag :tmp_dir
    test "round-trips attack_element through the Loader", %{tmp_dir: dir} do
      definition = %ItemDefinition{
        id: 1752,
        aegis_name: "Fire_Arrow",
        name: "Fire Arrow",
        type: :ammo,
        subtype: :arrow,
        attack: 30,
        locations: [:ammo],
        attack_element: :fire
      }

      yaml = Ymlr.document!([Importer.to_yaml_map(definition)])
      File.write!(Path.join(dir, "items.yml"), yaml)

      assert %{by_id: %{1752 => ^definition}} = Loader.load()
    end
  end
end
