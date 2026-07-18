defmodule Aesir.ZoneServer.Mmo.StatusEffect.ConcealedTest do
  @moduledoc """
  `Interpreter.concealed?/2` reads the `:conceals` property carried by Hiding
  and Cloaking. `targetable?/2` is untouched and must keep returning what it
  always returned, since it has callers outside mob AI.
  """

  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.StatusEffect.Helpers
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.UnitRegistry

  defmodule FakeEntity do
    @moduledoc false
    def get_entity_info(_state), do: %{stats: %{}, boss_flag: false}
  end

  setup :setup_ets_tables

  test "a unit with sc_hiding is concealed" do
    unit_id = 1
    StatusStorage.apply_status(:player, unit_id, :sc_hiding, duration: 60_000)

    assert Interpreter.concealed?(:player, unit_id)
    assert Interpreter.targetable?(:player, unit_id)
  end

  test "a unit with sc_cloaking is concealed" do
    unit_id = 2
    StatusStorage.apply_status(:player, unit_id, :sc_cloaking, val1: 5, duration: 60_000)

    assert Interpreter.concealed?(:player, unit_id)
    assert Interpreter.targetable?(:player, unit_id)
  end

  test "a unit with no statuses is not concealed" do
    unit_id = 3

    refute Interpreter.concealed?(:player, unit_id)
    assert Interpreter.targetable?(:player, unit_id)
  end

  test "a unit with an unrelated status is not concealed" do
    unit_id = 4
    StatusStorage.apply_status(:player, unit_id, :sc_provoke, duration: 60_000)

    refute Interpreter.concealed?(:player, unit_id)
    assert Interpreter.targetable?(:player, unit_id)
  end

  test "removing the hiding status via Helpers.remove_statuses/2 clears concealment" do
    unit_id = 5
    UnitRegistry.register_unit(:player, unit_id, FakeEntity, %{})
    StatusStorage.apply_status(:player, unit_id, :sc_hiding, duration: 60_000)
    assert Interpreter.concealed?(:player, unit_id)

    Helpers.remove_statuses({:player, unit_id}, [:sc_hiding, :sc_cloaking])

    refute Interpreter.concealed?(:player, unit_id)
  end
end
