defmodule Aesir.ZoneServer.Mmo.StatusEffect.HelpersVitalsTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.StatusEffect.Helpers

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})
    :ok
  end

  test "non-player and missing player targets are harmless" do
    assert :ok = Helpers.set_vitals({:mob, 1}, hp: :max)
    assert :ok = Helpers.set_vitals({:player, 999_999}, hp: :max)
  end
end
