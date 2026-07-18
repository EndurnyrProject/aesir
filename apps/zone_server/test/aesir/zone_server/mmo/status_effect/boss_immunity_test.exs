defmodule Aesir.ZoneServer.Mmo.StatusEffect.BossImmunityTest do
  @moduledoc """
  Boss monsters reject every externally-applied status while still accepting
  their own self-buffs. The origin of a status is resolved through
  `StatusEntry.resolve_source_type/4`, so a foreign caster is rejected even when
  its id coincides with the boss' instance id.
  """

  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup
  import Aesir.ZoneServer.SessionHelpers

  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables

  defp start_mob(opts) do
    %{unit_id: unit_id, mob_state: mob_state, pid: pid} = start_mob_session(opts)
    UnitRegistry.register_unit(:mob, unit_id, MobState, mob_state, pid)
    unit_id
  end

  test "a foreign caster id with no source_type is rejected on a boss and stores nothing" do
    unit_id = start_mob(modes: [:boss])

    assert {:error, :boss_immune} =
             Interpreter.apply_status(:mob, unit_id, :sc_stun, caster_id: 12_345)

    refute StatusStorage.has_status?(:mob, unit_id, :sc_stun)
  end

  test "a foreign caster of the boss' own unit type is rejected" do
    unit_id = start_mob(modes: [:boss])

    assert {:error, :boss_immune} =
             Interpreter.apply_status(:mob, unit_id, :sc_stun,
               source_id: unit_id + 1,
               source_type: :mob
             )

    refute StatusStorage.has_status?(:mob, unit_id, :sc_stun)
  end

  test "declared :boss immunity still short-circuits ahead of the gate" do
    unit_id = start_mob(modes: [:boss])

    assert {:error, :immune} =
             Interpreter.apply_status(:mob, unit_id, :sc_freeze, caster_id: 12_345)

    refute StatusStorage.has_status?(:mob, unit_id, :sc_freeze)
  end

  test "the same application against a non-boss mob succeeds" do
    unit_id = start_mob(modes: [])

    assert :ok =
             Interpreter.apply_status(:mob, unit_id, :sc_stun,
               caster_id: 12_345,
               resistance_roll: fn _ -> true end
             )

    assert StatusStorage.has_status?(:mob, unit_id, :sc_stun)
  end

  test "a self-originated buff is applied to a boss" do
    unit_id = start_mob(modes: [:boss])

    assert :ok =
             Interpreter.apply_status(:mob, unit_id, :sc_increaseagi,
               val1: 3,
               caster_id: unit_id,
               source_id: unit_id
             )

    assert StatusStorage.has_status?(:mob, unit_id, :sc_increaseagi)
  end

  test "a caster id colliding with the boss instance id is still rejected when typed :player" do
    unit_id = start_mob(modes: [:boss])

    assert {:error, :boss_immune} =
             Interpreter.apply_status(:mob, unit_id, :sc_stun,
               source_id: unit_id,
               source_type: :player
             )

    refute StatusStorage.has_status?(:mob, unit_id, :sc_stun)
  end

  test "a status carrying no caster identity at all is rejected on a boss" do
    unit_id = start_mob(modes: [:boss])

    assert {:error, :boss_immune} =
             Interpreter.apply_status(:mob, unit_id, :sc_increaseagi, val1: 3)

    refute StatusStorage.has_status?(:mob, unit_id, :sc_increaseagi)
  end

  test "an offensive skill applying crowd control without a caster is rejected on a boss" do
    unit_id = start_mob(modes: [:boss])

    assert {:error, :boss_immune} =
             Interpreter.apply_status(:mob, unit_id, :sc_stun, duration: 4_500)

    refute StatusStorage.has_status?(:mob, unit_id, :sc_stun)
  end
end
