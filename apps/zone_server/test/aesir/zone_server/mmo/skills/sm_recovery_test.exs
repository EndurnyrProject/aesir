defmodule Aesir.ZoneServer.Mmo.Skills.SmRecoveryTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skills.SmRecovery

  @ctx %{max_hp: 1000}

  test "skill_name/0" do
    assert SmRecovery.skill_name() == :sm_recovery
  end

  test "regen_contribution returns non-zero skill_hp_regen scaled by level and max_hp" do
    %{skill_hp_regen: hp} = SmRecovery.regen_contribution(5, @ctx)
    assert hp == 5 * 5 + div(5 * 1000, 500)
  end

  test "regen_contribution scales with level" do
    %{skill_hp_regen: low} = SmRecovery.regen_contribution(1, @ctx)
    %{skill_hp_regen: high} = SmRecovery.regen_contribution(10, @ctx)
    assert high > low
  end
end
