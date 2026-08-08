defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.GrandcrossRootTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.GrandcrossRoot

  describe "metadata" do
    test "roots the caster and recalculates DEF/MDEF" do
      metadata = GrandcrossRoot.metadata()

      assert :prevents_movement in metadata.properties
      assert metadata.no_save
      assert metadata.remove_on_map_change
      assert :def in metadata.calc_flags
      assert :mdef in metadata.calc_flags
    end
  end

  describe "modifiers/2" do
    test "suppresses the captured shield DEF/MDEF as negative flat modifiers" do
      instance = %{val1: 7, val2: 3}
      assert %{def: -7, mdef: -3} = GrandcrossRoot.modifiers(instance, %{})
    end

    test "a shieldless caster (zero capture) suppresses nothing" do
      instance = %{val1: 0, val2: 0}
      assert %{def: 0, mdef: 0} = GrandcrossRoot.modifiers(instance, %{})
    end

    test "tolerates a nil capture" do
      instance = %{val1: nil, val2: nil}
      assert %{def: 0, mdef: 0} = GrandcrossRoot.modifiers(instance, %{})
    end
  end
end
