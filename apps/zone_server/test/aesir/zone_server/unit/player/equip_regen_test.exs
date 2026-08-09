defmodule Aesir.ZoneServer.Unit.Player.EquipRegenTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Unit.Player.EquipRegen

  describe "compute/3" do
    test "no periodic gear yields the empty no-op result" do
      assert EquipRegen.compute(%{:str => 5, {:addrace, :brute} => 20}, %{}, 500) == {0, 0, %{}}
    end

    test "accumulates elapsed time without firing before the interval elapses" do
      mods = %{{:hp_regen_bonus, 1_000} => 5}
      assert {0, 0, acc} = EquipRegen.compute(mods, %{}, 500)
      assert acc == %{{:hp_regen_bonus, 1_000} => 500}
    end

    test "fires once when the interval is reached and carries the remainder" do
      mods = %{{:hp_regen_bonus, 1_000} => 5}
      acc0 = %{{:hp_regen_bonus, 1_000} => 700}
      assert {5, 0, acc} = EquipRegen.compute(mods, acc0, 500)
      assert acc == %{{:hp_regen_bonus, 1_000} => 200}
    end

    test "fires multiple whole intervals in one tick" do
      mods = %{{:hp_regen_bonus, 200} => 3}
      assert {6, 0, acc} = EquipRegen.compute(mods, %{}, 500)
      assert acc == %{{:hp_regen_bonus, 200} => 100}
    end

    test "loss entries accumulate into the loss total" do
      mods = %{{:hp_loss_bonus, 1_000} => 10}
      assert {0, 10, _acc} = EquipRegen.compute(mods, %{{:hp_loss_bonus, 1_000} => 500}, 500)
    end

    test "regen and loss are summed independently" do
      mods = %{{:hp_regen_bonus, 500} => 7, {:hp_loss_bonus, 500} => 4}
      assert {7, 4, _acc} = EquipRegen.compute(mods, %{}, 500)
    end

    test "drops accumulators for entries no longer present" do
      mods = %{{:hp_regen_bonus, 1_000} => 5}
      stale = %{{:hp_loss_bonus, 1_000} => 400, {:hp_regen_bonus, 1_000} => 400}
      assert {0, 0, acc} = EquipRegen.compute(mods, stale, 100)
      assert Map.keys(acc) == [{:hp_regen_bonus, 1_000}]
    end
  end
end
