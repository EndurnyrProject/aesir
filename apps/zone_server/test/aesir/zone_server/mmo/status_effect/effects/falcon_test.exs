defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.FalconTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Falcon
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Mmo.StatusEntry

  describe "metadata" do
    test "is a permanent, no_save, no_dispel option mirror carrying the falcon option" do
      meta = Falcon.metadata()

      assert meta.id == :sc_falcon
      assert meta.permanent == true
      assert meta.no_save == true
      assert meta.no_dispel == true
      assert meta.option == :falcon
      assert meta.calc_flags == []
    end

    test "is registered in the status effect registry" do
      definition = Registry.get_definition(:sc_falcon)

      assert definition.module == Falcon
      assert definition.option == :falcon
    end
  end

  describe "modifiers/2" do
    test "contributes no combat modifiers (display mirror only)" do
      assert Falcon.modifiers(%StatusEntry{type: :sc_falcon, state: %{}}, %{}) == %{}
    end
  end
end
