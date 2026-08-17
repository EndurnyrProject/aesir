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
      partner_id: Keyword.get(opts, :partner_id, 0),
      cart_type: Keyword.get(opts, :cart_type, 0),
      party_id: Keyword.get(opts, :party_id, 0),
      guild_id: Keyword.get(opts, :guild_id, 0)
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

  describe "checkcart/1" do
    test "returns 1 when a cart is mounted, else 0" do
      assert Dsl.checkcart(ctx(cart_type: 1)) == 1
      assert Dsl.checkcart(ctx(cart_type: 3)) == 1
      assert Dsl.checkcart(ctx()) == 0
    end

    test "raises on a detached ctx" do
      assert_raise ArgumentError, fn -> Dsl.checkcart(%{ctx() | game_state: nil}) end
    end
  end

  describe "getcharid/2" do
    test "type 0 is the char id, 3 the account id" do
      assert Dsl.getcharid(ctx(), 0) == 1
      assert Dsl.getcharid(ctx(), 3) == 100
    end

    test "type 1 is the party id, 0 when partyless" do
      assert Dsl.getcharid(ctx(party_id: 77), 1) == 77
      assert Dsl.getcharid(ctx(), 1) == 0
    end

    test "type 2 is the guild id, 0 when guildless" do
      assert Dsl.getcharid(ctx(guild_id: 55), 2) == 55
      assert Dsl.getcharid(ctx(), 2) == 0
      assert Dsl.getcharid(ctx(guild_id: nil), 2) == 0
    end

    test "unknown types return 0" do
      assert Dsl.getcharid(ctx(), 9) == 0
    end

    test "raises on a detached ctx" do
      assert_raise ArgumentError, fn -> Dsl.getcharid(%{ctx() | game_state: nil}, 0) end
    end
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

  describe "gettime/2" do
    test "reads the local-time calendar components by DT_* type" do
      now = NaiveDateTime.local_now()

      assert Dsl.gettime(ctx(), 3) == now.hour
      assert Dsl.gettime(ctx(), 5) == now.day
      assert Dsl.gettime(ctx(), 6) == now.month
      assert Dsl.gettime(ctx(), 7) == now.year
    end

    test "day of week is 0=Sunday..6=Saturday (rAthena tm_wday)" do
      dow = Dsl.gettime(ctx(), 4)

      assert dow in 0..6
      assert dow == Date.day_of_week(NaiveDateTime.local_now(), :sunday) - 1
    end

    test "day of year is 0-based (Jan 1 is 0)" do
      doy = Dsl.gettime(ctx(), 8)

      assert doy in 0..365
      assert doy == Date.day_of_year(NaiveDateTime.local_now()) - 1
    end

    test "an out-of-range type returns -1" do
      assert Dsl.gettime(ctx(), 0) == -1
      assert Dsl.gettime(ctx(), 99) == -1
    end

    test "ignores the ctx (works detached)" do
      assert is_integer(Dsl.gettime(%{ctx() | game_state: nil}, 3))
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

    test "soundeffectall/3 is a no-op with no origin unit (no player, no npc_gid)" do
      c = %{ctx() | char_id: nil, npc_gid: nil}
      assert Dsl.soundeffectall(c, "election.wav", 0) == c
    end

    test "both are no-ops on an errored ctx" do
      c = Ctx.halt(ctx(), :boom)
      assert Dsl.cutin(c, "img", 1) == c
      assert Dsl.soundeffect(c, "s.wav", 0) == c
      assert Dsl.soundeffectall(c, "s.wav", 0) == c
    end
  end
end
