defmodule Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculatorTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator

  describe "merge_modifiers/2" do
    test "sums numeric values present in both maps" do
      assert ModifierCalculator.merge_modifiers(%{flee_bonus: 10}, %{flee_bonus: 5}) ==
               %{flee_bonus: 15}
    end

    test "keeps non-colliding keys from both maps" do
      assert ModifierCalculator.merge_modifiers(%{atk_bonus: 3}, %{def_bonus: 4}) ==
               %{atk_bonus: 3, def_bonus: 4}
    end

    test "atom-valued collision takes the newer value instead of crashing" do
      assert ModifierCalculator.merge_modifiers(
               %{attack_element: :fire},
               %{attack_element: :poison}
             ) == %{attack_element: :poison}
    end

    test "mixed numeric/non-numeric collision takes the newer value" do
      assert ModifierCalculator.merge_modifiers(%{attack_element: :fire}, %{attack_element: 2}) ==
               %{attack_element: 2}

      assert ModifierCalculator.merge_modifiers(%{attack_element: 2}, %{attack_element: :fire}) ==
               %{attack_element: :fire}
    end
  end
end
