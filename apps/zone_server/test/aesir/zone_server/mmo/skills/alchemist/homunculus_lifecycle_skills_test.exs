defmodule Aesir.ZoneServer.Mmo.Skills.Alchemist.HomunculusLifecycleSkillsTest do
  use ExUnit.Case, async: false

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Grant
  alias Aesir.ZoneServer.Mmo.Skills.Alchemist.AmCallhomun
  alias Aesir.ZoneServer.Mmo.Skills.Alchemist.AmRest
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @embryo 7142
  @seed 7140

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

  # skill.cpp:8701-8705: a homunculus out and not vaporized fails Call at cast
  # begin with the bare clif_skill_fail.
  describe "Call Homunculus cast begin" do
    test "refuses an active or dead homunculus and passes a resting or absent one" do
      assert {:error, :invalid_lifecycle} = begin_call(summary(:active, 100, 100))
      assert {:error, :dead} = begin_call(summary(:dead, 0, 100))
      assert {:ok, _caster} = begin_call(summary(:rested, 100, 100))
      assert {:ok, _caster} = begin_call(nil)
    end
  end

  # skill.cpp:9883-9906 (skill_get_requirement), checked at the cast end.
  describe "Call Homunculus cast-end items" do
    @tag game_mode: :renewal
    test "renewal needs an Embryo for a first call and a Seed of Life for a recall" do
      assert {:error, :missing_catalyst} = call_items(nil, [])
      assert :ok = call_items(nil, [@embryo])
      assert {:error, :missing_catalyst} = call_items(summary(:rested, 1, 1), [@embryo])
      assert :ok = call_items(summary(:rested, 1, 1), [@seed])
    end

    @tag game_mode: :pre_renewal
    test "pre-renewal needs an Embryo for a first call and nothing for a recall" do
      assert {:error, :missing_catalyst} = call_items(nil, [])
      assert :ok = call_items(nil, [@embryo])
      assert :ok = call_items(summary(:rested, 1, 1), [])
    end
  end

  # skill.cpp:8707-8711: no active homunculus or HP below 80 percent fails Rest
  # at cast begin with the bare clif_skill_fail.
  describe "Rest cast begin" do
    test "needs an active homunculus at 80 percent of its HP" do
      assert {:error, :no_companion} = begin_rest(nil)
      assert {:error, :dead} = begin_rest(summary(:dead, 0, 100))
      assert {:error, :invalid_lifecycle} = begin_rest(summary(:rested, 100, 100))
      assert {:error, :hp_gate} = begin_rest(summary(:active, 79, 100))
      assert {:ok, _caster} = begin_rest(summary(:active, 80, 100))
    end

    test "compares HP against the integer 80 percent of max HP" do
      assert {:ok, _caster} = begin_rest(summary(:active, 80, 101))
      assert {:error, :hp_gate} = begin_rest(summary(:active, 79, 101))
    end
  end

  defp summary(lifecycle, hp, max_hp), do: %{lifecycle: lifecycle, hp: hp, max_hp: max_hp}

  defp begin_call(summary),
    do: AmCallhomun.begin_attempt(caster(summary, []), :self, 1, AmCallhomun.definition())

  defp begin_rest(summary),
    do: AmRest.begin_attempt(caster(summary, []), :self, 1, AmRest.definition())

  defp call_items(summary, items),
    do:
      AmCallhomun.castend_requirement(caster(summary, items), :self, 1, AmCallhomun.definition())

  defp caster(summary, items) do
    inventory =
      items
      |> Enum.with_index()
      |> Map.new(fn {id, index} -> {index, %InventoryItem{nameid: id, amount: 1}} end)

    %PlayerState{character_id: 1, homunculus_summary: summary, inventory: inventory}
  end
end
