defmodule Aesir.ZoneServer.Script.DslRandomOptionsTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Script.Dsl.Items

  describe "random_options/3" do
    test "reads the slots positionally, casting as the item option fields do" do
      assert Items.random_options([3, 0, 40_000], [70_000, 0, 9], [200, 0, -1]) == [
               %{id: 3, value: 4464, param: -56},
               %{id: 0, value: 0, param: 0},
               %{id: -25_536, value: 9, param: -1}
             ]
    end

    test "reads at most five slots and pads short value arrays with 0" do
      assert Items.random_options([1, 2, 3, 4, 5, 6], [10], []) == [
               %{id: 1, value: 10, param: 0},
               %{id: 2, value: 0, param: 0},
               %{id: 3, value: 0, param: 0},
               %{id: 4, value: 0, param: 0},
               %{id: 5, value: 0, param: 0}
             ]
    end

    test "drops only the all-zero slots after the last non-zero one" do
      assert Items.random_options([7, 0, 0], [1, 5, 0], [0, 0, 0]) == [
               %{id: 7, value: 1, param: 0},
               %{id: 0, value: 5, param: 0}
             ]
    end
  end
end
