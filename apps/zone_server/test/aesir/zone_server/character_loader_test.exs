defmodule Aesir.ZoneServer.CharacterLoaderTest do
  use Aesir.DataCase, async: true

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
      assert {:ok, player_data} = CharacterLoader.load_character(character.id, account.id)

      assert player_data.char_id == character.id
      assert player_data.account_id == account.id
      assert player_data.name == "TestChar"
      assert player_data.map_name == "prontera"
      assert player_data.x == 100
      assert player_data.y == 200
      assert player_data.hp == 100
      assert player_data.max_hp == 150
      assert player_data.sp == 50
      assert player_data.max_sp == 75
      assert player_data.base_level == 10
      assert player_data.job_level == 5
      assert player_data.job_id == 0
      assert player_data.walk_speed == 150
      assert player_data.is_walking == false
      assert player_data.walk_path == []
      assert player_data.subscribed_cells == []
    end

    test "returns error when character not found", %{account: account} do
      non_existent_id = 999_999

      assert {:error, :character_not_found} =
               CharacterLoader.load_character(non_existent_id, account.id)
    end

    test "returns error when character belongs to different account", %{character: character} do
      different_account_id = 999_999

      assert {:error, :character_not_owned} =
               CharacterLoader.load_character(character.id, different_account_id)
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

      assert {:ok, player_data} = CharacterLoader.load_character(character.id, account.id)

      # Should use default positions when nil
      assert player_data.x == 155
      assert player_data.y == 187
    end

    test "normalizes map name by removing .gat extension", %{
      account: account,
      character: character
    } do
      assert {:ok, player_data} = CharacterLoader.load_character(character.id, account.id)

      # Original has "prontera.gat", should be normalized to "prontera"
      assert player_data.map_name == "prontera"
    end
  end
end
