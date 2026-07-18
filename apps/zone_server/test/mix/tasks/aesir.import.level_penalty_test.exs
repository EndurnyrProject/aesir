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

    test "extracts the Mvp_Drop breakpoints as a flat difference => rate map" do
      assert Task.table_for(@body, "Mvp_Drop") == %{5 => 100}
    end

    test "returns an empty map when an optional MVP type is absent from the body" do
      assert Task.table_for(@body, "Mvp_Exp") == %{}
    end

    test "raises when a required type is absent, rather than emitting an empty table" do
      body_without_exp = %{"Body" => Enum.reject(@body["Body"], &(&1["Type"] == "Exp"))}

      assert_raise RuntimeError, ~r/required table Exp missing/, fn ->
        Task.table_for(body_without_exp, "Exp")
      end
    end
  end
end
