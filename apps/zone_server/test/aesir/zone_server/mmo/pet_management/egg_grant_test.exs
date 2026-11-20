defmodule Aesir.ZoneServer.Mmo.PetManagement.EggGrantTest do
  use Aesir.DataCase, async: true

  import Aesir.Factory

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Commons.Models.Pet
  alias Aesir.ZoneServer.Mmo.PetManagement.Catalog
  alias Aesir.ZoneServer.Mmo.PetManagement.Egg
  alias Aesir.ZoneServer.Mmo.PetManagement.EggGrant
  alias Aesir.ZoneServer.Unit.Inventory

  test "rejects non-eggs and full inventories before creating a pet" do
    assert {:error, :not_egg} = EggGrant.grant(501, 1, 1, %{}, :infinity)
    {:ok, definition} = Catalog.by_mob(1002)
    item = build(:inventory_item)
    full = Map.new(0..(Inventory.capacity() - 1), &{&1, item})
    assert {:error, :no_slot} = EggGrant.grant(definition.egg_item_id, 1, 1, full, :infinity)
  end

  test "each fresh egg has a distinct persisted pet" do
    character = insert(:character)

    {:ok, definition} = Catalog.by_mob(1002)

    inventory =
      Enum.reduce(1..3, %{}, fn _, inventory ->
        assert {:ok, next} =
                 EggGrant.grant(
                   definition.egg_item_id,
                   character.account_id,
                   character.id,
                   inventory,
                   :infinity
                 )

        next
      end)

    ids =
      for egg <- Map.values(inventory) do
        assert Repo.get!(InventoryItem, egg.id) == egg
        pet_id = Egg.pet_id(egg)
        assert %Pet{egg_id: egg_id, incubate: 1} = Repo.get!(Pet, pet_id)
        assert egg_id == definition.egg_item_id
        pet_id
      end

    assert length(Enum.uniq(ids)) == 3
  end
end
