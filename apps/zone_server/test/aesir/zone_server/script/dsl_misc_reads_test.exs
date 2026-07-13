defmodule Aesir.ZoneServer.Script.DslMiscReadsTest do
  @moduledoc """
  Covers the renewal/VIP/marriage/time reads (`checkre/2`, `vip_status/2`,
  `getpartnerid/1`, `gettimetick/2`) and the client-packet effect ops
  (`cutin/3`, `soundeffect/3`) short-circuiting on a detached or errored ctx.
  """

  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Dsl
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  defp game_state(opts) do
    %PlayerState{
      character_id: 1,
      account_id: 100,
      partner_id: Keyword.get(opts, :partner_id, 0)
    }
  end

  defp ctx(opts \\ []) do
    %Ctx{
      char_id: 1,
      account_id: 100,
      connection_pid: self(),
      session_pid: self(),
      game_state: game_state(opts),
      source: {:npc, :test_npc}
    }
  end

  describe "checkre/2 (Aesir is renewal-only)" do
    test "every renewal feature flag (0..5) is on" do
      for type <- 0..5, do: assert(Dsl.checkre(ctx(), type) == 1)
    end

    test "an unknown type returns 0, matching rAthena" do
      assert Dsl.checkre(ctx(), 6) == 0
      assert Dsl.checkre(ctx(), -1) == 0
    end

    test "ignores the ctx (works detached)" do
      assert Dsl.checkre(%{ctx() | game_state: nil}, 0) == 1
    end
  end

  describe "vip_status/2 (Aesir has no VIP tier)" do
    test "always returns 0 for every type" do
      for type <- 1..3, do: assert(Dsl.vip_status(ctx(), type) == 0)
    end

    test "ignores the ctx (works detached)" do
      assert Dsl.vip_status(%{ctx() | game_state: nil}, 1) == 0
    end
  end

  describe "gettimetick/2" do
    test "type 2 is the Unix epoch timestamp in seconds" do
      assert_in_delta Dsl.gettimetick(ctx(), 2), System.os_time(:second), 2
    end

    test "type 1 is the seconds elapsed since local midnight" do
      %NaiveDateTime{hour: hour, minute: minute, second: second} = NaiveDateTime.local_now()
      expected = hour * 3600 + minute * 60 + second

      tick = Dsl.gettimetick(ctx(), 1)

      assert tick in 0..86_399
      assert abs(tick - expected) <= 2 or abs(tick - expected) >= 86_397
    end

    test "type 0 (and unknown types) is a non-negative monotonic millisecond tick" do
      first = Dsl.gettimetick(ctx(), 0)
      second = Dsl.gettimetick(ctx(), 7)

      assert first >= 0
      assert second >= first
    end

    test "ignores the ctx (works detached)" do
      assert is_integer(Dsl.gettimetick(%{ctx() | game_state: nil}, 2))
    end
  end

  describe "getpartnerid/1" do
    test "reads game_state.partner_id" do
      assert Dsl.getpartnerid(ctx(partner_id: 4242)) == 4242
    end

    test "is 0 for an unmarried player" do
      assert Dsl.getpartnerid(ctx()) == 0
    end

    test "raises on a detached ctx (no player state)" do
      assert_raise ArgumentError, fn -> Dsl.getpartnerid(%{ctx() | game_state: nil}) end
    end
  end

  describe "client-packet effects short-circuit without a player" do
    test "cutin/3 returns the ctx unchanged when there is no char to send to" do
      c = %{ctx() | char_id: nil}
      assert Dsl.cutin(c, "kafra_01", 2) == c
    end

    test "soundeffect/3 returns the ctx unchanged when there is no char to send to" do
      c = %{ctx() | char_id: nil}
      assert Dsl.soundeffect(c, "bragis_poem.wav", 0) == c
    end

    test "both are no-ops on an errored ctx" do
      c = Ctx.halt(ctx(), :boom)
      assert Dsl.cutin(c, "img", 1) == c
      assert Dsl.soundeffect(c, "s.wav", 0) == c
    end
  end
end
