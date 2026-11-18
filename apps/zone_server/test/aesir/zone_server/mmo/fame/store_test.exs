defmodule Aesir.ZoneServer.Mmo.Fame.StoreTest do
  use Aesir.DataCase, async: true

  import Aesir.Factory

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.Fame.Store
  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs

  test "persist stores an absolute total and advances tie order atomically" do
    character = :blacksmith |> character(12) |> Repo.reload!()
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

  test "rankings contain only the ten positive scores of the exact profession set" do
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
      characters = Enum.map(jobs, &character(&1, 100))
      character(hd(jobs), 0)
      character(:novice, 999)
      assert {:ok, entries} = Store.ranking(category)
      assert Enum.map(entries, & &1.character_id) == Enum.map(characters, & &1.id)
      assert Enum.all?(entries, &(&1.fame == 100))
    end
  end

  test "a new equal-score award enters at the tenth-place cutoff" do
    characters = Enum.map(1..12, fn _ -> character(:alchemist, 50) end)
    assert {:ok, initial} = Store.ranking(:alchemist)
    assert Enum.map(initial, & &1.character_id) == Enum.map(Enum.take(characters, 10), & &1.id)
    outsider = List.last(characters)
    assert :ok = Store.persist(outsider.id, 50)
    assert {:ok, updated} = Store.ranking(:alchemist)

    assert Enum.map(updated, & &1.character_id) == [
             outsider.id | Enum.map(Enum.take(characters, 9), & &1.id)
           ]
  end

  test "legacy equal scores use character ID until an award establishes order" do
    first = character(:blacksmith, 1_000_000_000)
    second = character(:blacksmith, 1_000_000_000)

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

  test "ranking membership and names follow current character rows" do
    character = character(:blacksmith, 12)
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

  defp character(job, fame) do
    {:ok, class} = AvailableJobs.job_name_to_id(job)
    insert(:character, class: class, fame: fame)
  end
end
