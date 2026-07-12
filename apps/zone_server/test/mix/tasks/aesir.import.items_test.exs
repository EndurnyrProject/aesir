defmodule Mix.Tasks.Aesir.Import.ItemsTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.ItemManagement.Importer
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Mix.Tasks.Aesir.Import.Items

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
               Items.apply_transpile(definition(%{type: :weapon}), "bonus bMaxHP,100;")
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

  describe "bAtkEle carve-out" do
    test "a Fireblend-style item keeps attack_element while its on_equip is rejected" do
      script = "bonus bAtkEle,Ele_Fire;"

      entry = %{
        "Id" => 1140,
        "AegisName" => "Fireblend",
        "Name" => "Fireblend",
        "Type" => "Weapon",
        "SubType" => "1hSword",
        "Script" => script
      }

      assert {:ok, %ItemDefinition{attack_element: :fire} = def} = Importer.to_definition(entry)

      assert {%ItemDefinition{attack_element: :fire, on_equip: nil},
              {:on_equip, 1140, "Fireblend", {:unsupported, {:unknown_bonus_key, "bAtkEle"}}}} =
               Items.apply_transpile(def, script)
    end
  end
end
