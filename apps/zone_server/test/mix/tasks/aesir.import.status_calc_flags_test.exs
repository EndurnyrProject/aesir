defmodule Mix.Tasks.Aesir.Import.StatusCalcFlagsTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.Aesir.Import.StatusCalcFlags

  test "normalizes enabled source flags and split status ids deterministically" do
    rows = [
      %{"Status" => "Gospel", "CalcFlags" => %{"Speed" => true, "Aspd" => true, "Hit" => false}},
      %{"Status" => "Blessing", "CalcFlags" => %{"Str" => true, "Int" => true}},
      %{"Status" => "Strfood", "Script" => "bonus bStr, getstatus(SC_STRFOOD, 1);"}
    ]

    result = StatusCalcFlags.convert!(rows)

    assert Enum.map(result, & &1["id"]) == [
             "sc_blessing",
             "sc_gospel",
             "sc_gospel_slow",
             "sc_strfood"
           ]

    assert Enum.at(result, 1)["flags"] == ["Aspd", "Speed"]
    assert List.last(result)["scripted"]
    assert Enum.at(result, 0)["flags"] == ["Int", "Str"]
    assert StatusCalcFlags.convert!(Enum.reverse(rows)) == result
  end

  test "All selections honor explicit exclusions and invalid input cannot silently disappear" do
    [%{"flags" => flags}] =
      StatusCalcFlags.convert!([
        %{"Status" => "Example", "CalcFlags" => %{"All" => true, "Hit" => false}}
      ])

    assert "Base" in flags
    refute "Hit" in flags
    refute "Dye" in flags

    for selections <- [%{"Imaginary" => true}, %{"Hit" => "true"}] do
      assert_raise ArgumentError, fn ->
        StatusCalcFlags.convert!([%{"Status" => "Example", "CalcFlags" => selections}])
      end
    end

    assert_raise ArgumentError, ~r/colliding/, fn ->
      StatusCalcFlags.convert!([%{"Status" => "Gospel"}, %{"Status" => "Gospel_Slow"}])
    end
  end
end
