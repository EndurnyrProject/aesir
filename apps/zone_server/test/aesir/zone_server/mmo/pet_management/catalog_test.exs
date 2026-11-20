defmodule Aesir.ZoneServer.Mmo.PetManagement.CatalogTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.ItemManagement.Items
  alias Aesir.ZoneServer.Mmo.MobManagement.Mobs
  alias Aesir.ZoneServer.Mmo.PetManagement.Catalog

  test "indexes the active pets and resolves their mob, item and evolution references" do
    assert [_ | _] = pets = Catalog.all()
    mob_ids = Enum.map(pets, & &1.mob_id)
    assert mob_ids == Enum.sort(Enum.uniq(mob_ids))
    pet_mobs = MapSet.new(mob_ids)

    refute Catalog.tame_item?(0)

    for pet <- pets do
      assert {:ok, _} = Mobs.by_id(pet.mob_id)
      assert {:ok, ^pet} = Catalog.by_mob(pet.mob_id)

      if pet.tame_item_id != 0 do
        assert Catalog.tame_item?(pet.tame_item_id)
      end

      assert {:ok, _} = Items.by_id(pet.egg_item_id)

      for id <- [pet.tame_item_id, pet.equip_item_id, pet.food_item_id], id != 0 do
        assert {:ok, _} = Items.by_id(id), "pet #{pet.mob_id} item #{id} missing"
      end

      for %{target_mob_id: target, requirements: requirements} <- pet.evolution do
        assert MapSet.member?(pet_mobs, target), "evolution target #{target} is not a pet"
        for %{item_id: id} <- requirements, do: assert({:ok, _} = Items.by_id(id))
      end
    end

    for {egg_id, species} <- Enum.group_by(pets, & &1.egg_item_id) do
      expected = Enum.min_by(species, & &1.mob_id)
      assert {:ok, ^expected} = Catalog.by_egg(egg_id)
    end
  end
end
