defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.RateBuffsTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Efst
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects
  alias Aesir.ZoneServer.Mmo.StatusEntry

  defp entry(type, val1), do: %StatusEntry{type: type, state: %{}, val1: val1}

  describe "SkfCast (val1-driven varcast_rate)" do
    test "passes val1 straight through as varcast_rate (negative = faster)" do
      assert %{varcast_rate: -5} == Effects.SkfCast.modifiers(entry(:sc_skf_cast, -5), %{})
    end
  end

  describe "SpcostRate (val1-driven, negated)" do
    test "negates a positive val1 into a cheaper sp_cost_rate" do
      assert %{sp_cost_rate: -10} == Effects.SpcostRate.modifiers(entry(:sc_spcost_rate, 10), %{})
      assert %{sp_cost_rate: -15} == Effects.SpcostRate.modifiers(entry(:sc_spcost_rate, 15), %{})
    end
  end

  describe "MentalPotion (val1-driven, two keys)" do
    test "emits +max_sp_rate and negated sp_cost_rate from the same val1" do
      assert %{max_sp_rate: 20, sp_cost_rate: -20} ==
               Effects.MentalPotion.modifiers(entry(:sc_mental_potion, 20), %{})
    end
  end

  describe "BeefRibStew (fixed magnitude)" do
    test "emits its literal map regardless of val1" do
      expected = %{varcast_rate: -5, sp_cost_rate: -3}
      assert expected == Effects.BeefRibStew.modifiers(entry(:sc_beef_rib_stew, 0), %{})
      assert expected == Effects.BeefRibStew.modifiers(entry(:sc_beef_rib_stew, 99), %{})
    end
  end

  describe "metadata, icons and registration" do
    @modules [
      {Effects.SkfCast, :sc_skf_cast, :skf_cast},
      {Effects.SpcostRate, :sc_spcost_rate, :atker_blood},
      {Effects.MentalPotion, :sc_mental_potion, :target_aspd},
      {Effects.BeefRibStew, :sc_beef_rib_stew, :beef_rib_stew}
    ]

    for {module, type, icon} <- @modules do
      test "#{inspect(module)} is a registered buff with a resolvable icon" do
        meta = unquote(module).metadata()
        assert meta.id == unquote(type)
        assert :buff in meta.properties
        assert is_integer(Efst.id(unquote(icon)))
        assert unquote(module) in Effects.all()
      end
    end
  end
end
