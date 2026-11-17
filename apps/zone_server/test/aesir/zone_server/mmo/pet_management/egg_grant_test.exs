defmodule Aesir.ZoneServer.Mmo.PetManagement.EggGrantTest do
  use Aesir.DataCase, async: true

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.Pet
  alias Aesir.ZoneServer.Mmo.PetManagement.Catalog
  alias Aesir.ZoneServer.Mmo.PetManagement.Egg
  alias Aesir.ZoneServer.Mmo.PetManagement.EggGrant

  test "rejects non-eggs and full inventories before creating a pet" do
    assert {:error, :not_egg} = EggGrant.grant(501, 1, 1, %{}, :infinity)
    {:ok, definition} = Catalog.by_mob(1002)
    full = Map.new(0..99, &{&1, %{}})
    assert {:error, :no_slot} = EggGrant.grant(definition.egg_item_id, 1, 1, full, :infinity)
  end

  test "each fresh egg has a distinct persisted pet" do
    suffix = System.unique_integer([:positive])
    username = "egg#{suffix}"

    account =
      Repo.insert!(
        Account.changeset(%Account{}, %{
          username: username,
          userid: username,
          user_pass: "password",
          email: "#{username}@example.com"
        })
      )

    character =
      Repo.insert!(
        Character.changeset(%Character{}, %{
          account_id: account.id,
          char_num: 0,
          name: "Egg#{suffix}",
          class: 1,
          base_level: 1,
          str: 1,
          agi: 1,
          vit: 1,
          int: 1,
          dex: 1,
          luk: 1
        })
      )

    {:ok, definition} = Catalog.by_mob(1002)

    inventory =
      Enum.reduce(1..3, %{}, fn _, inventory ->
        assert {:ok, next} =
                 EggGrant.grant(
                   definition.egg_item_id,
                   account.id,
                   character.id,
                   inventory,
                   :infinity
                 )

        next
      end)

    ids = inventory |> Map.values() |> Enum.map(&Egg.pet_id/1)
    assert length(Enum.uniq(ids)) == 3
    assert Enum.all?(ids, &Repo.get(Pet, &1))
  end
end
