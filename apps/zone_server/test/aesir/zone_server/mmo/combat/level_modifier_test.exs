defmodule Aesir.ZoneServer.Mmo.Combat.LevelModifierTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Combat.LevelModifier

  test "scales a ratio by base level / 100 only above level 99" do
    assert LevelModifier.skill_ratio(350, 99) == 350
    assert LevelModifier.skill_ratio(350, 50) == 350
    assert LevelModifier.skill_ratio(350, 100) == 350
    assert LevelModifier.skill_ratio(350, 175) == div(350 * 175, 100)
  end
end
