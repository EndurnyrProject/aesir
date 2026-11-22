defmodule Aesir.ZoneServer.Script.CtxTest do
  use ExUnit.Case, async: true

  import Aesir.ZoneServer.Factory

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Unit.Player.SessionState

  describe "from_session/2" do
    test "carries the owning session for an inline item script" do
      pid = self()
      player = build(:player_state, character_id: 42, account_id: 7)
      session = %SessionState{game_state: player, connection_pid: pid}

      assert %Ctx{
               char_id: 42,
               account_id: 7,
               connection_pid: ^pid,
               game_state: ^player,
               session_state: ^session,
               source: {:item, 501},
               status: :ok
             } = Ctx.from_session(session, {:item, 501})
    end

    test "NPC scripts receive the player snapshot but no inline session authority" do
      pid = self()
      player = build(:player_state, character_id: 99, account_id: 3)
      session = %SessionState{game_state: player, connection_pid: pid}

      assert %Ctx{
               char_id: 99,
               account_id: 3,
               connection_pid: ^pid,
               game_state: ^player,
               session_state: nil,
               source: {:npc, :prontera_guard},
               status: :ok
             } = Ctx.from_session(session, {:npc, :prontera_guard})
    end
  end

  test "halt/2 throws the error status while preserving the rest of the context" do
    ctx = build(:script_ctx, page: ["before"], vars: %{count: 2})

    assert {:script_end, halted} = catch_throw(Ctx.halt(ctx, :out_of_stock))
    assert halted == %{ctx | status: {:error, :out_of_stock}}
  end

  describe "fail/3" do
    import ExUnit.CaptureLog

    test "returns the ctx running, recording the failure newest first" do
      ctx = build(:script_ctx, source: {:item, 501})

      log =
        capture_log(fn ->
          failed = ctx |> Ctx.fail(:getitem, :inventory_full) |> Ctx.fail(:warp, :map_not_found)

          assert failed.status == :ok
          assert failed.failures == [{:warp, :map_not_found}, {:getitem, :inventory_full}]
          assert %{failed | failures: []} == ctx
        end)

      assert log =~ "script command getitem returned failure: :inventory_full"
    end
  end
end
