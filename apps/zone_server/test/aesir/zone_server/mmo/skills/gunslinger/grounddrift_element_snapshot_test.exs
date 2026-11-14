defmodule Aesir.ZoneServer.Mmo.Skills.Gunslinger.GrounddriftElementSnapshotTest do
  use ExUnit.Case, async: true
  import Mimic
  import Aesir.ZoneServer.TrapTestHelper

  alias Aesir.ZoneServer.Mmo.Combat.SkillAttack
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skills.Gunslinger.GsGrounddrift
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator

  setup :set_mimic_private

  setup do
    Mimic.copy(SkillAttack)
    stub_units([mob(7), player(1000)])
    :ok
  end

  test "an endow change after placement keeps the placed element and follow-up" do
    stub(ModifierCalculator, :get_battle_modifiers, fn :mob, 7 ->
      %{enchant_arms_element: :fire}
    end)

    group = %Group{
      group_id: 1,
      skill_id: 521,
      skill_name: :gs_grounddrift,
      level: 3,
      caster_id: 7,
      caster_type: :mob,
      map_name: "prontera",
      center: {50, 50}
    }

    {:ok, placement} = GsGrounddrift.on_place(group)
    assert %{element: :fire, variant: 4} = placement.state

    stub(ModifierCalculator, :get_battle_modifiers, fn :mob, 7 ->
      %{enchant_arms_element: :water}
    end)

    test_pid = self()

    stub(SkillAttack, :execute_splash_attack, fn _c, _ctr, _r, opts ->
      send(test_pid, {:element, Keyword.fetch!(opts, :element)})
      []
    end)

    reject(StatusInterpreter, :apply_status, 4)

    assert {:expire, _} =
             GsGrounddrift.on_unit_hit(
               %{group | state: placement.state},
               {50, 50},
               {:player, 1000},
               0
             )

    assert_received {:element, :fire}
  end
end
