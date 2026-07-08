defmodule Mix.Tasks.Aesir.Import.RefineTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.Aesir.Import.Refine, as: Task

  @body %{
    "Body" => [
      %{
        "Group" => "Weapon",
        "Levels" => [
          %{
            "Level" => 1,
            "RefineLevels" => [
              %{
                "Level" => 1,
                "Bonus" => 200,
                "Chances" => [
                  %{"Type" => "Normal", "Rate" => 10_000, "Price" => 50, "Material" => "Phracon"}
                ]
              },
              %{
                "Level" => 8,
                "Bonus" => 1600,
                "RandomBonus" => 300,
                "BlacksmithBlessingAmount" => 1,
                "BroadcastSuccess" => true,
                "Chances" => [
                  %{
                    "Type" => "Normal",
                    "Rate" => 6000,
                    "Price" => 50,
                    "Material" => "Phracon",
                    "BreakingRate" => 10_000
                  },
                  %{
                    "Type" => "HD",
                    "Rate" => 6000,
                    "Price" => 20_000,
                    "Material" => "HD_Oridecon",
                    "DowngradeAmount" => 1
                  }
                ]
              }
            ]
          }
        ]
      },
      %{
        "Group" => "Armor",
        "Levels" => [
          %{
            "Level" => 1,
            "RefineLevels" => [
              %{
                "Level" => 5,
                "Bonus" => 600,
                "Chances" => [
                  %{
                    "Type" => "Enriched",
                    "Rate" => 9000,
                    "Price" => 2000,
                    "Material" => "Enriched_Elunium",
                    "BreakingRate" => 10_000
                  }
                ]
              }
            ]
          }
        ]
      }
    ]
  }

  describe "groups_from_body/1" do
    test "preserves all groups with normalized snake_case names" do
      groups = Task.groups_from_body(@body)

      assert Enum.map(groups, & &1["group"]) == ["weapon", "armor"]
    end

    test "preserves item levels and refine levels with defaults filled in" do
      [weapon | _] = Task.groups_from_body(@body)
      [item_level] = weapon["levels"]

      assert item_level["level"] == 1
      [refine1, refine8] = item_level["refine_levels"]

      assert refine1["level"] == 1
      assert refine1["bonus"] == 200
      assert refine1["random_bonus"] == 0
      assert refine1["blacksmith_blessing_amount"] == 0
      assert refine1["broadcast_success"] == false
      assert refine1["broadcast_failure"] == false

      assert refine8["bonus"] == 1600
      assert refine8["random_bonus"] == 300
      assert refine8["blacksmith_blessing_amount"] == 1
      assert refine8["broadcast_success"] == true
    end

    test "preserves each cost type's chance fields, keeping material as an aegis string" do
      [weapon | _] = Task.groups_from_body(@body)
      [item_level] = weapon["levels"]
      [_refine1, refine8] = item_level["refine_levels"]
      [normal, hd] = refine8["chances"]

      assert normal == %{
               "type" => "normal",
               "rate" => 6000,
               "price" => 50,
               "material" => "Phracon",
               "breaking_rate" => 10_000,
               "downgrade_amount" => 0
             }

      assert hd == %{
               "type" => "hd",
               "rate" => 6000,
               "price" => 20_000,
               "material" => "HD_Oridecon",
               "breaking_rate" => 0,
               "downgrade_amount" => 1
             }
    end

    test "preserves armor breaking rate for a high refine level" do
      [_weapon, armor] = Task.groups_from_body(@body)
      [item_level] = armor["levels"]
      [refine5] = item_level["refine_levels"]
      [enriched] = refine5["chances"]

      assert enriched["breaking_rate"] == 10_000
    end
  end
end
