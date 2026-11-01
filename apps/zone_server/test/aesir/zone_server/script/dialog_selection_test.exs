defmodule Aesir.ZoneServer.Script.DialogSelectionTest do
  use ExUnit.Case, async: true

  alias Aesir.Net.NpcDialog
  alias Aesir.Net.NpcInteract
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Dsl
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @gid 0x6000_0011

  test "visible choices skip empty labels but return and persist the original logical index" do
    parent = self()
    player = %PlayerState{character_id: 1, account_id: 1, temp_vars: %{}}

    ctx = %Ctx{
      char_id: 1,
      account_id: 1,
      connection_pid: self(),
      game_state: player,
      session_pid: self(),
      source: {:item, 14527},
      npc_gid: @gid
    }

    pid = spawn(fn -> send(parent, {:selected, Dsl.select(ctx, ["A", "", " ", "C", ""])}) end)

    assert_receive {:send, _, {:npc_dialog, %NpcDialog{options: ["A", " ", "C"], npc_id: @gid}}}
    send(pid, {:npc_interact, %NpcInteract{npc_id: @gid + 1, response: {:choice, 1}}})
    send(pid, {:npc_interact, %NpcInteract{npc_id: @gid, response: {:choice, 3}}})

    assert_receive {:"$gen_call", from, {:npc, {:script_apply, {:set_temp_var, :menu, 4}}}}
    updated = %{player | temp_vars: %{"menu" => 4}}
    GenServer.reply(from, {:ok, updated})
    assert_receive {:selected, {%Ctx{game_state: ^updated, page: []}, 4}}
  end

  test "out-of-range and zero choices disconnect instead of reaching a helper branch" do
    for choice <- [0, 3] do
      owner =
        start_supervised!(
          Supervisor.child_spec({Agent, fn -> :alive end}, id: choice, restart: :temporary)
        )

      owner_ref = Process.monitor(owner)

      ctx = %Ctx{
        char_id: 1,
        account_id: 1,
        connection_pid: self(),
        game_state: %PlayerState{character_id: 1, account_id: 1},
        session_pid: owner,
        source: {:item, 14527},
        npc_gid: @gid
      }

      {pid, ref} = spawn_monitor(fn -> Dsl.select(ctx, ["A", "B"]) end)
      assert_receive {:send, _, {:npc_dialog, %NpcDialog{expect: :MENU}}}
      send(pid, {:npc_interact, %NpcInteract{npc_id: @gid, response: {:choice, choice}}})
      assert_receive {:DOWN, ^owner_ref, :process, ^owner, :normal}
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}
    end
  end
end
