defmodule Aesir.ZoneServer.Unit.Player.Handlers.PacketHandlerNpcTest do
  use ExUnit.Case, async: false

  alias Aesir.Net.NameRequest
  alias Aesir.Net.NameResponse
  alias Aesir.Net.NpcDialog
  alias Aesir.Net.NpcInteract
  alias Aesir.Net.NpcTalk
  alias Aesir.ZoneServer.Npc.Placement
  alias Aesir.ZoneServer.Npc.Registry
  alias Aesir.ZoneServer.Unit.Player.Handlers.PacketHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  defmodule TalkNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 150, y: 150, dir: 0, sprite: 58, name: "Talker"}]

    @impl true
    def on_talk(ctx) do
      ctx = ctx |> mes("hi") |> next()
      {ctx, choice} = select(ctx, ["A", "B"])
      ctx |> mes("you picked #{choice}") |> close()
    end
  end

  setup do
    Registry.reload([TalkNpc])
    gid = Registry.entity_id(%Placement{map: "prontera", x: 150, y: 150, sprite: 58})
    {:ok, gid: gid}
  end

  defp state do
    %{
      game_state: %PlayerState{character_id: 1, account_id: 100},
      connection_pid: self(),
      interaction_lock: nil
    }
  end

  test "NpcTalk for a registered NPC spawns a monitored interaction and sets the lock", %{
    gid: gid
  } do
    {:noreply, new_state} = PacketHandler.handle_message(%NpcTalk{npc_id: gid}, state())

    assert {pid, ref, ^gid} = new_state.interaction_lock
    assert is_pid(pid)
    assert is_reference(ref)
    assert Process.alive?(pid)

    assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :NEXT, text: "hi"}}}
  end

  test "a second NpcTalk while locked is ignored", %{gid: gid} do
    {:noreply, locked} = PacketHandler.handle_message(%NpcTalk{npc_id: gid}, state())
    {pid, _ref, _gid} = locked.interaction_lock

    {:noreply, again} = PacketHandler.handle_message(%NpcTalk{npc_id: gid}, locked)

    assert again.interaction_lock == locked.interaction_lock
    assert {^pid, _, _} = again.interaction_lock
  end

  test "NpcTalk for an unregistered gid is ignored (no lock)" do
    {:noreply, new_state} = PacketHandler.handle_message(%NpcTalk{npc_id: 0xDEAD}, state())

    assert new_state.interaction_lock == nil
  end

  test "NpcInteract is forwarded to the locked interaction and drives it to close", %{gid: gid} do
    {:noreply, locked} = PacketHandler.handle_message(%NpcTalk{npc_id: gid}, state())
    assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :NEXT}}}

    {:noreply, ^locked} =
      PacketHandler.handle_message(
        %NpcInteract{npc_id: gid, response: {:continue, true}},
        locked
      )

    assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :MENU, options: ["A", "B"]}}}

    {:noreply, ^locked} =
      PacketHandler.handle_message(%NpcInteract{npc_id: gid, response: {:choice, 1}}, locked)

    assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :CLOSE, text: "you picked 1"}}}
  end

  test "NpcInteract with no lock is dropped" do
    {:noreply, new_state} =
      PacketHandler.handle_message(
        %NpcInteract{npc_id: 1, response: {:continue, true}},
        state()
      )

    assert new_state.interaction_lock == nil
  end

  test "NpcInteract whose npc_id does not match the lock gid is dropped", %{gid: gid} do
    {:noreply, locked} = PacketHandler.handle_message(%NpcTalk{npc_id: gid}, state())
    {pid, _ref, _gid} = locked.interaction_lock
    assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :NEXT}}}

    {:noreply, ^locked} =
      PacketHandler.handle_message(
        %NpcInteract{npc_id: 0xBEEF, response: {:continue, true}},
        locked
      )

    refute_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :MENU}}}, 100
    assert Process.alive?(pid)
  end

  test "a cancel routed while blocked on NEXT ends the interaction promptly", %{gid: gid} do
    {:noreply, locked} = PacketHandler.handle_message(%NpcTalk{npc_id: gid}, state())
    {pid, _ref, _gid} = locked.interaction_lock
    ref = Process.monitor(pid)
    assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :NEXT}}}

    {:noreply, ^locked} =
      PacketHandler.handle_message(%NpcInteract{npc_id: gid, response: {:cancel, true}}, locked)

    # The interaction exits promptly (not after the idle timeout); in the real
    # session this :DOWN clears the lock.
    assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 500
  end

  test "the interaction's :DOWN clears the lock and keeps the session alive", %{gid: gid} do
    ref = make_ref()
    interaction = spawn(fn -> :ok end)

    locked = %{
      game_state: %PlayerState{character_id: 1, account_id: 100},
      connection_pid: self(),
      connection_monitor_ref: make_ref(),
      interaction_lock: {interaction, ref, gid}
    }

    assert {:noreply, cleared} =
             PlayerSession.handle_info(
               {:DOWN, ref, :process, interaction, :normal},
               locked
             )

    assert cleared.interaction_lock == nil
  end

  test "a :DOWN that is not the interaction lock ref still stops the session" do
    conn_ref = make_ref()

    state = %{
      game_state: %PlayerState{character_id: 1, account_id: 100},
      connection_pid: self(),
      connection_monitor_ref: conn_ref,
      interaction_lock: nil
    }

    assert {:stop, :normal, ^state} =
             PlayerSession.handle_info({:DOWN, conn_ref, :process, self(), :killed}, state)
  end

  test "NameRequest for an in-view NPC gid replies with the placement name", %{gid: gid} do
    s = %{
      game_state: %PlayerState{
        character_id: 1,
        account_id: 100,
        visible_players: MapSet.new(),
        visible_mobs: MapSet.new()
      },
      connection_pid: self()
    }

    {:noreply, ^s} = PacketHandler.handle_message(%NameRequest{entity_id: gid}, s)

    assert_receive {:send, _ch,
                    {:name_response,
                     %NameResponse{
                       gid: ^gid,
                       name: "Talker",
                       party_name: "",
                       guild_name: "",
                       position_name: ""
                     }}}
  end
end
