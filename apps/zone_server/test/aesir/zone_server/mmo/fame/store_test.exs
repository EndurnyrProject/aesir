defmodule Aesir.ZoneServer.Mmo.Fame.StoreTest do
  use Aesir.DataCase, async: false

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.Fame.Store
  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs

  setup do
    account =
      Repo.insert!(%Account{
        userid: "fame-store",
        user_pass: "unused",
        sex: "M",
        email: "fame@test.local"
      })

    %{account: account}
  end

  test "persist stores an absolute total and advances tie order atomically", %{account: account} do
    character = character(account, :blacksmith, 12)
    assert character.fame_order == 0
    assert :ok = Store.persist(character.id, 50)
    first = Repo.get!(Character, character.id)
    assert first.fame == 50
    assert first.fame_order > 0
    assert :ok = Store.persist(character.id, 50)
    second = Repo.get!(Character, character.id)
    assert second.fame == 50
    assert second.fame_order > first.fame_order

    assert Map.drop(Map.from_struct(second), [:fame, :fame_order]) ==
             Map.drop(Map.from_struct(character), [:fame, :fame_order])

    assert {:error, :character_not_found} = Store.persist(2_000_000_000, 1)
  end

  test "rankings contain only the ten positive scores of the exact profession set", %{
    account: account
  } do
    boards = [
      blacksmith: [
        :blacksmith,
        :whitesmith,
        :baby_blacksmith,
        :mechanic,
        :mechanic_t,
        :baby_mechanic,
        :meister
      ],
      alchemist: [
        :alchemist,
        :creator,
        :baby_alchemist,
        :genetic,
        :genetic_t,
        :baby_genetic,
        :biolo
      ]
    ]

    for {category, jobs} <- boards do
      characters = Enum.map(jobs, &character(account, &1, 100))
      character(account, hd(jobs), 0)
      character(account, :novice, 999)
      assert {:ok, entries} = Store.ranking(category)
      assert Enum.map(entries, & &1.character_id) == Enum.map(characters, & &1.id)
      assert Enum.all?(entries, &(&1.fame == 100))
    end
  end

  test "a new equal-score award enters at the tenth-place cutoff", %{account: account} do
    characters = Enum.map(1..12, fn _ -> character(account, :alchemist, 50) end)
    assert {:ok, initial} = Store.ranking(:alchemist)
    assert Enum.map(initial, & &1.character_id) == Enum.map(Enum.take(characters, 10), & &1.id)
    outsider = List.last(characters)
    assert :ok = Store.persist(outsider.id, 50)
    assert {:ok, updated} = Store.ranking(:alchemist)

    assert Enum.map(updated, & &1.character_id) == [
             outsider.id | Enum.map(Enum.take(characters, 9), & &1.id)
           ]
  end

  test "legacy equal scores use character ID until an award establishes order", %{
    account: account
  } do
    first = character(account, :blacksmith, 1_000_000_000)
    second = character(account, :blacksmith, 1_000_000_000)

    assert {:ok, [%{character_id: first_id}, %{character_id: second_id}]} =
             Store.ranking(:blacksmith)

    assert {first_id, second_id} == {first.id, second.id}
    assert :ok = Store.persist(second.id, 1_000_000_000)
    assert {:ok, ranking} = Store.ranking(:blacksmith)
    assert Enum.map(ranking, & &1.character_id) == [second.id, first.id]
    assert {:ok, ^ranking} = Store.ranking(:blacksmith)
    assert :ok = Store.persist(first.id, 1_000_000_000)
    assert {:ok, [%{character_id: ^first_id} | _]} = Store.ranking(:blacksmith)
  end

  test "ranking membership and names follow current character rows", %{account: account} do
    character = character(account, :blacksmith, 12)
    {:ok, alchemist} = AvailableJobs.job_name_to_id(:alchemist)

    character =
      Repo.update!(
        Ecto.Changeset.change(character,
          name: "Renamed",
          class: alchemist,
          delete_date: ~N[2026-11-30 00:00:00]
        )
      )

    assert {:ok, []} = Store.ranking(:blacksmith)
    assert {:ok, [%{name: "Renamed", fame: 12}]} = Store.ranking(:alchemist)
    Repo.delete!(character)
    assert {:ok, []} = Store.ranking(:alchemist)
  end

  test "database query errors are not successful empty rankings" do
    SQL.query!(Repo, "ALTER TABLE characters RENAME TO fame_test_characters")
    assert {:error, %Postgrex.Error{}} = Store.ranking(:blacksmith)
  end

  test "database write errors remain explicit", %{account: account} do
    character = character(account, :blacksmith, 12)
    SQL.query!(Repo, "ALTER SEQUENCE character_fame_order_seq RENAME TO fame_test_order_seq")
    assert {:error, %Postgrex.Error{}} = Store.persist(character.id, 13)
  end

  defp character(account, job, fame) do
    {:ok, class} = AvailableJobs.job_name_to_id(job)
    n = System.unique_integer([:positive])

    Repo.insert!(%Character{
      account_id: account.id,
      char_num: rem(n, 250),
      name: "Maker#{n}",
      class: class,
      fame: fame
    })
  end
end
