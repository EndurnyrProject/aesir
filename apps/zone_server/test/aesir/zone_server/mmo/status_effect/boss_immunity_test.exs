defmodule Aesir.ZoneServer.Mmo.StatusEffect.BossImmunityTest do
  @moduledoc """
  A status-immune monster (boss, guardian and battlefield classes) rejects a
  status whose definition carries the BossResist `:boss` immunity, whoever its
  source, and receives every other status like any unit.
  """

  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup
  import Aesir.ZoneServer.SessionHelpers

  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage

  setup :setup_ets_tables

  defp start_mob(modes) do
    %{unit_id: unit_id} = start_mob_session(modes: modes)
    unit_id
  end

  test "a boss rejects a BossResist status from a foreign caster and stores nothing" do
    unit_id = start_mob([:boss, :status_immune])

    assert {:error, :immune} =
             Interpreter.apply_status(:mob, unit_id, :sc_stun, caster_id: 12_345)

    refute StatusStorage.has_status?(:mob, unit_id, :sc_stun)
  end

  test "a boss rejects a BossResist status it is itself the source of" do
    unit_id = start_mob([:boss, :status_immune])

    assert {:error, :immune} =
             Interpreter.apply_status(:mob, unit_id, :sc_stun,
               source_id: unit_id,
               source_type: :mob
             )
  end

  test "a status-immune monster of another class rejects it too" do
    unit_id = start_mob([:status_immune])

    assert {:error, :immune} = Interpreter.apply_status(:mob, unit_id, :sc_stun, duration: 4_500)
  end

  test "a boss receives a status without BossResist from any source" do
    unit_id = start_mob([:boss, :status_immune])

    assert :ok = Interpreter.apply_status(:mob, unit_id, :sc_increaseagi, val1: 3)
    assert StatusStorage.has_status?(:mob, unit_id, :sc_increaseagi)
  end

  test "an unavoidable application reaches a boss" do
    unit_id = start_mob([:boss, :status_immune])

    assert :ok =
             Interpreter.apply_status(:mob, unit_id, :sc_stun,
               duration: 4_500,
               no_avoid: true,
               bypass_resistance: true
             )
  end

  test "a monster that is not status-immune receives a BossResist status" do
    unit_id = start_mob([])

    assert :ok =
             Interpreter.apply_status(:mob, unit_id, :sc_stun,
               caster_id: 12_345,
               resistance_roll: fn _ -> true end
             )

    assert StatusStorage.has_status?(:mob, unit_id, :sc_stun)
  end
end
