defmodule Aesir.ZoneServer.Mmo.Skills.Gunslinger.GrounddriftLifecycleTest do
  use ExUnit.Case, async: true
  import Mimic
  import Aesir.ZoneServer.TrapTestHelper

  alias Aesir.ZoneServer.Mmo.Combat.SkillAttack
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.View
  alias Aesir.ZoneServer.Mmo.Skills.Gunslinger.GsGrounddrift
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator

  setup :set_mimic_private

  setup do
    Mimic.copy(SkillAttack)
    stub_units([player(1000), mob(2), mob(7)])
    stub(Targeting, :validate_field_target, fn _g, _c, _t -> :ok end)
    :ok
  end

  defp group(state, attrs \\ []),
    do:
      struct(
        %Group{
          group_id: 1,
          skill_id: 521,
          skill_name: :gs_grounddrift,
          level: 2,
          caster_id: 1000,
          caster_type: :player,
          map_name: "prontera",
          center: {50, 50},
          state: state
        },
        attrs
      )

  test "placement arms for 3 s per level and lingers 1.5 s inert" do
    stub(ModifierCalculator, :get_battle_modifiers, fn _, _ -> %{} end)
    before = System.monotonic_time(:millisecond)
    {:ok, placement} = GsGrounddrift.on_place(group(%{}, caster_id: 7, caster_type: :mob))
    later = System.monotonic_time(:millisecond)

    assert placement.duration == 7_500
    assert placement.unit_range == 1
    assert placement.state.armed_until in (before + 6_000)..(later + 6_000)
  end

  test "an armed drift targets enemies and an inert one targets nobody" do
    now = System.monotonic_time(:millisecond)
    armed = group(%{element: :wind, variant: 0, armed_until: now + 60_000})
    inert = group(%{element: :wind, variant: 0, armed_until: now})

    assert GsGrounddrift.unit_targets(armed, {50, 50}, [{:mob, 2}]) == [{:mob, 2}]
    assert GsGrounddrift.unit_targets(inert, {50, 50}, [{:mob, 2}]) == []
  end

  test "a triggered drift expires at once and bursts only once per pass" do
    stub(SkillAttack, :execute_field_splash_attack, fn _c, _ctr, _r, _g, _o -> [{:mob, 2}] end)
    stub(StatusInterpreter, :apply_status, fn _t, _i, _s, _p -> :ok end)
    drift = group(%{element: :wind, variant: 0, armed_until: 0})

    assert {:expire, spent} = GsGrounddrift.on_unit_hit(drift, {50, 50}, {:mob, 2}, 0)

    reject(SkillAttack, :execute_field_splash_attack, 5)
    assert {:expire, ^spent} = GsGrounddrift.on_unit_hit(spent, {50, 50}, {:mob, 7}, 0)
  end

  test "the wire group carries the variant, 0 without one" do
    placed = group(%{variant: 3}, cells: [{50, 50}], created_at: 0, expires_at: 7_500)

    assert View.group(placed, []).unit_variant == 3
    assert View.group(%{placed | state: %{}}, []).unit_variant == 0
  end
end
