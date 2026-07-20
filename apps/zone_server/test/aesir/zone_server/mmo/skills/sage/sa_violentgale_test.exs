defmodule Aesir.ZoneServer.Mmo.Skills.Sage.SaViolentgaleTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skills.Sage.SaViolentgale

  # rAthena db/re/skill_db.yml:5868-5917.
  describe "definition/0" do
    test "matches the Renewal Violent Gale level tables" do
      definition = SaViolentgale.definition()

      assert definition.id == 287
      assert definition.max_level == 5
      assert definition.target_type == :ground
      assert definition.damage_type == :no_damage
      assert definition.range == 2
      assert definition.element == :wind
      assert definition.sp_cost == [48, 46, 44, 42, 40]
      assert definition.cast_time == List.duplicate(4_000, 5)
      assert definition.fixed_cast_time == List.duplicate(1_000, 5)
      assert definition.item_cost == [%{id: 717, amount: 1}]
      assert definition.unit_duration == [60_000, 120_000, 180_000, 240_000, 300_000]
    end
  end

  describe "on_place/1" do
    test "creates the tickless 7x7 element field shared by the trio" do
      assert {:ok, placement} = SaViolentgale.on_place(group(level: 5))

      assert Enum.sort(placement.cells) == Enum.sort(for(x <- 7..13, y <- 17..23, do: {x, y}))
      assert placement.duration == 300_000
      assert placement.path_check
      assert placement.lifecycle_policy.exclusive_family == :sage_element_field
      assert placement.lifecycle_policy.inherit_family_duration
    end

    test "schedule/2 makes the group tickless" do
      assert {:ok, %Group{next_tick_at: nil}} =
               SaViolentgale.schedule(group(next_tick_at: 1_000), fn _ -> 0 end)
    end
  end

  describe "field_support/1" do
    test "grants SC_VIOLENTGALE to every unit with no filter" do
      assert %{status_type: :sc_violentgale, params: params, target?: target?} =
               SaViolentgale.field_support(group(level: 2))

      assert params == [level: 2, val1: 2]
      assert target?.({:player, 100})
      assert target?.({:mob, 200})
    end
  end

  defp group(attrs) do
    struct(
      %Group{
        group_id: 1,
        skill_id: 287,
        skill_name: :sa_violentgale,
        level: 1,
        caster_id: 100,
        caster_type: :player,
        map_name: "prontera",
        center: {10, 20}
      },
      attrs
    )
  end
end
