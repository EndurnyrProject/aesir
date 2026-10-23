defmodule Aesir.ZoneServer.Mmo.Skills.Merchant.McChangecartTest do
  use ExUnit.Case, async: true

  import Mimic

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

  describe "cast/4" do
    # skill.cpp ST_CART castbegin row: USESKILL_FAIL_CART before anything is spent.
    test "cannot begin without a mounted cart, without touching the handler" do
      reject(&CartHandler.change_cart_tier/2)

      assert {:error, :cart} =
               McChangecart.begin_attempt(
                 caster(cart_type: 0),
                 :self,
                 1,
                 McChangecart.definition()
               )
    end

    test "delegates to CartHandler.change_cart_tier with the caster's base level" do
      caster = caster(cart_type: 1, base_level: 70)

      expect(CartHandler, :change_cart_tier, fn ^caster, 70 ->
        {:ok, %{caster | cart_type: 3}}
      end)

      assert {:ok, %{cart_type: 3}} =
               McChangecart.cast(caster, :self, 1, McChangecart.definition())
    end

    test "keeps the cast when the handler has no upgrade to make" do
      caster = caster(cart_type: 1, base_level: 30)

      expect(CartHandler, :change_cart_tier, fn ^caster, 30 -> {:error, :no_cart_upgrade} end)

      assert {:ok, ^caster} = McChangecart.cast(caster, :self, 1, McChangecart.definition())
    end
  end
end
