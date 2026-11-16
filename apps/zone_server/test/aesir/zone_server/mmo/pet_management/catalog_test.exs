defmodule Aesir.ZoneServer.Mmo.PetManagement.CatalogTest do
  use ExUnit.Case, async: false

  alias Aesir.ZoneServer.Mmo.ItemManagement.Items
  alias Aesir.ZoneServer.Mmo.MobManagement.Mobs
  alias Aesir.ZoneServer.Mmo.PetManagement.Catalog

  setup do
    :ok = Catalog.reload()
  end

  @tag game_mode: :renewal
  test "renewal catalog references its mode's items and mobs and shares two eggs" do
    assert length(Catalog.all()) == 107
    assert_references_resolve()
    assert shared_eggs() == MapSet.new(~w(Chung_E_Egg Mystic_Leaf_Cat_Ball))

    {:ok, egg} = Items.by_aegis("Chung_E_Egg")
    assert {:ok, %{mob_id: 1519}} = Catalog.by_egg(egg.id)
  end

  @tag game_mode: :pre_renewal
  test "pre-renewal catalog references its mode's items and mobs and shares no egg" do
    assert length(Catalog.all()) == 57
    assert_references_resolve()
    assert shared_eggs() == MapSet.new()
  end

  defp assert_references_resolve do
    pets = Catalog.all()
    pet_mobs = MapSet.new(pets, & &1.mob_id)

    for pet <- pets do
      assert {:ok, _} = Mobs.by_id(pet.mob_id)
      assert {:ok, ^pet} = Catalog.by_mob(pet.mob_id)
      assert Catalog.tame_item?(pet.tame_item_id) == (pet.tame_item_id != 0)

      for id <- [pet.tame_item_id, pet.egg_item_id, pet.equip_item_id, pet.food_item_id],
          id != 0 do
        assert {:ok, _} = Items.by_id(id), "pet #{pet.mob_id} item #{id} missing"
      end

      for %{target_mob_id: target, requirements: requirements} <- pet.evolution do
        assert MapSet.member?(pet_mobs, target), "evolution target #{target} is not a pet"
        for %{item_id: id} <- requirements, do: assert({:ok, _} = Items.by_id(id))
      end
    end
  end

  defp shared_eggs do
    for {egg_id, [_, _ | _]} <- Enum.group_by(Catalog.all(), & &1.egg_item_id),
        into: MapSet.new() do
      {:ok, item} = Items.by_id(egg_id)
      item.aegis_name
    end
  end
end
