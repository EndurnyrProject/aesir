defmodule Aesir.ZoneServer.Mmo.Skills.Gunslinger.GrounddriftFollowupTest do
  use ExUnit.Case, async: true
  import Mimic
  import Aesir.ZoneServer.TrapTestHelper

  alias Aesir.ZoneServer.Mmo.Combat.Knockback
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

    stub(StatusInterpreter, :apply_status, fn :mob, 2, status, params ->
      send(test_pid, {:status, status, params})
      :ok
    end)

    :ok
  end

  defp strike(variant) do
    group = %Group{
      group_id: 1,
      skill_id: 521,
      skill_name: :gs_grounddrift,
      level: 10,
      caster_id: 1000,
      caster_type: :player,
      map_name: "prontera",
      center: {48, 51},
      state: %{element: :neutral, variant: variant, armed_until: 0}
    }

    assert {:expire, _} = GsGrounddrift.on_unit_hit(group, {48, 51}, {:mob, 2}, 0)
  end

  defp durations do
    for variant <- 0..3 do
      strike(variant)
      assert_received {:status, status, params}
      assert params[:success_rate] == 50
      assert params[:caster_id] == 1000
      {status, params[:duration]}
    end
  end

  @tag game_mode: :renewal
  test "renewal follow-ups use the Duration2 entries 1-4" do
    assert durations() == [sc_stun: 5_000, sc_blind: 20_000, sc_poison: 20_000, sc_freeze: 30_000]
  end

  @tag game_mode: :pre_renewal
  test "pre-renewal follow-ups use the Duration2 entries 1-4" do
    assert durations() == [sc_stun: 5_000, sc_blind: 30_000, sc_poison: 60_000, sc_freeze: 12_000]
  end

  test "fire pushes 3 cells away from the unit cell and applies no status" do
    test_pid = self()

    stub(Knockback, :knockback, fn type, id, x, y, distance ->
      send(test_pid, {:blown, type, id, x, y, distance})
      :ok
    end)

    strike(4)
    assert_received {:blown, :mob, 2, 48, 51, 3}
    refute_received {:status, _, _}
  end
end
