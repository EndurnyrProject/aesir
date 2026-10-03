defmodule Aesir.ZoneServer.Mmo.Skills.Mage.MgSrecoveryTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skills.Mage.MgSrecovery

  test "skill_name/0" do
    assert MgSrecovery.skill_name() == :mg_srecovery
  end

  test "adds the exact Renewal SP recovery contribution per natural regen tick" do
    assert %{skill_sp_regen: 4} = MgSrecovery.regen_contribution(1, %{max_sp: 599})
    assert %{skill_sp_regen: 41} = MgSrecovery.regen_contribution(10, %{max_sp: 599})
  end

  test "contributes no HP regeneration" do
    assert MgSrecovery.regen_contribution(5, %{max_sp: 1000}) == %{skill_sp_regen: 25}
  end
end
