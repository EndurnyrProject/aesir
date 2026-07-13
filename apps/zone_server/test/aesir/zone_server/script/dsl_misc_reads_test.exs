defmodule Aesir.ZoneServer.Script.DslMiscReadsTest do
  @moduledoc """
  Covers the renewal/VIP/marriage reads (`checkre/2`, `vip_status/2`,
  `getpartnerid/1`) and the client-packet effect ops (`cutin/3`,
  `soundeffect/3`) short-circuiting on a detached or errored ctx.
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
