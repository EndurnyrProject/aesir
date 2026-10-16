defmodule Aesir.ZoneServer.Mmo.StatusEffect.StatusDelayTest do
  @moduledoc """
  A delayed status start (`start_delay`, status_change_start's delay): the
  defense runs at once, the status starts at the end of the delay if its target
  still lives, and renewal shortens the duration by the delay.
  """

  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup
  import Aesir.ZoneServer.SessionHelpers

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables

  defp mob do
    %{unit_id: unit_id} = start_mob_session([])
    unit_id
  end

  defp eventually(fun, attempts \\ 50) do
    cond do
      fun.() -> true
      attempts == 0 -> false
      true -> Process.sleep(10) && eventually(fun, attempts - 1)
    end
  end

  test "reports success at once and starts the status after the delay" do
    unit_id = mob()

    assert :ok =
             Interpreter.apply_status(:mob, unit_id, :sc_stun,
               duration: 4_500,
               bypass_resistance: true,
               start_delay: 100
             )

    refute StatusStorage.has_status?(:mob, unit_id, :sc_stun)
    assert eventually(fn -> StatusStorage.has_status?(:mob, unit_id, :sc_stun) end)

    entry = StatusStorage.get_status(:mob, unit_id, :sc_stun)
    expected = if GameMode.mode() == :renewal, do: 4_400, else: 4_500
    assert entry.expires_at - entry.started_at == expected
  end

  test "a target that died during the delay gets nothing" do
    unit_id = mob()

    assert :ok =
             Interpreter.apply_status(:mob, unit_id, :sc_stun,
               duration: 4_500,
               bypass_resistance: true,
               start_delay: 50
             )

    {:ok, {_module, state, _pid}} = UnitRegistry.get_unit(:mob, unit_id)
    UnitRegistry.update_unit_state(:mob, unit_id, %{state | is_dead: true, hp: 0})

    Process.sleep(150)
    refute StatusStorage.has_status?(:mob, unit_id, :sc_stun)
  end

  test "a target that left the world during the delay gets nothing" do
    unit_id = mob()

    assert :ok =
             Interpreter.apply_status(:mob, unit_id, :sc_stun,
               duration: 4_500,
               bypass_resistance: true,
               start_delay: 50
             )

    UnitRegistry.unregister_unit(:mob, unit_id)

    Process.sleep(150)
    refute StatusStorage.has_status?(:mob, unit_id, :sc_stun)
  end

  test "a defense that resists it starts nothing and says so at once" do
    unit_id = mob()

    assert {:error, :resisted} =
             Interpreter.apply_status(:mob, unit_id, :sc_stun,
               duration: 4_500,
               success_rate: 50,
               resistance_roll: fn _rate -> false end,
               start_delay: 50
             )
  end

  test "Bleeding starts at once despite a delay" do
    unit_id = mob()

    assert :ok =
             Interpreter.apply_status(:mob, unit_id, :sc_bleeding,
               duration: 10_000,
               bypass_resistance: true,
               start_delay: 1_000
             )

    assert StatusStorage.has_status?(:mob, unit_id, :sc_bleeding)
  end
end
