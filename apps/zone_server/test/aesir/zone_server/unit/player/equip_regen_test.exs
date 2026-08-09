defmodule Aesir.ZoneServer.Unit.Player.EquipRegenTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Unit.Player.EquipRegen

  @zero %{hp_gain: 0, hp_loss: 0, sp_gain: 0, sp_loss: 0}

  describe "compute/3" do
    test "no periodic gear yields zero deltas and empty accumulators" do
      assert EquipRegen.compute(%{:str => 5, {:addrace, :brute} => 20}, %{}, 500) == {@zero, %{}}
    end

    test "accumulates elapsed time without firing before the interval elapses" do
      mods = %{{:hp_regen_bonus, 1_000} => 5}
      assert {@zero, acc} = EquipRegen.compute(mods, %{}, 500)
      assert acc == %{{:hp_regen_bonus, 1_000} => 500}
    end

    test "fires once when the interval is reached and carries the remainder" do
      mods = %{{:hp_regen_bonus, 1_000} => 5}
      acc0 = %{{:hp_regen_bonus, 1_000} => 700}
      assert {deltas, acc} = EquipRegen.compute(mods, acc0, 500)
      assert deltas.hp_gain == 5
      assert acc == %{{:hp_regen_bonus, 1_000} => 200}
    end

    test "fires multiple whole intervals in one tick" do
      mods = %{{:hp_regen_bonus, 200} => 3}
      assert {deltas, acc} = EquipRegen.compute(mods, %{}, 500)
      assert deltas.hp_gain == 6
      assert acc == %{{:hp_regen_bonus, 200} => 100}
    end

    test "hp loss entries accumulate into the hp_loss total" do
      mods = %{{:hp_loss_bonus, 1_000} => 10}
      assert {deltas, _acc} = EquipRegen.compute(mods, %{{:hp_loss_bonus, 1_000} => 500}, 500)
      assert deltas.hp_loss == 10
    end

    test "sp regen and sp loss accumulate into their own buckets" do
      mods = %{{:sp_regen_bonus, 500} => 7, {:sp_loss_bonus, 500} => 4}
      assert {deltas, _acc} = EquipRegen.compute(mods, %{}, 500)
      assert deltas.sp_gain == 7
      assert deltas.sp_loss == 4
    end

    test "all four families are summed independently in one tick" do
      mods = %{
        {:hp_regen_bonus, 500} => 1,
        {:hp_loss_bonus, 500} => 2,
        {:sp_regen_bonus, 500} => 3,
        {:sp_loss_bonus, 500} => 4
      }

      assert {%{hp_gain: 1, hp_loss: 2, sp_gain: 3, sp_loss: 4}, _acc} =
               EquipRegen.compute(mods, %{}, 500)
    end

    test "drops accumulators for entries no longer present" do
      mods = %{{:hp_regen_bonus, 1_000} => 5}
      stale = %{{:hp_loss_bonus, 1_000} => 400, {:hp_regen_bonus, 1_000} => 400}
      assert {@zero, acc} = EquipRegen.compute(mods, stale, 100)
      assert Map.keys(acc) == [{:hp_regen_bonus, 1_000}]
    end
  end
end
