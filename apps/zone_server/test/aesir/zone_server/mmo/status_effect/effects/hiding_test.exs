defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.HidingTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Hiding

  describe "metadata" do
    test "is a concealing, movement-preventing status" do
      metadata = Hiding.metadata()

      assert metadata.no_save
      assert metadata.no_dispel
      assert :conceals in metadata.properties
      assert :hide in metadata.flags
    end

    test "is cleared by a cross-map warp" do
      assert Hiding.metadata().remove_on_map_change
    end
  end
end
