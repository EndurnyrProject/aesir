defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.IncHealRateTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Efst
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.IncHealRate
  alias Aesir.ZoneServer.Mmo.StatusEntry

  defp entry(val1), do: %StatusEntry{type: :sc_inchealrate, state: %{}, val1: val1}

  describe "modifiers/2" do
    test "emits +val1 as received_heal_rate" do
      assert %{received_heal_rate: 50} == IncHealRate.modifiers(entry(50), %{})
      assert %{received_heal_rate: 12} == IncHealRate.modifiers(entry(12), %{})
    end
  end

  describe "metadata" do
    test "id/properties/calc_flags" do
      meta = IncHealRate.metadata()
      assert meta.id == :sc_inchealrate
      assert :buff in meta.properties
      assert :received_heal_rate in meta.calc_flags
    end

    test "icon healplus resolves via Mmo.Efst" do
      assert IncHealRate.metadata().icon == :healplus
      assert is_integer(Efst.id(:healplus))
    end
  end

  test "is registered in Effects.all/0" do
    assert IncHealRate in Effects.all()
  end
end
