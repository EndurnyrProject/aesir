defmodule Aesir.ZoneServer.Unit.Player.Handlers.NpcInteractionHandlerTest do
  @moduledoc """
  Covers the dialogs a script takes over (rAthena `bk_st`): a pause loses the
  script dialogs beneath the pausing script but not a skill-staged menu, a
  detach gives the player back the dialog beneath, a dialog beneath ending on
  its own leaves the stack, and the menu beneath still gets its answer.
  """

  use ExUnit.Case, async: true

  import Aesir.ZoneServer.Factory

  alias Aesir.Net.NpcInteract
  alias Aesir.ZoneServer.Unit.Player.Handlers.NpcInteractionHandler
  alias Aesir.ZoneServer.Unit.Player.SessionState

  setup do
    script = waiting_process()
    menu = relay(self())
    system_gid = SessionState.system_dialog_gid()

    script_lock = {script, Process.monitor(script), 0x5000_0001}
    menu_lock = {menu, Process.monitor(menu), system_gid}
    running = {self(), make_ref(), 0x5000_0002}

    state = %{
      build(:session_state)
      | interaction_lock: running,
        dialog_backups: [{script_lock, nil}, {menu_lock, nil}]
    }

    %{state: state, script: script, menu: menu, script_lock: script_lock, menu_lock: menu_lock}
  end

  test "a pause loses the script dialogs beneath, but not a skill-staged menu", context do
    %{state: state, script: script, menu: menu, menu_lock: menu_lock} = context

    assert NpcInteractionHandler.script_paused(waiting_process(), state) == state

    watch = Process.monitor(script)
    paused = NpcInteractionHandler.script_paused(self(), state)

    assert paused.dialog_backups == [{menu_lock, nil}]
    assert_receive {:DOWN, ^watch, :process, ^script, :shutdown}
    assert Process.alive?(menu)
  end

  test "detaching the running script gives the player the dialog beneath", context do
    %{state: state, script_lock: script_lock, menu_lock: menu_lock} = context

    detached = NpcInteractionHandler.detach_script(self(), state)

    assert detached.interaction_lock == script_lock
    assert detached.dialog_backups == [{menu_lock, nil}]
  end

  test "a dialog beneath that ends on its own leaves the stack", context do
    %{state: state, script_lock: {_pid, ref, _gid}, menu_lock: menu_lock} = context

    assert {:ok, %{dialog_backups: [{^menu_lock, nil}]}} =
             NpcInteractionHandler.backup_ended(ref, state)

    assert NpcInteractionHandler.backup_ended(make_ref(), state) == :error
  end

  test "a skill-staged menu beneath still gets its answer", %{state: state} do
    answer = %NpcInteract{npc_id: SessionState.system_dialog_gid(), response: {:choice, 1}}
    {:noreply, ^state} = NpcInteractionHandler.handle_interact(answer, state)

    assert_receive {:relayed, {:npc_interact, ^answer}}
  end

  describe "handle_attach_script/5" do
    setup %{state: state} do
      holder = waiting_process()
      %{state: %{state | interaction_lock: {holder, make_ref(), 0x5000_0003}}, holder: holder}
    end

    test "without force a player held by a script refuses", %{state: state} do
      from = {self(), make_ref()}

      assert {:reply, :busy, ^state} =
               NpcInteractionHandler.handle_attach_script(
                 state,
                 from,
                 waiting_process(),
                 7,
                 false
               )
    end

    test "the script already holding the player is attached already", %{
      state: state,
      holder: holder
    } do
      assert {:reply, {:ok, %{game_state: game_state}}, ^state} =
               NpcInteractionHandler.handle_attach_script(
                 state,
                 {self(), make_ref()},
                 holder,
                 7,
                 true
               )

      assert game_state == state.game_state
    end

    test "with force it waits while the holder runs, then takes over when it waits",
         %{state: state, holder: holder} do
      lock = state.interaction_lock
      script = waiting_process()
      tag = make_ref()
      state = %{state | dialog_running?: true}

      {:noreply, waiting} =
        NpcInteractionHandler.handle_attach_script(state, {self(), tag}, script, 7, true)

      refute_received {^tag, _reply}
      assert waiting.interaction_lock == lock

      attached = NpcInteractionHandler.script_paused(holder, waiting)

      assert_received {^tag, {:ok, %{connection_pid: _connection}}}
      assert {^script, _ref, 7} = attached.interaction_lock
      assert hd(attached.dialog_backups) == {lock, nil}
      assert attached.dialog_running?
    end
  end

  defp waiting_process, do: spawn(fn -> Process.sleep(:infinity) end)

  defp relay(to), do: spawn(fn -> receive do: (msg -> send(to, {:relayed, msg})) end)
end
