defmodule Aesir.ZoneServer.Mmo.Refine.RefineTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Refine.Refine

  defp level_info(chances) do
    %{
      bonus: 0,
      randombonus_max: 0,
      blessing_amount: 0,
      broadcast_success: false,
      broadcast_failure: false,
      chances: chances
    }
  end

  defp chance(overrides) do
    Map.merge(%{rate: 0, price: 0, material_nameid: 1, breaking_rate: 0, downgrade: 0}, overrides)
  end

  test "success_roll under rate succeeds and bumps refine by one" do
    info = level_info(%{normal: chance(%{rate: 5000})})

    assert Refine.outcome(4, info, :normal, false, 4999, 0) == {:success, 5}
  end

  test "a safe level (rate 10000) never fails regardless of the rolls" do
    info = level_info(%{normal: chance(%{rate: 10_000})})

    assert Refine.outcome(4, info, :normal, false, 9999, 9999) == {:success, 5}
  end

  test "blessing-protected failure is a plain no-op" do
    info = level_info(%{normal: chance(%{rate: 5000, breaking_rate: 10_000})})

    assert Refine.outcome(4, info, :normal, true, 9999, 0) == {:fail}
  end

  test "normal high-level failure breaks when the break roll lands under breaking_rate" do
    info = level_info(%{normal: chance(%{rate: 5000, breaking_rate: 5000})})

    assert Refine.outcome(9, info, :normal, false, 9999, 4999) == {:break}
  end

  test "enriched/hd failure downgrades and clamps at zero" do
    info = level_info(%{enriched: chance(%{rate: 5000, downgrade: 2})})

    assert Refine.outcome(9, info, :enriched, false, 9999, 0) == {:downgrade, 7}
    assert Refine.outcome(1, info, :enriched, false, 9999, 0) == {:downgrade, 0}
  end

  test "success never exceeds MAX_REFINE" do
    info = level_info(%{normal: chance(%{rate: 10_000})})

    assert Refine.outcome(20, info, :normal, false, 0, 0) == {:success, 20}
  end

  test "nil level_info is not refinable" do
    assert Refine.outcome(4, nil, :normal, false, 0, 0) == {:error, :not_refinable}
  end

  test "missing cost type is not refinable" do
    info = level_info(%{normal: chance(%{rate: 5000})})

    assert Refine.outcome(4, info, :enriched, false, 0, 0) == {:error, :not_refinable}
  end

  test "plain failure with no breaking rate and no downgrade is a no-op" do
    info = level_info(%{normal: chance(%{rate: 5000})})

    assert Refine.outcome(4, info, :normal, false, 9999, 0) == {:fail}
  end
end
