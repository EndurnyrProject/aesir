defmodule Aesir.ZoneServer.Mmo.ItemManagement.CreatorNamesTest do
  use Aesir.DataCase, async: true
  use Mimic

  import Aesir.Factory

  alias Aesir.Commons.InterServer.Schemas.OnlineUser
  alias Aesir.Commons.SessionManager
  alias Aesir.ZoneServer.Mmo.ItemManagement.CreatorNames

  setup :set_mimic_from_context
  setup :verify_on_exit!

  setup do
    character = insert(:character)
    %{account: character.account, character: character}
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
