defmodule Aesir.ZoneServer.Mmo.Skills.Alchemist.HomunculusLifecycleSkillsTest do
  use ExUnit.Case, async: false

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Grant

  setup do
    Catalog.reload()
    :ok
  end

  test "Bioethics can be granted at level 1" do
    assert {:ok, %{238 => 1}} = Grant.grant(%{}, 238, 1)
  end

  @tag game_mode: :renewal
  test "pins Renewal lifecycle definitions" do
    assert {:ok, call} = Catalog.by_id(243)

    assert {call.name, call.max_level, call.target_type, call.sp_cost} ==
             {:am_callhomun, 1, :self, [10]}

    assert {:ok, rest} = Catalog.by_id(244)
    assert {rest.name, rest.sp_cost, rest.cooldown} == {:am_rest, [50], [20_000]}

    assert {:ok, resurrection} = Catalog.by_id(247)

    assert resurrection.max_level == 5
    assert resurrection.sp_cost == [74, 68, 62, 56, 50]
    assert resurrection.cast_time == List.duplicate(2_000, 5)
    assert resurrection.fixed_cast_time == List.duplicate(1_000, 5)
    assert resurrection.cooldown == [140_000, 110_000, 80_000, 50_000, 20_000]
  end

  @tag game_mode: :pre_renewal
  test "pins classic lifecycle definitions" do
    assert {:ok, call} = Catalog.by_id(243)
    assert {call.sp_cost, call.duration} == {[10], []}

    assert {:ok, rest} = Catalog.by_id(244)
    assert {rest.sp_cost, rest.cooldown} == {[50], []}

    assert {:ok, resurrection} = Catalog.by_id(247)
    assert resurrection.cast_time == List.duplicate(2_000, 5)
    assert resurrection.fixed_cast_time == []
    assert resurrection.cooldown == []
  end
end
