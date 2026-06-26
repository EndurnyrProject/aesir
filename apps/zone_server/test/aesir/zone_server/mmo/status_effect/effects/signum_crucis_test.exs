defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.SignumCrucisTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.SignumCrucis

  describe "metadata" do
    test "is marked permanent" do
      assert %{permanent: true} = SignumCrucis.metadata()
    end

    test "is a debuff" do
      assert %{properties: props} = SignumCrucis.metadata()
      assert :debuff in props
    end

    test "conflicts with itself" do
      assert %{conflicts_with: [:sc_signumcrucis]} = SignumCrucis.metadata()
    end
  end

  describe "modifiers/2" do
    test "reduces DEF by val2 percent" do
      instance = %{val1: 5, val2: 30}
      assert %{def_rate: -30} = SignumCrucis.modifiers(instance, %{})
    end

    test "level 10 debuff — val2=50 gives -50% DEF" do
      instance = %{val1: 10, val2: 50}
      assert %{def_rate: -50} = SignumCrucis.modifiers(instance, %{})
    end
  end
end
