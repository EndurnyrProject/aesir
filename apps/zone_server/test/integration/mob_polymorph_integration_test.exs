defmodule Aesir.ZoneServer.Integration.MobPolymorphIntegrationTest do
  @moduledoc """
  A monster form change through the real owning session.

  The reset is a first calculation: the new form's raw base publishes with no
  held contribution, while the held statuses, the runtime level and the
  already-fired work survive. A later committed event restores only the fields
  it selects, from the entries held at that moment.
  """

  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Net.SpriteChange
  alias Aesir.ZoneServer.Mmo.StatusEffect.ContextBuilder
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState

  @replacement_id 1001

  test "a form change resets the snapshot and keeps held statuses for later selections" do
    _player = start_player_session(position: {150, 150}, invincible: true)

    mob =
      start_mob_session(
        mob_id: 1002,
        unit_id: 7_101,
        position: {152, 150},
        vit: 0,
        luk: 0,
        awake: false
      )

    # A held Blessing raises the starting form's STR while it is held.
    :ok = Interpreter.apply_status(:mob, mob.unit_id, :sc_blessing, val1: 10)

    assert_eventually(fn ->
      get_mob_state(mob.pid).calculated.str > get_mob_state(mob.pid).base.str
    end)

    blessed = get_mob_state(mob.pid)
    assert blessed.calculated.str == blessed.base.str + 10

    :ok = MobSession.polymorph(mob.pid, @replacement_id)

    assert_eventually(fn -> get_mob_state(mob.pid).mob_id == @replacement_id end)
    changed = get_mob_state(mob.pid)
    raw = changed.base

    assert_packet_sent(SpriteChange)

    # The reset is the replacement form's raw base: the held contribution is
    # gone, the form seed is the replacement's and not the old one, and the
    # status itself, the runtime level and fired work are intact.
    assert changed.calculated == raw
    refute raw == blessed.base
    assert changed.mob_data.id == @replacement_id
    assert MobState.get_level(changed) == MobState.get_level(blessed)
    assert StatusStorage.has_status?(:mob, mob.unit_id, :sc_blessing)
    assert ContextBuilder.get_unit_stats(:mob, mob.unit_id).str == raw.str

    # A later event refreshes only its own selection: Blessing stays out until a
    # selection asks for STR again.
    :ok = Interpreter.apply_status(:mob, mob.unit_id, :sc_increaseagi, val1: 3)

    assert_eventually(fn -> get_mob_state(mob.pid).calculated.agi == raw.agi + 5 end)

    restored = get_mob_state(mob.pid)

    assert restored.calculated.agi == raw.agi + 5
    assert restored.calculated.str == raw.str
    assert MobState.get_stats(restored).str == raw.str
    assert StatusStorage.has_status?(:mob, mob.unit_id, :sc_blessing)
  end
end
