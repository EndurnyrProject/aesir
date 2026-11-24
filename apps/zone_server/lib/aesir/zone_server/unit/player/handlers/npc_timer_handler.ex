defmodule Aesir.ZoneServer.Unit.Player.Handlers.NpcTimerHandler do
  @moduledoc """
  The player's NPC timer slot: rAthena's `sd->npc_timer_id`, the one timer an
  NPC can attach to a player (`initnpctimer`/`startnpctimer` with the attach
  flag, see `Npc.Session`).

  A player holds at most one slot across every NPC. `start/4` arms it at the
  first `OnTimer<ms>` label of the NPC due after the NPC's stored timer value,
  and is a no-op while a slot is armed (`npc_timerevent_start`). `stop/1`
  cancels whatever slot is armed (`npc_timerevent_stop`). When a label fires
  (`fire/2`, `npc_timerevent`) the next label is armed first, then the label
  runs attached to this player at once, never queued behind an open dialog:
  it takes the dialog lock when the player is free and otherwise runs beside
  the open dialog. A slot whose NPC session has since been replaced (a script
  reload) is dropped, as the reference's NPC unload deletes it.

  On logout `quit/1` (`npc_timerevent_quit`) drops the slot and runs the NPC's
  `OnTimerQuit` label attached to this player, if it declares one.
  """

  alias Aesir.ZoneServer.Npc.Events, as: NpcEvents
  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry
  alias Aesir.ZoneServer.Npc.Session, as: NpcSession
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Unit.Player.SessionState

  @quit_label "OnTimerQuit"

  @typedoc """
  An armed slot: the fire `ref`, its `Process.send_after/3` `timer`, the NPC
  `gid` and the session pid it was started from, and the labels still to fire,
  the armed one first.
  """
  @type slot :: %{
          ref: reference(),
          timer: reference(),
          gid: non_neg_integer(),
          npc_pid: pid() | nil,
          pending: [NpcSession.timer_entry(), ...]
        }

  @doc """
  Arms the slot for `gid` from the NPC's stored timer value `from_ms`, unless
  a slot is already armed or no label is due after `from_ms`.
  """
  @spec start(SessionState.t(), non_neg_integer(), integer(), pid() | nil) :: SessionState.t()
  def start(%{npc_timer: %{}} = state, _gid, _from_ms, _npc_pid), do: state

  def start(state, gid, from_ms, npc_pid) do
    case Enum.filter(NpcSession.schedule(gid), fn {due_ms, _label} -> due_ms > from_ms end) do
      [] -> state
      [{due_ms, _label} | _rest] = pending -> arm(state, gid, npc_pid, pending, due_ms - from_ms)
    end
  end

  @doc "Cancels the armed slot, whichever NPC it belongs to."
  @spec stop(SessionState.t()) :: SessionState.t()
  def stop(%{npc_timer: %{timer: timer}} = state) do
    Process.cancel_timer(timer)
    %{state | npc_timer: nil}
  end

  def stop(state), do: state

  @doc """
  Fires the armed label when `ref` is the armed slot's: arms the next label,
  then runs this one attached to the player. A stale `ref` is ignored.
  """
  @spec fire(SessionState.t(), reference()) :: SessionState.t()
  def fire(%{npc_timer: %{ref: ref} = slot} = state, ref) do
    %{gid: gid, npc_pid: npc_pid, pending: [{due_ms, label} | rest]} = slot

    state =
      case rest do
        [] -> %{state | npc_timer: nil}
        [{next_ms, _label} | _more] -> arm(state, gid, npc_pid, rest, next_ms - due_ms)
      end

    if NpcSession.whereis(gid) == npc_pid, do: run(state, gid, label, due_ms), else: state
  end

  def fire(state, _ref), do: state

  @doc """
  Drops the slot on logout and starts the NPC's `OnTimerQuit` label attached
  to this player, at the armed label's time. Returns the started script's pid,
  or `nil` when there was no slot or no such label.
  """
  @spec quit(SessionState.t()) :: {SessionState.t(), pid() | nil}
  def quit(%{npc_timer: %{gid: gid, pending: [{due_ms, _label} | _rest]}} = state) do
    state = stop(state)

    case start_label(state, gid, @quit_label, due_ms, :quit) do
      {:ok, pid} -> {state, pid}
      {:error, _no_handler} -> {state, nil}
    end
  end

  def quit(state), do: {state, nil}

  defp arm(state, gid, npc_pid, [{_due_ms, _label} | _rest] = pending, delay) do
    ref = make_ref()
    timer = Process.send_after(self(), {:npc_timer_fire, ref}, max(delay, 0))
    %{state | npc_timer: %{ref: ref, timer: timer, gid: gid, npc_pid: npc_pid, pending: pending}}
  end

  defp run(state, gid, label, due_ms) do
    case start_label(state, gid, label, due_ms, :fire) do
      {:ok, pid} ->
        if SessionState.in_script?(state),
          do: state,
          else: SessionState.hold_npc_dialog(state, {pid, Process.monitor(pid), gid})

      {:error, _no_handler} ->
        state
    end
  end

  defp start_label(state, gid, label, due_ms, kind) do
    case NpcRegistry.module_for_unit(gid) do
      {:ok, {module, _placement}} ->
        ctx = state |> Ctx.from_session({:npc, module.npc_id()}) |> Map.put(:npc_gid, gid)
        NpcEvents.trigger_timer_attached(gid, label, ctx, self(), due_ms, kind)

      :error ->
        {:error, :no_handler}
    end
  end
end
