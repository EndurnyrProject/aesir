defmodule Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.BonusKeysTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.BonusKeys

  @documented_destinations [
    :str,
    :agi,
    :vit,
    :int,
    :dex,
    :luk,
    :pow,
    :sta,
    :wis,
    :spl,
    :con,
    :crt,
    :atk,
    :matk,
    :def,
    :mdef,
    :hit,
    :flee,
    :critical,
    :patk,
    :smatk,
    :res,
    :mres
  ]

  describe "destination/1" do
    test "resolves the classic stat keys" do
      assert BonusKeys.destination("bStr") == {:ok, :str}
      assert BonusKeys.destination("bLuk") == {:ok, :luk}
    end

    test "resolves the base trait keys" do
      assert BonusKeys.destination("bPow") == {:ok, :pow}
      assert BonusKeys.destination("bCrt") == {:ok, :crt}
    end

    test "resolves the combat trait keys case-insensitively" do
      assert BonusKeys.destination("bPAtk") == {:ok, :patk}
      assert BonusKeys.destination("bPatk") == {:ok, :patk}
      assert BonusKeys.destination("BPATK") == {:ok, :patk}
    end

    test "bBaseAtk and bAtk both map to :atk" do
      assert BonusKeys.destination("bBaseAtk") == {:ok, :atk}
      assert BonusKeys.destination("bAtk") == {:ok, :atk}
    end

    test "resolves the classic combat keys" do
      assert BonusKeys.destination("bMatk") == {:ok, :matk}
      assert BonusKeys.destination("bDef") == {:ok, :def}
      assert BonusKeys.destination("bMdef") == {:ok, :mdef}
      assert BonusKeys.destination("bHit") == {:ok, :hit}
      assert BonusKeys.destination("bFlee") == {:ok, :flee}
      assert BonusKeys.destination("bCritical") == {:ok, :critical}
    end

    test "returns :error for an out-of-vocabulary key" do
      assert BonusKeys.destination("bMaxHP") == :error
    end
  end

  describe "destinations/0" do
    test "returns exactly the documented section-3 destination set" do
      assert Enum.sort(Enum.uniq(BonusKeys.destinations())) ==
               Enum.sort(Enum.uniq(@documented_destinations))
    end
  end
end
