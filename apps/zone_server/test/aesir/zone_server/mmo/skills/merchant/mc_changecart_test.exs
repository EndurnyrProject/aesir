defmodule Aesir.ZoneServer.Mmo.Skills.Merchant.McChangecartTest do
  use ExUnit.Case, async: true

  import Mimic

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Merchant.McChangecart
  alias Aesir.ZoneServer.Unit.Player.Handlers.CartHandler

  setup :verify_on_exit!

  defp caster(opts) do
    %{
      character_id: 1000,
      cart_type: Keyword.get(opts, :cart_type, 1),
      stats: %{progression: %{base_level: Keyword.get(opts, :base_level, 50)}}
    }
  end

  describe "skill data" do
    test "mc_changecart loads from the catalog as a self no-damage skill at id 154" do
      assert {:ok, definition} = Catalog.by_id(154)
      assert {:ok, ^definition} = Catalog.by_name(:mc_changecart)
      assert definition.name == :mc_changecart
      assert definition.display_name == "Change Cart"
      assert definition.target_type == :self
      assert definition.damage_type == :no_damage
      assert definition.max_level == 1
      assert definition.sp_cost == [40]
    end

    test "is registered as an active skill" do
      assert {:ok, McChangecart} = Catalog.active_module_for(:mc_changecart)
    end
  end

  describe "cast/4" do
    test "rejects with :no_cart when no cart is mounted, without touching the handler" do
      reject(&CartHandler.change_cart_tier/2)

      assert {:error, :no_cart} =
               McChangecart.cast(caster(cart_type: 0), :self, 1, McChangecart.definition())
    end

    test "delegates to CartHandler.change_cart_tier with the caster's base level" do
      caster = caster(cart_type: 1, base_level: 70)

      expect(CartHandler, :change_cart_tier, fn ^caster, 70 ->
        {:ok, %{caster | cart_type: 3}}
      end)

      assert {:ok, %{cart_type: 3}} =
               McChangecart.cast(caster, :self, 1, McChangecart.definition())
    end

    test "propagates a no-upgrade error from the handler" do
      caster = caster(cart_type: 1, base_level: 30)

      expect(CartHandler, :change_cart_tier, fn ^caster, 30 -> {:error, :no_cart_upgrade} end)

      assert {:error, :no_cart_upgrade} =
               McChangecart.cast(caster, :self, 1, McChangecart.definition())
    end
  end
end
