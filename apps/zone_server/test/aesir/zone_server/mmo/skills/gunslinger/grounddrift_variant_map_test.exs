defmodule Aesir.ZoneServer.Mmo.Skills.Gunslinger.GrounddriftVariantMapTest do
  use ExUnit.Case, async: true
  import Mimic
  import Aesir.ZoneServer.TrapTestHelper

  alias Aesir.ZoneServer.Mmo.Combat.SkillAttack
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skills.Gunslinger.GsGrounddrift
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  setup :set_mimic_private

  setup do
    Mimic.copy(SkillAttack)
    stub_units([player(1000), mob(2)])
    stub(SkillAttack, :execute_field_splash_attack, fn _c, _ctr, _r, _g, _o -> [{:mob, 2}] end)
    test_pid = self()

    stub(StatusInterpreter, :apply_status, fn _t, _i, status, _p ->
      send(test_pid, {:status, status})
      :ok
    end)

    :ok
  end

  defp group(state),
    do: %Group{
      group_id: 1,
      skill_id: 521,
      skill_name: :gs_grounddrift,
      level: 5,
      caster_id: 1000,
      caster_type: :player,
      map_name: "prontera",
      center: {50, 50},
      state: state
    }

  test "the five sub-unit elements select variants 0-4 without rolling" do
    never = fn _ -> flunk("rolled for a fixed element") end

    for {element, variant} <- [wind: 0, dark: 1, poison: 2, water: 3, fire: 4] do
      assert %{variant: ^variant, element: ^element} =
               GsGrounddrift.place_state(element, 0, never)
    end
  end

  test "each status variant applies its own follow-up" do
    for {element, status} <- [
          wind: :sc_stun,
          dark: :sc_blind,
          poison: :sc_poison,
          water: :sc_freeze
        ] do
      state = GsGrounddrift.place_state(element, 0, fn _ -> 1 end)
      assert {:expire, _} = GsGrounddrift.on_unit_hit(group(state), {50, 50}, {:mob, 2}, 0)
      assert_received {:status, ^status}
    end
  end

  test "any other element rolls the variant at placement and uses its follow-up" do
    for element <- [:neutral, :holy, :earth, :ghost, :undead] do
      state = GsGrounddrift.place_state(element, 0, fn 5 -> 3 end)
      assert %{variant: 2, element: ^element} = state
      assert {:expire, _} = GsGrounddrift.on_unit_hit(group(state), {50, 50}, {:mob, 2}, 0)
      assert_received {:status, :sc_poison}
    end
  end
end
