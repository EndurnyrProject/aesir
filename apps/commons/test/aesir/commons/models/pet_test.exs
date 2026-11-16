defmodule Aesir.Commons.Models.PetTest do
  use Aesir.DataCase, async: true

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.Pet

  test "validates pet state bounds" do
    changeset =
      Pet.changeset(%Pet{}, %{intimate: 1001, hungry: -1, name: String.duplicate("a", 25)})

    assert %{intimate: [_], hungry: [_], name: [_]} = errors_on(changeset)
  end

  test "validates both endpoints and flags" do
    attrs = %{
      class: 1002,
      name: "Poring",
      account_id: 1,
      char_id: 1,
      level: 1,
      egg_id: 1,
      intimate: 0,
      hungry: 100,
      rename_flag: 1,
      incubate: 0
    }

    assert Pet.changeset(%Pet{}, attrs).valid?

    changeset =
      Pet.changeset(
        %Pet{},
        Map.merge(attrs, %{intimate: -1, hungry: 101, rename_flag: 2, incubate: -1})
      )

    assert %{intimate: [_], hungry: [_], rename_flag: [_], incubate: [_]} = errors_on(changeset)
  end

  test "retains pets when a character is deleted" do
    suffix = System.unique_integer([:positive])

    account =
      %Account{}
      |> Account.changeset(%{
        userid: "pet#{suffix}",
        user_pass: "secret",
        email: "pet#{suffix}@example.com"
      })
      |> Repo.insert!()

    character =
      %Character{}
      |> Character.changeset(%{
        account_id: account.id,
        char_num: 0,
        name: "Pet#{suffix}",
        class: 0
      })
      |> Repo.insert!()

    pet =
      %Pet{}
      |> Pet.changeset(%{
        class: 1002,
        name: "Poring",
        account_id: account.id,
        char_id: character.id,
        level: 1,
        egg_id: 1,
        intimate: 100,
        hungry: 100
      })
      |> Repo.insert!()

    Repo.delete!(character)
    assert Repo.get!(Pet, pet.id).char_id == character.id
  end
end
