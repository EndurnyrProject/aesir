defmodule Aesir.ZoneServer.Script.CtxTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  defp build_player_state(opts \\ []) do
    %PlayerState{
      character_id: Keyword.get(opts, :character_id, 42),
      account_id: Keyword.get(opts, :account_id, 7),
      character_name: "TestChar",
      map_name: "prontera",
      x: 150,
      y: 150
    }
  end

  describe "from_session/2" do
    test "builds Ctx from session map with item source" do
      pid = self()
      ps = build_player_state(character_id: 42, account_id: 7)
      session = %{game_state: ps, connection_pid: pid}

      ctx = Ctx.from_session(session, {:item, 501})

      assert %Ctx{
               char_id: 42,
               account_id: 7,
               connection_pid: ^pid,
               game_state: ^ps,
               source: {:item, 501},
               status: :ok
             } = ctx
    end

    test "builds Ctx from session map with npc source" do
      pid = self()
      ps = build_player_state(character_id: 99, account_id: 3)
      session = %{game_state: ps, connection_pid: pid}

      ctx = Ctx.from_session(session, {:npc, :prontera_guard})

      assert ctx.char_id == 99
      assert ctx.account_id == 3
      assert ctx.source == {:npc, :prontera_guard}
      assert ctx.status == :ok
    end
  end

  describe "halt/2" do
    test "ends the script by throwing the ctx with status {:error, reason}" do
      ps = build_player_state()
      ctx = Ctx.from_session(%{game_state: ps, connection_pid: self()}, {:item, 501})

      assert {:script_end, %Ctx{status: {:error, :blocked}}} =
               catch_throw(Ctx.halt(ctx, :blocked))
    end

    test "preserves all other fields" do
      ps = build_player_state(character_id: 10, account_id: 20)
      ctx = Ctx.from_session(%{game_state: ps, connection_pid: self()}, {:item, 502})

      assert {:script_end, halted} = catch_throw(Ctx.halt(ctx, :out_of_stock))
      assert halted == %{ctx | status: {:error, :out_of_stock}}
    end
  end

  describe "fail/3" do
    import ExUnit.CaptureLog

    test "returns the ctx running, recording the failure newest first" do
      ps = build_player_state()
      ctx = Ctx.from_session(%{game_state: ps, connection_pid: self()}, {:item, 501})

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
