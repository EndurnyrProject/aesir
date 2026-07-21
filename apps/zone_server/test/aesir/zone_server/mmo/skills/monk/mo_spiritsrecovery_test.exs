defmodule Aesir.ZoneServer.Mmo.Skills.Monk.MoSpiritsrecoveryTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Monk.MoSpiritsrecovery

  test "returns the verified sitting HP and SP recovery contributions" do
    assert MoSpiritsrecovery.regen_contribution(1, %{max_hp: 499, max_sp: 499}) ==
             %{sitting_hp_regen: 4, sitting_sp_regen: 2}

    assert MoSpiritsrecovery.regen_contribution(5, %{max_hp: 10_000, max_sp: 10_000}) ==
             %{sitting_hp_regen: 120, sitting_sp_regen: 110}
  end

  test "is discovered as passive skill id 260" do
    assert {:ok, definition} = Catalog.by_id(260)
    assert definition.name == :mo_spiritsrecovery
    assert definition.max_level == 5
    assert definition.target_type == :passive
  end
end
