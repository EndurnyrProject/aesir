defmodule Aesir.ZoneServer.CharacterPersistenceTest do
  use Aesir.DataCase, async: false

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Repo
  alias Aesir.ZoneServer.CharacterPersistence

  describe "update_character/3" do
    setup do
      {:ok, account} =
        %Account{}
        |> Account.changeset(%{
          userid: "testuser",
          user_pass: "password",
          sex: "M",
          email: "test@example.com"
        })
        |> Repo.insert()

      {:ok, character} =
        Character.new(%{
          account_id: account.id,
          char_num: 0,
          name: "TestChar",
          class: 0,
          str: 5,
          agi: 5,
          vit: 5,
          int: 5,
          dex: 5,
          luk: 5,
          hp: 100,
          max_hp: 150,
          sp: 50,
          max_sp: 75,
          last_map: "prontera.gat",
          last_x: 100,
          last_y: 200,
          base_exp: 0,
          job_exp: 0
        })
        |> Repo.insert()

      %{account: account, character: character}
    end

    test "updates single field successfully", %{character: character} do
      assert {:ok, updated} = CharacterPersistence.update_character(character.id, %{hp: 75})

      assert updated.hp == 75
      assert updated.max_hp == 150
      assert updated.sp == 50
    end

    test "updates multiple fields successfully", %{character: character} do
      assert {:ok, updated} =
               CharacterPersistence.update_character(character.id, %{hp: 75, sp: 25, max_hp: 200})

      assert updated.hp == 75
      assert updated.sp == 25
      assert updated.max_hp == 200
      assert updated.max_sp == 75
    end

    test "returns error when character not found" do
      assert {:error, :character_not_found} =
               CharacterPersistence.update_character(999_999, %{hp: 100})
    end

    test "returns error when no fields provided" do
      assert {:error, :no_fields_to_update} =
               CharacterPersistence.update_character(1, %{})
    end

    test "async mode returns :ok immediately", %{character: character} do
      assert :ok = CharacterPersistence.update_character(character.id, %{hp: 50}, async: true)

      Process.sleep(100)

      updated = Repo.get(Character, character.id)
      assert updated.hp == 50
    end

    test "validates field values through changeset", %{character: character} do
      assert {:error, changeset} =
               CharacterPersistence.update_character(character.id, %{base_level: 1000})

      assert changeset.errors[:base_level] != nil
    end

    test "does not update fields not in the map", %{character: character} do
      original_sp = character.sp

      assert {:ok, updated} = CharacterPersistence.update_character(character.id, %{hp: 50})

      assert updated.hp == 50
      assert updated.sp == original_sp
    end
  end

  describe "update_position/5" do
    setup do
      {:ok, account} =
        %Account{}
        |> Account.changeset(%{
          userid: "testuser2",
          user_pass: "password",
          sex: "F",
          email: "test2@example.com"
        })
        |> Repo.insert()

      {:ok, character} =
        Character.new(%{
          account_id: account.id,
          char_num: 0,
          name: "TestChar2",
          class: 0,
          last_map: "prontera.gat",
          last_x: 100,
          last_y: 200
        })
        |> Repo.insert()

      %{account: account, character: character}
    end

    test "updates position fields successfully", %{character: character} do
      assert {:ok, updated} =
               CharacterPersistence.update_position(character.id, 150, 250, "geffen.gat")

      assert updated.last_x == 150
      assert updated.last_y == 250
      assert updated.last_map == "geffen.gat"
    end

    test "only updates position fields", %{character: character} do
      original_hp = character.hp

      assert {:ok, updated} =
               CharacterPersistence.update_position(character.id, 150, 250, "geffen.gat")

      assert updated.hp == original_hp
    end

    test "async mode works correctly", %{character: character} do
      assert :ok =
               CharacterPersistence.update_position(character.id, 150, 250, "geffen.gat",
                 async: true
               )

      Process.sleep(100)

      updated = Repo.get(Character, character.id)
      assert updated.last_x == 150
      assert updated.last_y == 250
      assert updated.last_map == "geffen.gat"
    end

    test "returns error when character not found" do
      assert {:error, :character_not_found} =
               CharacterPersistence.update_position(999_999, 100, 200, "prontera.gat")
    end
  end

  describe "update_stats/3" do
    setup do
      {:ok, account} =
        %Account{}
        |> Account.changeset(%{
          userid: "testuser3",
          user_pass: "password",
          sex: "M",
          email: "test3@example.com"
        })
        |> Repo.insert()

      {:ok, character} =
        Character.new(%{
          account_id: account.id,
          char_num: 0,
          name: "TestChar3",
          class: 0,
          hp: 100,
          max_hp: 150,
          sp: 50,
          max_sp: 75
        })
        |> Repo.insert()

      %{account: account, character: character}
    end

    test "updates stat fields successfully", %{character: character} do
      assert {:ok, updated} =
               CharacterPersistence.update_stats(character.id, %{hp: 125, sp: 60})

      assert updated.hp == 125
      assert updated.sp == 60
    end

    test "can update max stats", %{character: character} do
      assert {:ok, updated} =
               CharacterPersistence.update_stats(character.id, %{max_hp: 200, max_sp: 100})

      assert updated.max_hp == 200
      assert updated.max_sp == 100
    end

    test "async mode works", %{character: character} do
      assert :ok =
               CharacterPersistence.update_stats(character.id, %{hp: 75, sp: 25}, async: true)

      Process.sleep(100)

      updated = Repo.get(Character, character.id)
      assert updated.hp == 75
      assert updated.sp == 25
    end
  end

  describe "update_exp/4" do
    setup do
      {:ok, account} =
        %Account{}
        |> Account.changeset(%{
          userid: "testuser4",
          user_pass: "password",
          sex: "F",
          email: "test4@example.com"
        })
        |> Repo.insert()

      {:ok, character} =
        Character.new(%{
          account_id: account.id,
          char_num: 0,
          name: "TestChar4",
          class: 0,
          base_exp: 0,
          job_exp: 0
        })
        |> Repo.insert()

      %{account: account, character: character}
    end

    test "updates both exp types", %{character: character} do
      assert {:ok, updated} = CharacterPersistence.update_exp(character.id, 1000, 500)

      assert updated.base_exp == 1000
      assert updated.job_exp == 500
    end

    test "updates only base exp when job exp is nil", %{character: character} do
      assert {:ok, updated} = CharacterPersistence.update_exp(character.id, 1000, nil)

      assert updated.base_exp == 1000
      assert updated.job_exp == 0
    end

    test "updates only job exp when base exp is nil", %{character: character} do
      assert {:ok, updated} = CharacterPersistence.update_exp(character.id, nil, 500)

      assert updated.base_exp == 0
      assert updated.job_exp == 500
    end

    test "returns error when both exp values are nil", %{character: character} do
      assert {:error, :no_fields_to_update} =
               CharacterPersistence.update_exp(character.id, nil, nil)
    end

    test "async mode works", %{character: character} do
      assert :ok = CharacterPersistence.update_exp(character.id, 1000, 500, async: true)

      Process.sleep(100)

      updated = Repo.get(Character, character.id)
      assert updated.base_exp == 1000
      assert updated.job_exp == 500
    end
  end
end
