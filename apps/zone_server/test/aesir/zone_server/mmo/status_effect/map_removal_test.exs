defmodule Aesir.ZoneServer.Mmo.StatusEffect.MapRemovalTest do
  @moduledoc """
  The statuses a unit loses when it leaves its map (`Interpreter.remove_on_map_change/2`):
  the flagged ones, Cloaking, the Battle Chant caster lock and an infinite Provoke.
  """

  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Skill.Unit
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Basilica
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Mmo.StatusStorage

  setup :set_mimic_private
  setup :setup_ets_tables

  @mob_id 9_901

  test "a unit leaving its map loses its flagged statuses, Cloaking, its chant and an infinite Provoke" do
    test_pid = self()
    stub(Unit, :destroy_async, fn group_id -> send(test_pid, {:destroyed, group_id}) end)

    :ok = StatusStorage.apply_status(:mob, @mob_id, :sc_hiding, val1: 10, duration: 60_000)
    :ok = StatusStorage.apply_status(:mob, @mob_id, :sc_cloaking, val1: 10, duration: 60_000)
    :ok = StatusStorage.apply_status(:mob, @mob_id, :sc_gospel, val1: 1, val2: 77)
    :ok = StatusStorage.apply_status(:mob, @mob_id, :sc_provoke, val1: 10, val4: 1)
    :ok = StatusStorage.apply_status(:mob, @mob_id, :sc_blessing, val1: 5, duration: 60_000)
    :ok = StatusStorage.apply_status(:mob, @mob_id, :sc_avoid, val1: 1, duration: 60_000)

    :ok = Interpreter.remove_on_map_change(:mob, @mob_id)

    assert_received {:destroyed, 77}

    assert @mob_id
           |> then(&StatusStorage.get_unit_statuses(:mob, &1))
           |> Enum.map(& &1.type)
           |> Enum.sort() == [:sc_avoid, :sc_blessing]
  end

  test "a Provoke that is not the infinite one stays" do
    :ok = StatusStorage.apply_status(:mob, @mob_id, :sc_provoke, val1: 10, duration: 30_000)

    :ok = Interpreter.remove_on_map_change(:mob, @mob_id)

    assert StatusStorage.has_status?(:mob, @mob_id, :sc_provoke)
  end

  test "the flag is the reference's RemoveOnChangeMap set" do
    flagged =
      [
        :sc_hiding,
        :sc_trickdead,
        :sc_ankle,
        :sc_bladestop_wait,
        :sc_bladestop,
        :sc_marionette,
        :sc_marionette2,
        :sc_devotion,
        :sc_closeconfine,
        :sc_closeconfine2,
        :sc_dancing,
        :sc_stop
      ]

    unflagged = [
      :sc_splasher,
      :sc_bloodlust,
      :sc_longing,
      :sc_change,
      :sc_defence,
      :sc_avoid,
      :sc_cloaking,
      :sc_gospel,
      :sc_devoted_by
    ]

    for type <- flagged, do: assert(Registry.get_definition(type).remove_on_map_change, "#{type}")

    for type <- unflagged,
        do: refute(Registry.get_definition(type).remove_on_map_change, "#{type}")

    assert Basilica.metadata().remove_on_map_change == (GameMode.mode() == :pre_renewal)
  end
end
