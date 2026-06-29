defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.PushCartTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.PushCart
  alias Aesir.ZoneServer.Mmo.StatusEntry

  defp entry(overrides), do: struct(%StatusEntry{type: :sc_push_cart, state: %{}}, overrides)

  describe "modifiers/2 movement_speed penalty (rAthena 50 - 5 * pushcart_level)" do
    test "level 0 (unlearned) applies the full +50% slowdown" do
      assert %{movement_speed: 50} = PushCart.modifiers(entry(val1: 0), %{})
    end

    test "level 5 applies a +25% slowdown" do
      assert %{movement_speed: 25} = PushCart.modifiers(entry(val1: 5), %{})
    end

    test "max level (10) removes the penalty entirely" do
      assert %{movement_speed: 0} = PushCart.modifiers(entry(val1: 10), %{})
    end
  end

  describe "dynamic_option/1 cart sprite tier (val2)" do
    test "tier 1 maps to :cart1" do
      assert :cart1 = PushCart.dynamic_option(entry(val2: 1))
    end

    test "tier 2 maps to :cart2" do
      assert :cart2 = PushCart.dynamic_option(entry(val2: 2))
    end

    test "tier 3 maps to :cart3" do
      assert :cart3 = PushCart.dynamic_option(entry(val2: 3))
    end

    test "unset tier (0 or nil) defaults to :cart1" do
      assert :cart1 = PushCart.dynamic_option(entry(val2: 0))
      assert :cart1 = PushCart.dynamic_option(entry(val2: nil))
    end
  end
end
