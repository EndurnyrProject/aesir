defmodule Aesir.Commons.Models.CharacterQuestTest do
  use Aesir.DataCase, async: true

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.CharacterQuest

  defp account! do
    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        userid: "questtester",
        user_pass: "secret",
        email: "questtester@example.com"
      })
      |> Repo.insert()

    account
  end

  defp character!(account) do
    {:ok, character} =
      %Character{}
      |> Character.changeset(%{
        account_id: account.id,
        char_num: 0,
        name: "QuestHero",
        class: 0
      })
      |> Repo.insert()

    character
  end

  describe "changeset/2" do
    test "declares char_id and quest_id as required" do
      changeset = CharacterQuest.changeset(%CharacterQuest{}, %{})

      refute changeset.valid?
      assert Enum.sort(changeset.required) == [:char_id, :quest_id]
      assert %{char_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects an invalid state" do
      changeset =
        CharacterQuest.changeset(%CharacterQuest{}, %{char_id: 1, quest_id: 7128, state: "bogus"})

      refute changeset.valid?
      assert %{state: ["is invalid"]} = errors_on(changeset)
    end

    test "accepts a valid quest row" do
      changeset =
        CharacterQuest.changeset(%CharacterQuest{}, %{
          char_id: 1,
          quest_id: 7128,
          state: "active",
          count1: 2
        })

      assert changeset.valid?
    end
  end

  describe "persistence" do
    test "enforces the (char_id, quest_id) unique constraint" do
      account = account!()
      character = character!(account)

      {:ok, _quest} =
        %CharacterQuest{}
        |> CharacterQuest.changeset(%{char_id: character.id, quest_id: 7128})
        |> Repo.insert()

      {:error, changeset} =
        %CharacterQuest{}
        |> CharacterQuest.changeset(%{char_id: character.id, quest_id: 7128})
        |> Repo.insert()

      assert %{char_id: ["has already been taken"]} = errors_on(changeset)
    end

    test "round-trips a quest row" do
      account = account!()
      character = character!(account)

      {:ok, quest} =
        %CharacterQuest{}
        |> CharacterQuest.changeset(%{
          char_id: character.id,
          quest_id: 7128,
          state: "active",
          count1: 3
        })
        |> Repo.insert()

      assert %CharacterQuest{quest_id: 7128, state: "active", count1: 3} =
               Repo.get!(CharacterQuest, quest.id)
    end
  end
end
