defmodule Aesir.ZoneServer.Mmo.ItemManagement.EligibilityTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.Eligibility
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Unit.Inventory

  setup :set_mimic_private
  setup :verify_on_exit!

  setup do
    Mimic.copy(ItemManagement)
    :ok
  end

  test "invalid identity never becomes unrestricted access" do
    item = definition()

    for context <- [
          %{},
          %{job_id: 1, base_level: 0, sex: "M"},
          %{job_id: 99_999, base_level: 1, sex: "M"},
          %{job_id: 1, base_level: 1, sex: "X"}
        ] do
      assert {:error, :invalid_identity} = Eligibility.check(item, context, :renewal)
    end
  end

  test "admits an item when level, gender, family, and class all match" do
    item =
      definition(%{
        jobs: [:swordman],
        classes: [:normal],
        gender: :male,
        equip_level_min: 10,
        equip_level_max: 50
      })

    assert :ok =
             Eligibility.check(
               item,
               %{job_id: job_id(:swordman), base_level: 25, sex: "M"},
               :renewal
             )
  end

  test "reports each restriction independently" do
    swordman = %{job_id: job_id(:swordman), base_level: 25, sex: "M"}

    assert {:error, :level_restricted} =
             Eligibility.check(definition(%{equip_level_min: 30}), swordman, :renewal)

    assert {:error, :level_restricted} =
             Eligibility.check(definition(%{equip_level_max: 20}), swordman, :renewal)

    assert {:error, :gender_restricted} =
             Eligibility.check(definition(%{gender: :female}), swordman, :renewal)

    assert {:error, :job_restricted} =
             Eligibility.check(definition(%{jobs: [:mage]}), swordman, :renewal)

    assert {:error, :class_restricted} =
             Eligibility.check(definition(%{classes: [:upper]}), swordman, :renewal)
  end

  test "checks restrictions in level, gender, family, then class order" do
    item =
      definition(%{
        equip_level_min: 99,
        gender: :female,
        jobs: [:mage],
        classes: [:upper]
      })

    context = %{job_id: job_id(:swordman), base_level: 1, sex: "M"}
    assert {:error, :level_restricted} = Eligibility.check(item, context, :renewal)
  end

  test "explicit empty jobs and classes deny while :all allows every family" do
    context = %{job_id: job_id(:swordman), base_level: 1, sex: "M"}

    assert {:error, :job_restricted} =
             Eligibility.check(definition(%{jobs: []}), context, :renewal)

    assert {:error, :class_restricted} =
             Eligibility.check(definition(%{jobs: :all, classes: []}), context, :renewal)

    assert :ok = Eligibility.check(definition(%{jobs: :all}), context, :renewal)
  end

  describe "ineligible_equipment/3" do
    test "returns sorted indices for permission failures only" do
      definitions = %{
        10 => definition(),
        11 => definition(%{jobs: [:mage]}),
        12 => definition(%{classes: [:upper]}),
        13 => definition(%{gender: :female}),
        14 => definition(%{equip_level_min: 99})
      }

      stub(ItemManagement, :get_item_by_id, fn id -> {:ok, Map.fetch!(definitions, id)} end)

      inventory = %{
        10 => inventory_item(10, 1),
        8 => inventory_item(14, 1),
        6 => inventory_item(13, 1),
        4 => inventory_item(12, 1),
        2 => inventory_item(11, 1),
        0 => inventory_item(11, 0)
      }

      context = %{job_id: job_id(:swordman), base_level: 50, sex: "M"}
      assert {:ok, [2, 4, 6, 8]} = Inventory.ineligible_equipment(inventory, context, :renewal)
    end

    test "validates identity even for an empty inventory" do
      reject(&ItemManagement.get_item_by_id/1)

      assert {:error, :invalid_identity} =
               Inventory.ineligible_equipment(
                 %{},
                 %{job_id: 1, base_level: 1, sex: "X"},
                 :renewal
               )
    end

    test "aborts when equipped item definition is missing" do
      stub(ItemManagement, :get_item_by_id, fn 999 -> {:error, :not_found} end)
      inventory = %{3 => inventory_item(999, 1)}
      context = %{job_id: job_id(:swordman), base_level: 50, sex: "M"}

      assert {:error, {:missing_definition, 999}} =
               Inventory.ineligible_equipment(inventory, context, :renewal)
    end
  end

  defp inventory_item(nameid, equip), do: %InventoryItem{nameid: nameid, amount: 1, equip: equip}

  defp definition(attrs \\ %{}) do
    struct(
      ItemDefinition,
      Map.merge(%{id: 1, aegis_name: "Test", name: "Test"}, attrs)
    )
  end

  defp job_id(name) do
    {:ok, id} = AvailableJobs.job_name_to_id(name)
    id
  end
end
