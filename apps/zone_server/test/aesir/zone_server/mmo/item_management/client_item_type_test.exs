defmodule Aesir.ZoneServer.Mmo.ItemManagement.ClientItemTypeTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.ItemManagement.ClientItemType

  describe "to_client_type/1" do
    test "maps the documented item-type atoms to their IT_ enum value" do
      assert ClientItemType.to_client_type(:healing) == 0
      assert ClientItemType.to_client_type(:usable) == 2
      assert ClientItemType.to_client_type(:etc) == 3
      assert ClientItemType.to_client_type(:armor) == 4
      assert ClientItemType.to_client_type(:weapon) == 5
      assert ClientItemType.to_client_type(:card) == 6
      assert ClientItemType.to_client_type(:pet_egg) == 7
      assert ClientItemType.to_client_type(:pet_armor) == 8
      assert ClientItemType.to_client_type(:ammo) == 10
      assert ClientItemType.to_client_type(:delay_consume) == 11
      assert ClientItemType.to_client_type(:shadow_gear) == 12
      assert ClientItemType.to_client_type(:cash) == 18
    end
  end
end
