defmodule Aesir.ZoneServer.Mmo.Refine.RefineTest do
  use ExUnit.Case, async: true

  import Aesir.ZoneServer.Factory

  alias Aesir.ZoneServer.Mmo.Refine.Refine

  test "success uses a strict roll and increases the refine level" do
    info = build(:refine_level, chances: %{normal: build(:refine_chance, rate: 5000)})

    assert Refine.outcome(4, info, :normal, false, 4999, 0) == {:success, 5}
    assert Refine.outcome(4, info, :normal, false, 5000, 0) == {:fail}
  end

  test "a safe step succeeds on the highest roll but cannot exceed the cap" do
    info = build(:refine_level, chances: %{normal: build(:refine_chance, rate: 10_000)})

    assert Refine.outcome(4, info, :normal, false, 9999, 9999) == {:success, 5}
    assert Refine.outcome(20, info, :normal, false, 9999, 9999) == {:success, 20}
  end

  test "a blessing prevents both break and downgrade; breaking uses a strict roll" do
    chance = build(:refine_chance, rate: 5000, breaking_rate: 5000, downgrade: 2)
    info = build(:refine_level, chances: %{normal: chance})

    assert Refine.outcome(9, info, :normal, true, 9999, 4999) == {:fail}
    assert Refine.outcome(9, info, :normal, false, 9999, 4999) == {:break}
    assert Refine.outcome(9, info, :normal, false, 9999, 5000) == {:downgrade, 7}
    assert Refine.outcome(1, info, :normal, false, 9999, 5000) == {:downgrade, 0}
  end

  test "an absent level or cost option is not refinable" do
    info = build(:refine_level, chances: %{normal: build(:refine_chance, rate: 5000)})

    assert Refine.outcome(4, nil, :normal, false, 0, 0) == {:error, :not_refinable}
    assert Refine.outcome(4, info, :enriched, false, 0, 0) == {:error, :not_refinable}
  end
end
