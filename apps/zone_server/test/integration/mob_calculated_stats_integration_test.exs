defmodule Aesir.ZoneServer.Integration.MobCalculatedStatsIntegrationTest do
  @moduledoc """
  A monster's calculated stats cross the real session boundary.

  A committed status event is the only thing that recalculates a monster: the
  owning session publishes one snapshot that the resistance inputs, the battle
  view and the session's own readers all observe, and a storage write the owner
  never processes changes nothing until the owner recalcs it.
  """

  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.StatusEffect.ContextBuilder
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobState

  test "a committed status reaches every calculated reader through the owner commit" do
    mob =
      start_mob_session(
        mob_id: 1002,
        unit_id: 7_001,
        position: {150, 150},
        vit: 0,
        luk: 0,
        awake: false
      )

    before = MobState.get_stats(get_mob_state(mob.pid))
    {:ok, before_battle} = Combat.resolve_combatant(:mob, mob.unit_id)

    assert ContextBuilder.get_unit_stats(:mob, mob.unit_id).str == before.str
    assert before_battle.base_stats.str == before.str

    :ok = Interpreter.apply_status(:mob, mob.unit_id, :sc_blessing, val1: 10)

    assert_eventually(fn ->
      ContextBuilder.get_unit_stats(:mob, mob.unit_id).str == before.str + 10
    end)

    {:ok, after_battle} = Combat.resolve_combatant(:mob, mob.unit_id)
    after_status = get_mob_state(mob.pid)

    assert after_battle.base_stats.str == before.str + 10
    assert MobState.get_stats(after_status).str == before.str + 10
    assert after_status.calculated.str == after_status.base.str + 10

    # A storage write the owner never processes leaves the published snapshot
    # untouched: no reader folds status entries of its own.
    :ok = StatusStorage.apply_status(:mob, mob.unit_id, :sc_gd_soulcold, val1: 5)

    untouched = get_mob_state(mob.pid)

    assert untouched.calculated.agi == before.agi
    assert ContextBuilder.get_unit_stats(:mob, mob.unit_id).agi == before.agi

    # The next committed event recalculates its own selection from every entry
    # held at that moment, including the one written above.
    :ok = Interpreter.apply_status(:mob, mob.unit_id, :sc_increaseagi, val1: 6)

    assert_eventually(fn -> get_mob_state(mob.pid).calculated.agi == before.agi + 13 end)

    recalculated = get_mob_state(mob.pid)

    assert recalculated.calculated.agi == before.agi + 13
    assert recalculated.calculated.str == before.str + 10
    assert StatusStorage.has_status?(:mob, mob.unit_id, :sc_gd_soulcold)
  end
end
