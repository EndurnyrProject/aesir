defmodule Aesir.ZoneServer.Mmo.Fame.StoreErrorsTest do
  # Sync: renaming the characters table or the fame-order sequence takes an exclusive
  # lock that stalls every concurrent sandbox touching it.
  use Aesir.DataCase, async: false

  import Aesir.Factory

  alias Aesir.ZoneServer.Mmo.Fame.Store

  test "database query errors are not successful empty rankings" do
    SQL.query!(Repo, "ALTER TABLE characters RENAME TO fame_test_characters")
    assert {:error, %Postgrex.Error{}} = Store.ranking(:blacksmith)
  end

  test "database write errors remain explicit" do
    character = insert(:character, fame: 12)
    SQL.query!(Repo, "ALTER SEQUENCE character_fame_order_seq RENAME TO fame_test_order_seq")
    assert {:error, %Postgrex.Error{}} = Store.persist(character.id, 13)
  end
end
