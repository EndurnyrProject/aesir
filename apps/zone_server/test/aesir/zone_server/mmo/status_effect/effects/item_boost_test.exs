defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.ItemBoostTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Efst
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.ItemBoost
  alias Aesir.ZoneServer.Mmo.StatusEntry

  defp entry(val1), do: %StatusEntry{type: :sc_itemboost, state: %{}, val1: val1}

  describe "modifiers/2" do
    test "emits +val1 as drop_rate" do
      assert %{drop_rate: 100} == ItemBoost.modifiers(entry(100), %{})
      assert %{drop_rate: 25} == ItemBoost.modifiers(entry(25), %{})
    end
  end

  describe "metadata" do
    test "id/properties/calc_flags" do
      meta = ItemBoost.metadata()
      assert meta.id == :sc_itemboost
      assert :buff in meta.properties
      assert :drop_rate in meta.calc_flags
    end

    test "icon cash_receiveitem resolves via Mmo.Efst" do
      assert ItemBoost.metadata().icon == :cash_receiveitem
      assert is_integer(Efst.id(:cash_receiveitem))
    end
  end

  test "is registered in Effects.all/0" do
    assert ItemBoost in Effects.all()
  end
end
