defmodule Aesir.ZoneServer.Mmo.StatusEffect.RemovalTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.Skill.Unit
  alias Aesir.ZoneServer.Mmo.StatusEffect.DevotionMirror
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage

  setup :set_mimic_private
  setup :setup_ets_tables

  setup do
    Mimic.copy(DevotionMirror)
    :ok
  end

  @mob_id 9_801
  @player_id 9_802

  test "a removed unit ends each status through its end logic, even once gone from the registry" do
    test_pid = self()
    stub(Unit, :destroy_async, fn group_id -> send(test_pid, {:destroyed, group_id}) end)
    :ok = StatusStorage.apply_status(:mob, @mob_id, :sc_dancing, val1: 1, val2: 77)
    :ok = StatusStorage.apply_status(:mob, @mob_id, :sc_blessing, val1: 5, duration: 60_000)

    :ok = Interpreter.end_removed_unit_statuses(:mob, @mob_id)

    assert_received {:destroyed, 77}
    assert StatusStorage.get_unit_statuses(:mob, @mob_id) == []
  end

  test "an infinite Endure is dropped without its end logic" do
    reject(&DevotionMirror.ended/2)
    :ok = StatusStorage.apply_status(:player, @player_id, :sc_endure, val1: 10, val4: 1)

    :ok = Interpreter.end_removed_unit_statuses(:player, @player_id)

    refute StatusStorage.has_status?(:player, @player_id, :sc_endure)
  end

  test "a Berserk holder gone from the registry still drops its Endure rider" do
    :ok =
      StatusStorage.apply_status(:player, @player_id, :sc_berserk,
        val1: 1,
        duration: 60_000,
        state: %{penalty_armed: true}
      )

    :ok = StatusStorage.apply_status(:player, @player_id, :sc_endure, val1: 10, val4: 1)

    :ok = Interpreter.end_removed_unit_statuses(:player, @player_id)

    assert StatusStorage.get_unit_statuses(:player, @player_id) == []
  end

  test "a status ended on a holder gone from the registry still runs its end logic" do
    :ok = StatusStorage.apply_status(:player, @player_id, :sc_berserk, val1: 1, duration: 60_000)
    :ok = StatusStorage.apply_status(:player, @player_id, :sc_endure, val1: 10, val4: 1)

    :ok = Interpreter.remove_status(:player, @player_id, :sc_berserk)

    assert StatusStorage.get_unit_statuses(:player, @player_id) == []
  end

  test "the unit's status counters go with it" do
    :ok = StatusStorage.put_endure_tick(:mob, @mob_id, 5_000)

    :ok = Interpreter.end_removed_unit_statuses(:mob, @mob_id)

    assert StatusStorage.endure_tick(:mob, @mob_id) == nil
  end
end
