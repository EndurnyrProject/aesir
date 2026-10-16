defmodule Aesir.ZoneServer.Unit.HitStopTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Unit.HitStop

  describe "plan/2" do
    test "finishes the step when at most half of it is left" do
      timer = make_ref()

      assert HitStop.plan({1_150, 150, timer}, 1_075) == :finish_step
      assert HitStop.plan({1_151, 150, timer}, 1_075) == :stay
      assert HitStop.plan({1_141, 141, timer}, 1_071) == :finish_step
      assert HitStop.plan({1_142, 141, timer}, 1_071) == :stay
    end

    test "stays when no step is known" do
      assert HitStop.plan(nil, 1_000) == :stay
    end
  end

  test "a scheduled step's timer can be cancelled before it fires" do
    step = HitStop.schedule(:step_due, 20)

    assert :ok = HitStop.cancel(step)
    refute_receive :step_due, 60
  end
end
