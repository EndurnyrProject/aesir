defmodule Aesir.ZoneServer.Unit.Inventory.AmmoCompatibilityTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.Commons.GameMode
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Unit.Inventory

  setup :set_mimic_private

  test "equip_ammo_mismatch_test" do
    stub_definitions(:shotgun)
    ctx = %{job_id: 0, base_level: 99, sex: "M"}
    weapon = %InventoryItem{nameid: 90_001, amount: 1, equip: 34, identify: 1}
    arrow = %InventoryItem{nameid: 90_002, amount: 10, identify: 1}
    bullet = %InventoryItem{nameid: 90_003, amount: 10, identify: 1}
    inventory = %{0 => weapon, 1 => arrow, 2 => bullet}

    assert {:error, :wrong_ammo} = Inventory.equip(inventory, 1, 32_768, ctx)

    assert {:ok, equipped, {:equipped, 2, 32_768, []}} =
             Inventory.equip(inventory, 2, 32_768, ctx)

    assert equipped[2].equip == 32_768
  end

  test "arrows require a bow, musical instrument or whip, but kunai remain unrestricted" do
    stub_definitions(:dagger)
    ctx = %{job_id: 0, base_level: 99, sex: "M"}

    inventory = %{
      0 => %InventoryItem{nameid: 90_001, amount: 1, equip: 2, identify: 1},
      1 => %InventoryItem{nameid: 90_002, amount: 10, identify: 1},
      2 => %InventoryItem{nameid: 90_004, amount: 10, identify: 1}
    }

    assert {:error, :wrong_ammo} = Inventory.equip(inventory, 1, 32_768, ctx)
    assert {:ok, _, _} = Inventory.equip(inventory, 2, 32_768, ctx)
    assert {:error, :wrong_ammo} = Inventory.equip(Map.delete(inventory, 0), 1, 32_768, ctx)
  end

  test "equip ammo follows the weapon and mode restrictions, including shells and renewal grenades" do
    launcher_ammo = if GameMode.mode() == :renewal, do: [:bullet, :shell], else: [:grenade]
    unrestricted = if GameMode.mode() == :renewal, do: [:kunai, :grenade], else: [:kunai]

    for {weapon, accepted} <- [
          bow: [:arrow],
          musical: [:arrow],
          whip: [:arrow],
          revolver: [:bullet, :shell],
          rifle: [:bullet, :shell],
          gatling: [:bullet, :shell],
          shotgun: [:bullet, :shell],
          grenade: launcher_ammo,
          dagger: [],
          fist: []
        ] do
      stub_definitions(weapon)

      for {id, subtype} <- [
            {90_002, :arrow},
            {90_003, :bullet},
            {90_004, :kunai},
            {90_005, :shell},
            {90_006, :grenade}
          ] do
        inventory = %{
          0 => %InventoryItem{nameid: 90_001, amount: 1, equip: 2, identify: 1},
          1 => %InventoryItem{nameid: id, amount: 10, identify: 1}
        }

        result = Inventory.equip(inventory, 1, 32_768, %{job_id: 0, base_level: 99, sex: "M"})

        if subtype in (accepted ++ unrestricted) do
          assert {:ok, equipped, _change} = result
          assert equipped[1].equip == 32_768
        else
          assert {:error, :wrong_ammo} = result
        end
      end
    end
  end

  defp stub_definitions(weapon) do
    definitions = %{
      90_001 => %ItemDefinition{
        id: 90_001,
        aegis_name: "Weapon",
        name: "Weapon",
        type: :weapon,
        subtype: weapon,
        locations: [:right_hand, :left_hand]
      },
      90_002 => %ItemDefinition{
        id: 90_002,
        aegis_name: "Arrow",
        name: "Arrow",
        type: :ammo,
        subtype: :arrow,
        locations: [:ammo]
      },
      90_003 => %ItemDefinition{
        id: 90_003,
        aegis_name: "Bullet",
        name: "Bullet",
        type: :ammo,
        subtype: :bullet,
        locations: [:ammo]
      },
      90_004 => %ItemDefinition{
        id: 90_004,
        aegis_name: "Kunai",
        name: "Kunai",
        type: :ammo,
        subtype: :kunai,
        locations: [:ammo]
      },
      90_005 => %ItemDefinition{
        id: 90_005,
        aegis_name: "Shell",
        name: "Shell",
        type: :ammo,
        subtype: :shell,
        locations: [:ammo]
      },
      90_006 => %ItemDefinition{
        id: 90_006,
        aegis_name: "Grenade",
        name: "Grenade",
        type: :ammo,
        subtype: :grenade,
        locations: [:ammo]
      }
    }

    stub(ItemManagement, :get_item_by_id, &Map.fetch(definitions, &1))
  end
end
