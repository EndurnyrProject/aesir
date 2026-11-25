defmodule Aesir.ZoneServer.Integration.NpcAttachIntegrationTest do
  @moduledoc """
  End-to-end coverage of rAthena's `attachrid` between two real player
  sessions: without `force` a player held by a script refuses; with it the
  script takes over the dialog holding the player (`script_attach_state`), and
  the player it was attached to before is let go (`script_detach_rid`).
  """

  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Net.NpcDialog
  alias Aesir.Net.NpcInteract
  alias Aesir.Net.NpcTalk
  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry
  alias Aesir.ZoneServer.Unit.Player.PlayerSession

  @probe :npc_attach_integration_probe

  defmodule CallerNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 140, y: 140, sprite: 58, name: "Caller"}]

    @impl true
    def on_talk(ctx) do
      send(:npc_attach_integration_probe, {:caller, self()})

      receive do
        {:attach, account_id, force} ->
          {ctx, attached} = attachrid(ctx, account_id, force)
          send(:npc_attach_integration_probe, {:attached, attached})
          if attached == 1, do: talk_to_target(ctx), else: ctx
      end
    end

    defp talk_to_target(ctx) do
      ctx = ctx |> mes("Over here.") |> next()
      send(:npc_attach_integration_probe, {:answered, ctx.char_id})
      ctx
    end
  end

  defmodule BellNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 146, y: 140, sprite: 58, name: "Bell"}]

    @impl true
    def on_talk(ctx) do
      ctx = ctx |> mes("Ding.") |> next()
      send(:npc_attach_integration_probe, :bell_resumed)
      ctx
    end
  end

  setup do
    Aesir.TestProbe.register!(@probe)
    on_exit(fn -> :persistent_term.erase(NpcRegistry) end)
    NpcRegistry.reload([CallerNpc, BellNpc])

    caller = player("Summoner", {141, 140})
    target = player("Summoned", {145, 140})
    bell = gid_for(BellNpc)

    simulate_incoming_message(target.pid, %NpcTalk{npc_id: bell})
    assert Enum.any?(collect_packets_of_type(NpcDialog), &match?(%{npc_id: ^bell}, &1))

    simulate_incoming_message(caller.pid, %NpcTalk{npc_id: gid_for(CallerNpc)})
    assert_receive {:caller, script}, 1_000

    %{caller: caller, target: target, bell: bell, script: script}
  end

  test "without force a player held by a script refuses", context do
    send(context.script, {:attach, context.target.character.account_id, 0})

    assert_receive {:attached, 0}, 1_000
    bell = context.bell
    assert {_bell_pid, _ref, ^bell} = PlayerSession.get_state(context.target.pid).interaction_lock

    simulate_incoming_message(context.target.pid, answer(bell))
    assert_receive :bell_resumed, 1_000
  end

  test "with force the script takes over the target's dialog and lets the caller go", context do
    %{caller: caller, target: target, script: script, bell: bell} = context
    {bell_pid, _ref, ^bell} = PlayerSession.get_state(target.pid).interaction_lock
    bell_ref = Process.monitor(bell_pid)

    send(script, {:attach, target.character.account_id, 1})

    assert_receive {:attached, 1}, 1_000
    caller_gid = gid_for(CallerNpc)

    assert Enum.any?(
             collect_packets_of_type(NpcDialog),
             &match?(%{npc_id: ^caller_gid, text: "Over here."}, &1)
           )

    assert_eventually(fn -> PlayerSession.get_state(caller.pid).interaction_lock == nil end)
    assert {^script, _ref, ^caller_gid} = PlayerSession.get_state(target.pid).interaction_lock
    assert_receive {:DOWN, ^bell_ref, :process, ^bell_pid, _reason}, 1_000

    simulate_incoming_message(target.pid, answer(caller_gid))
    target_char = target.character.id
    assert_receive {:answered, ^target_char}, 1_000
    refute_received :bell_resumed
  end

  test "two scripts forcing their way onto each other's players both attach", context do
    %{caller: caller, target: target, script: script, bell: bell} = context
    simulate_incoming_message(target.pid, answer(bell))
    assert_receive :bell_resumed, 1_000
    assert_eventually(fn -> PlayerSession.get_state(target.pid).interaction_lock == nil end)

    simulate_incoming_message(target.pid, %NpcTalk{npc_id: gid_for(CallerNpc)})
    assert_receive {:caller, other_script}, 1_000

    send(script, {:attach, target.character.account_id, 1})
    send(other_script, {:attach, caller.character.account_id, 1})

    assert_receive {:attached, 1}, 1_000
    assert_receive {:attached, 1}, 1_000
  end

  defp player(name, position) do
    session =
      start_player_session(
        id: System.unique_integer([:positive]),
        account_id: System.unique_integer([:positive]),
        name: name,
        position: position
      )

    on_exit(fn -> end_player_session(session) end)
    session
  end

  defp answer(gid), do: %NpcInteract{npc_id: gid, response: {:continue, true}}

  defp gid_for(module) do
    {^module, placement} = Enum.find(NpcRegistry.entries(), fn {mod, _} -> mod == module end)
    NpcRegistry.entity_id(placement)
  end
end
