defmodule Aesir.ZoneServer.Unit.Player.LifePotionRegenTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Unit.Player.EquipRegen

  test "periodic percentage recovery truncates each interval and adds to flat recovery" do
    modifiers = %{
      {:percent_hp_regen_bonus, {:sc_s_lifepotion, 5_000}} => 5,
      {:percent_hp_regen_bonus, {:sc_l_lifepotion, 4_000}} => 7,
      {:hp_regen_bonus, 5_000} => 3
    }

    assert {deltas, accumulators} =
             EquipRegen.compute(modifiers, %{}, 10_500, %{max_hp: 199, max_sp: 100})

    assert deltas.hp_gain == 50
    assert deltas.hp_loss == 0
    assert deltas.sp_gain == 0

    assert accumulators == %{
             {:percent_hp_regen_bonus, {:sc_s_lifepotion, 5_000}} => 500,
             {:percent_hp_regen_bonus, {:sc_l_lifepotion, 4_000}} => 2_500,
             {:hp_regen_bonus, 5_000} => 500
           }
  end

  test "coexisting percentages truncate separately even when their intervals match" do
    modifiers = %{
      {:percent_hp_regen_bonus, {:sc_s_lifepotion, 5_000}} => 5,
      {:percent_hp_regen_bonus, {:sc_l_lifepotion, 5_000}} => 7
    }

    assert {deltas, _accumulators} =
             EquipRegen.compute(modifiers, %{}, 5_000, %{max_hp: 199})

    assert deltas.hp_gain == 22
  end

  test "signed percentages are percentages, and invalid intervals do not accumulate" do
    modifiers = %{
      {:percent_hp_regen_bonus, {:sc_s_lifepotion, 5_000}} => -5,
      {:percent_hp_regen_bonus, {:sc_l_lifepotion, 0}} => 100
    }

    assert {deltas, accumulators} =
             EquipRegen.compute(modifiers, %{}, 5_000, %{max_hp: 199})

    assert deltas.hp_gain == -9
    assert map_size(accumulators) == 1
  end

  test "percentage intervals carry progress and use the current maximum at their deadline" do
    modifiers = %{{:percent_hp_regen_bonus, {:sc_s_lifepotion, 5_000}} => 5}

    assert {first, progress} =
             EquipRegen.compute(modifiers, %{}, 4_500, %{max_hp: 199, max_sp: 100})

    assert first.hp_gain == 0

    assert {second, _progress} =
             EquipRegen.compute(modifiers, progress, 500, %{max_hp: 401, max_sp: 100})

    assert second.hp_gain == 20
  end
end
