defmodule Aesir.ZoneServer.Unit.Player.QuestPersistenceTest do
  use Aesir.DataCase, async: false

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.CharacterQuest
  alias Aesir.ZoneServer.Unit.Player.QuestLog.Entry
  alias Aesir.ZoneServer.Unit.Player.QuestPersistence

  setup do
    prev_inline = Application.get_env(:zone_server, :inline_persistence)
    Application.put_env(:zone_server, :inline_persistence, true)

    on_exit(fn ->
      case prev_inline do
        nil -> Application.delete_env(:zone_server, :inline_persistence)
        value -> Application.put_env(:zone_server, :inline_persistence, value)
      end
    end)

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        userid: "questuser",
        user_pass: "password",
        sex: "M",
        email: "quest@example.com"
      })
      |> Repo.insert()

    {:ok, character} =
      Character.new(%{
        account_id: account.id,
        char_num: 0,
        name: "QuestChar",
        class: 0,
        last_map: "prontera.gat",
        last_x: 100,
        last_y: 200
      })
      |> Repo.insert()

    %{character: character}
  end

  describe "load_on_spawn/1" do
    test "returns an empty quest_log for a character with no rows", %{character: character} do
      state = %{game_state: %{character_id: character.id, quest_log: %{}}}

      assert QuestPersistence.load_on_spawn(state).game_state.quest_log == %{}
    end

    test "populates quest_log from persisted rows", %{character: character} do
      %CharacterQuest{}
      |> CharacterQuest.changeset(%{
        char_id: character.id,
        quest_id: 1100,
        state: "active",
        count1: 3,
        count2: 0,
        count3: 0
      })
      |> Repo.insert!()

      state = %{game_state: %{character_id: character.id, quest_log: %{}}}

      assert QuestPersistence.load_on_spawn(state).game_state.quest_log == %{
               1100 => %Entry{state: :active, counts: [3, 0, 0], deadline: nil}
             }
    end
  end

  describe "upsert/2" do
    test "round-trips state and counts through load_on_spawn/1", %{character: character} do
      entry = %Entry{state: :active, counts: [5, 1, 0], deadline: nil}

      :ok = QuestPersistence.upsert(character.id, {1100, entry})

      state = %{game_state: %{character_id: character.id, quest_log: %{}}}
      assert QuestPersistence.load_on_spawn(state).game_state.quest_log == %{1100 => entry}
    end

    test "a second upsert updates the row in place instead of duplicating it", %{
      character: character
    } do
      :ok = QuestPersistence.upsert(character.id, {1100, %Entry{state: :active, counts: [1]}})
      :ok = QuestPersistence.upsert(character.id, {1100, %Entry{state: :complete, counts: [20]}})

      rows = Repo.all(CharacterQuest)
      assert [%CharacterQuest{quest_id: 1100, state: "complete", count1: 20}] = rows
    end
  end

  describe "delete/2" do
    test "removes the row for the given quest", %{character: character} do
      :ok = QuestPersistence.upsert(character.id, {1100, %Entry{state: :active, counts: [1]}})
      :ok = QuestPersistence.upsert(character.id, {1101, %Entry{state: :active, counts: [2]}})

      :ok = QuestPersistence.delete(character.id, 1100)

      assert [%CharacterQuest{quest_id: 1101}] = Repo.all(CharacterQuest)
    end
  end
end
