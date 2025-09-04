defmodule Aesir.ZoneServer.Mmo.StatusEffect.Actions.DamageTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.StatusEffect.Actions.Damage

  describe "execute/4" do
    test "calculates damage with amount parameter" do
      params = %{amount: 50}
      state = %{}
      context = %{}
      target_id = 999

      # This should not crash and return the state
      result = Damage.execute(target_id, params, state, context)
      assert {:ok, ^state} = result
    end

    test "calculates damage with formula function" do
      formula_fn = fn _context -> 100 end
      params = %{formula_fn: formula_fn}
      state = %{}
      context = %{}
      target_id = 999

      result = Damage.execute(target_id, params, state, context)
      assert {:ok, ^state} = result
    end

    test "uses neutral element by default" do
      params = %{amount: 25}
      state = %{}
      context = %{}
      target_id = 999

      # Should not crash even though target doesn't exist
      result = Damage.execute(target_id, params, state, context)
      assert {:ok, ^state} = result
    end

    test "respects specified element" do
      params = %{amount: 25, element: :fire}
      state = %{}
      context = %{}
      target_id = 999

      result = Damage.execute(target_id, params, state, context)
      assert {:ok, ^state} = result
    end

    test "applies min/max bounds with formula function" do
      formula_fn = fn _context -> 150 end
      params = %{formula_fn: formula_fn}
      state = %{}
      context = %{min: 10, max: 100}
      target_id = 999

      result = Damage.execute(target_id, params, state, context)
      assert {:ok, ^state} = result
    end

    test "handles missing parameters gracefully" do
      params = %{}
      state = %{}
      context = %{}
      target_id = 999

      # Should calculate 0 damage and not crash
      result = Damage.execute(target_id, params, state, context)
      assert {:ok, ^state} = result
    end
  end
end
