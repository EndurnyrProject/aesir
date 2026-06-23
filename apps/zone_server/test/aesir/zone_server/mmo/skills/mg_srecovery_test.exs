defmodule Aesir.ZoneServer.Mmo.Skills.MgSrecoveryTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.MgSrecovery

  @ctx %{max_sp: 1000}

  test "skill_name/0" do
    assert MgSrecovery.skill_name() == :mg_srecovery
  end

  test "regen_contribution returns skill_sp_regen scaled by level and max_sp" do
    %{skill_sp_regen: sp} = MgSrecovery.regen_contribution(5, @ctx)
    assert sp == 5 * 3 + div(5 * 1000, 500)
  end

  test "regen_contribution scales with level" do
    %{skill_sp_regen: low} = MgSrecovery.regen_contribution(1, @ctx)
    %{skill_sp_regen: high} = MgSrecovery.regen_contribution(10, @ctx)
    assert high > low
  end

  test "catalog resolves id 9" do
    assert {:ok, %{name: :mg_srecovery}} = Catalog.by_id(9)
  end
end
