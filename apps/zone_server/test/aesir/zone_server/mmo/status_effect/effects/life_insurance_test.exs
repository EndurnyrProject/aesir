defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.LifeInsuranceTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Efst
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.LifeInsurance
  alias Aesir.ZoneServer.Mmo.StatusEntry

  defp entry(val1), do: %StatusEntry{type: :sc_lifeinsurance, state: %{}, val1: val1}

  describe "modifiers/2" do
    test "emits the fixed no_death_penalty flag regardless of val1" do
      assert %{no_death_penalty: 1} == LifeInsurance.modifiers(entry(0), %{})
      assert %{no_death_penalty: 1} == LifeInsurance.modifiers(entry(99), %{})
    end
  end

  describe "metadata" do
    test "id/properties/calc_flags" do
      meta = LifeInsurance.metadata()
      assert meta.id == :sc_lifeinsurance
      assert :buff in meta.properties
      assert :no_death_penalty in meta.calc_flags
    end

    test "icon cash_deathpenalty resolves via Mmo.Efst" do
      assert LifeInsurance.metadata().icon == :cash_deathpenalty
      assert is_integer(Efst.id(:cash_deathpenalty))
    end
  end

  test "is registered in Effects.all/0" do
    assert LifeInsurance in Effects.all()
  end
end
