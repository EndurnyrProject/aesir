defmodule Mix.Tasks.Aesir.Import.LevelPenaltyTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.Aesir.Import.LevelPenalty, as: Task

  @body %{
    "Body" => [
      %{
        "Type" => "Drop",
        "LevelDifferences" => [
          %{"Difference" => 16, "Rate" => 50},
          %{"Difference" => -16, "Rate" => 50},
          %{"Difference" => 4, "Rate" => 90}
        ]
      },
      %{
        "Type" => "Exp",
        "LevelDifferences" => [
          %{"Difference" => 30, "Rate" => 70},
          %{"Difference" => -30, "Rate" => 70},
          %{"Difference" => 20, "Rate" => 90}
        ]
      },
      %{
        "Type" => "Mvp_Drop",
        "LevelDifferences" => [
          %{"Difference" => 5, "Rate" => 100}
        ]
      }
    ]
  }

  describe "table_for/2" do
    test "extracts the Drop breakpoints as a flat difference => rate map" do
      assert Task.table_for(@body, "Drop") == %{16 => 50, -16 => 50, 4 => 90}
    end

    test "extracts the Exp breakpoints as a flat difference => rate map" do
      assert Task.table_for(@body, "Exp") == %{30 => 70, -30 => 70, 20 => 90}
    end

    test "does not mix breakpoints across types" do
      exp_table = Task.table_for(@body, "Exp")

      refute Map.has_key?(exp_table, 16)
      refute Map.has_key?(exp_table, 5)
    end
  end
end
