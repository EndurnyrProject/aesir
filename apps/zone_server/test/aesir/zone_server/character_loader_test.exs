defmodule Aesir.ZoneServer.CharacterLoaderTest do
  use Aesir.DataCase, async: true

  import ExUnit.CaptureLog

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.CharacterLoader

  describe "load_character/2" do
    setup do
      {:ok, account} =
        Account.changeset(%Account{}, %{
          userid: "testuser",
          user_pass: "password123",
          email: "test@example.com"
        })
        |> Repo.insert()

      {:ok, character} =
        Character.changeset(%Character{}, %{
          account_id: account.id,
          char_num: 0,
          name: "TestChar",
          class: 0,
          base_level: 10,
          job_level: 5,
          hp: 100,
          max_hp: 150,
          sp: 50,
          max_sp: 75,
          last_map: "prontera.gat",
          last_x: 100,
          last_y: 200
        })
        |> Repo.insert()

      {:ok, account: account, character: character}
    end

    test "successfully loads character with correct account", %{
      account: account,
      character: character
    } do
      assert {:ok, loaded_character} = CharacterLoader.load_character(character.id, account.id)

      assert loaded_character.id == character.id
      assert loaded_character.account_id == account.id
      assert loaded_character.name == "TestChar"
      assert loaded_character.last_map == "prontera.gat"
      assert loaded_character.last_x == 100
      assert loaded_character.last_y == 200
      assert loaded_character.hp == 100
      assert loaded_character.max_hp == 150
      assert loaded_character.sp == 50
      assert loaded_character.max_sp == 75
      assert loaded_character.base_level == 10
      assert loaded_character.job_level == 5
      assert loaded_character.class == 0
    end

    test "returns error when character not found", %{account: account} do
      non_existent_id = 999_999

      log =
        capture_log(fn ->
          assert {:error, :character_not_found} =
                   CharacterLoader.load_character(non_existent_id, account.id)
        end)

      assert log =~
               "Failed to load character #{non_existent_id} for account #{account.id}: character_not_found"
    end

    test "returns error when character belongs to different account", %{character: character} do
      different_account_id = 999_999

      log =
        capture_log(fn ->
          assert {:error, :character_not_owned} =
                   CharacterLoader.load_character(character.id, different_account_id)
        end)

      assert log =~
               "Failed to load character #{character.id} for account #{different_account_id}: character_not_owned"
    end

    test "handles missing position data with defaults", %{account: account} do
      {:ok, character} =
        Character.changeset(%Character{}, %{
          account_id: account.id,
          char_num: 1,
          name: "NoPosition",
          class: 0,
          last_map: "new_1-1.gat",
          last_x: nil,
          last_y: nil
        })
        |> Repo.insert()

      assert {:ok, loaded_character} = CharacterLoader.load_character(character.id, account.id)

      # Character model would have nil or defaults for positions
      assert loaded_character.last_x == nil
      assert loaded_character.last_y == nil
    end

    test "preserves map name with .gat extension", %{
      account: account,
      character: character
    } do
      assert {:ok, loaded_character} = CharacterLoader.load_character(character.id, account.id)

      # Character model keeps the .gat extension
      assert loaded_character.last_map == "prontera.gat"
    end
  end
end
