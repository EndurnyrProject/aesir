defmodule Aesir.ZoneServer.Mmo.ItemManagement.CreatorNamesTest do
  use Aesir.DataCase, async: false
  use Mimic

  alias Aesir.Commons.InterServer.Schemas.OnlineUser
  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.SessionManager
  alias Aesir.ZoneServer.Mmo.ItemManagement.CreatorNames

  setup :verify_on_exit!

  setup do
    Mimic.set_mimic_private()
    Mimic.copy(SessionManager)

    suffix = System.unique_integer([:positive])

    account =
      %Account{}
      |> Account.changeset(%{
        userid: "creator#{suffix}",
        user_pass: "password",
        email: "creator#{suffix}@aesir.test"
      })
      |> Repo.insert!()

    character =
      %Character{}
      |> Character.changeset(%{
        account_id: account.id,
        char_num: 0,
        name: "Creator#{suffix}",
        class: 0
      })
      |> Repo.insert!()

    %{account: account, character: character}
  end

  test "resolves an online character by name", %{account: account, character: character} do
    account_id = account.id
    character_id = character.id

    stub(SessionManager, :get_online_user, fn ^account_id ->
      {:ok, OnlineUser.new(account_id, account.userid, :zone_server, character_id, "prontera")}
    end)

    assert {:ok, ^character_id} = CreatorNames.resolve_online_target(character.name)
  end

  test "resolves an online character by character id", %{account: account, character: character} do
    account_id = account.id
    character_id = character.id

    stub(SessionManager, :get_online_user, fn ^account_id ->
      {:ok, OnlineUser.new(account_id, account.userid, :zone_server, character_id, "prontera")}
    end)

    assert {:ok, ^character_id} = CreatorNames.resolve_online_target(character_id)
  end

  test "rejects an offline character", %{account: account, character: character} do
    account_id = account.id
    character_id = character.id
    stub(SessionManager, :get_online_user, fn ^account_id -> {:error, :not_found} end)

    assert {:error, :not_online} = CreatorNames.resolve_online_target(character_id)
  end

  test "rejects an unknown character name" do
    assert {:error, :not_online} = CreatorNames.resolve_online_target("UnknownCreator")
  end
end
