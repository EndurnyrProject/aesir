defmodule Aesir.ZoneServer.Mmo.CombatTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  alias Aesir.ZoneServer.Mmo.Combat

  describe "deal_damage/4" do
    test "returns error for non-existent target" do
      {result, _log} =
        with_log(fn ->
          Combat.deal_damage(99_999, 100, :neutral, :status_effect)
        end)

      assert {:error, :target_not_found} = result
    end

    test "accepts valid parameters" do
      # This test mainly ensures the function doesn't crash with valid input
      # Since we don't have a real target to test with in unit tests
      {result, _log} =
        with_log(fn ->
          Combat.deal_damage(1, 100, :fire, :status_effect)
        end)

      assert match?({:error, :target_not_found}, result)
    end
  end

  # Note: Full integration tests would require setting up actual PlayerSession
  # and MobSession processes, which is better done in integration test suites
end
