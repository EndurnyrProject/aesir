defmodule Aesir.ZoneServer.Mmo.Skills.Alchemist.HomunculusLifecycleSkillsTest do
  use ExUnit.Case, async: false

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Grant

  setup do
    Catalog.reload()
    :ok
  end

  test "catalogues Bioethics as an Alchemist quest grant only" do
    assert {:ok, definition} = Catalog.by_id(238)
    assert definition.name == :am_bioethics
    assert definition.max_level == 1
    assert definition.quest_skill
    assert definition.quest_owner_job == :alchemist
    assert {:ok, %{238 => 1}} = Grant.grant(%{}, 238, 1)
  end

  test "pins Renewal lifecycle definitions" do
    assert {:ok, call} = Catalog.by_id(243)

    assert {call.name, call.max_level, call.target_type, call.sp_cost} ==
             {:am_callhomun, 1, :self, [10]}

    assert {:ok, rest} = Catalog.by_id(244)
    assert {rest.name, rest.sp_cost, rest.cooldown} == {:am_rest, [50], [20_000]}

    assert {:ok, resurrection} = Catalog.by_id(247)

    assert resurrection.name == :am_resurrecthomun
    assert resurrection.max_level == 5
    assert resurrection.sp_cost == [74, 68, 62, 56, 50]
    assert resurrection.cast_time == List.duplicate(2_000, 5)
    assert resurrection.fixed_cast_time == List.duplicate(1_000, 5)
    assert resurrection.cooldown == [140_000, 110_000, 80_000, 50_000, 20_000]
  end
end
