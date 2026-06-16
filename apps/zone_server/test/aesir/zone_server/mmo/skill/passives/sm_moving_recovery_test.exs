defmodule Aesir.ZoneServer.Mmo.Skill.Passives.SmMovingRecoveryTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skill.Passives.SmMovingRecovery

  test "skill_name/0" do
    assert SmMovingRecovery.skill_name() == :sm_movingrecovery
  end

  test "regen_contribution allows regen while moving" do
    assert SmMovingRecovery.regen_contribution(1, %{}) == %{allow_while_moving: true}
  end
end
