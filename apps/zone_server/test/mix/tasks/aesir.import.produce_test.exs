defmodule Mix.Tasks.Aesir.Import.ProduceTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.Aesir.Import.Produce, as: Task

  describe "parse_recipes/1" do
    test "normalizes a weapon recipe" do
      assert Task.parse_recipes("0,1101,1,99,1,998,2\n") == [
               %{
                 "id" => 0,
                 "product_id" => 1101,
                 "item_level" => 1,
                 "skill_id" => 99,
                 "skill_level" => 1,
                 "materials" => [%{"item_id" => 998, "amount" => 2}]
               }
             ]
    end

    test "preserves every material pair" do
      assert [recipe] = Task.parse_recipes("1,1102,3,99,3,998,20,999,5,1000,1\n")

      assert recipe["materials"] == [
               %{"item_id" => 998, "amount" => 20},
               %{"item_id" => 999, "amount" => 5},
               %{"item_id" => 1000, "amount" => 1}
             ]
    end

    test "preserves possession-only materials" do
      assert [recipe] = Task.parse_recipes("2,1103,1,99,1,7131,0\n")
      assert recipe["materials"] == [%{"item_id" => 7131, "amount" => 0}]
    end

    test "skips comments and blank lines" do
      assert Task.parse_recipes("\n// Sword recipe\n3,1104,1,99,1,998,2\n\n") == [
               %{
                 "id" => 3,
                 "product_id" => 1104,
                 "item_level" => 1,
                 "skill_id" => 99,
                 "skill_level" => 1,
                 "materials" => [%{"item_id" => 998, "amount" => 2}]
               }
             ]
    end
  end
end
