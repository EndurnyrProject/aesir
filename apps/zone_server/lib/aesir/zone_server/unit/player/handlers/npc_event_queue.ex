defmodule Aesir.ZoneServer.Unit.Player.Handlers.NpcEventQueue do
  @moduledoc """
  Player-attached NPC events (`OnTouch_`, `OnTouch`, `OnMyMobDead`, ...) and
  the queue they wait in while the player is busy.

  `dispatch/3` is the entry point: a free player starts the event's attached
  `Script.Interaction` at once; a busy one (interaction lock or pending skill
  text input) queues it. The queue holds two events; a third is logged and
  dropped. The session drains it one event at a time: when the lock releases
  (`release/1`), the head is popped and run 100 ms later (`run_queued/3`),
  where it is re-queued at the back if the player is busy again, dropped
  when its NPC is no longer visible or, for a touch label, when the player
  has left the NPC's area (which pops the next one), and otherwise started.
  """

  require Logger

  alias Aesir.ZoneServer.Npc.Events, as: NpcEvents
  alias Aesir.ZoneServer.Npc.Placement
  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry
  alias Aesir.ZoneServer.Npc.Session, as: NpcSession
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Unit.Player.SessionState

  @max_queued 2
  @dequeue_delay_ms 100
  @touch_labels ["OnTouch_", "OnTouch"]

  @typedoc "A queued event: the target NPC gid and its label."
  @type event :: {non_neg_integer(), String.t()}

  @doc """
  Runs `label` on `gid` for this player now, or queues it while the player is
  busy. `module` is the NPC module when the caller already resolved it;
  otherwise it is looked up in the registry. A label the module does not
  declare is logged and ignored.
  """
  @spec dispatch(SessionState.t(), non_neg_integer(), String.t(), module() | nil) ::
          SessionState.t()
  def dispatch(state, gid, label, module \\ nil) do
    if SessionState.interaction_blocked?(state) do
      enqueue(state, gid, label)
    else
      case start_attached(state, gid, label, module) do
        {:ok, state} -> state
        {:error, _reason} -> state
      end
    end
  end

  @doc "Appends the event, or logs and drops it when both slots are taken."
  @spec enqueue(SessionState.t(), non_neg_integer(), String.t()) :: SessionState.t()
  def enqueue(state, gid, label) do
    queue = queue(state)

    if length(queue) < @max_queued do
      Map.put(state, :npc_event_queue, queue ++ [{gid, label}])
    else
      Logger.warning("npc event queue full, dropping #{inspect(label)} for gid #{gid}")
      state
    end
  end

  @doc """
  Pops the head of the queue and schedules it to run after the dequeue
  delay. Called when whatever made the player busy ends.
  """
  @spec release(SessionState.t()) :: SessionState.t()
  def release(state) do
    case queue(state) do
      [] ->
        state

      [{gid, label} | rest] ->
        Process.send_after(self(), {:npc, {:run_queued_event, gid, label}}, @dequeue_delay_ms)
        Map.put(state, :npc_event_queue, rest)
    end
  end

  @doc """
  Runs a dequeued event: re-queued when the player is busy again, dropped
  (popping the next) when it can no longer run, started otherwise.
  """
  @spec run_queued(SessionState.t(), non_neg_integer(), String.t()) :: SessionState.t()
  def run_queued(state, gid, label) do
    cond do
      SessionState.interaction_blocked?(state) ->
        enqueue(state, gid, label)

      not runnable?(state.game_state, gid, label) ->
        release(state)

      true ->
        case start_attached(state, gid, label) do
          {:ok, state} -> state
          {:error, _reason} -> release(state)
        end
    end
  end

  @doc """
  Starts `label` on `gid` as an attached interaction and takes the
  interaction lock. The caller has already ruled out a busy player. A
  disabled or hidden NPC runs nothing.
  """
  @spec start_attached(SessionState.t(), non_neg_integer(), String.t(), module() | nil) ::
          {:ok, SessionState.t()} | {:error, term()}
  def start_attached(state, gid, label, module \\ nil) do
    with {:ok, module} <- resolve_module(gid, module),
         true <- NpcSession.visible?(gid) || {:error, :invisible},
         {:ok, pid} <-
           NpcEvents.trigger_attached(gid, label, event_ctx(state, module, gid), self()) do
      ref = Process.monitor(pid)
      {:ok, SessionState.hold_npc_dialog(state, {pid, ref, gid})}
    else
      {:error, reason} ->
        Logger.warning("npc event: #{inspect(reason)} for #{inspect(label)} (gid #{gid})")
        {:error, reason}
    end
  end

  defp resolve_module(_gid, module) when is_atom(module) and not is_nil(module), do: {:ok, module}

  defp resolve_module(gid, nil) do
    case NpcRegistry.module_for_unit(gid) do
      {:ok, {module, _placement}} -> {:ok, module}
      :error -> {:error, :no_npc}
    end
  end

  defp event_ctx(state, module, gid) do
    state
    |> Ctx.from_session({:npc, module.npc_id()})
    |> Map.put(:npc_gid, gid)
  end

  defp runnable?(game_state, gid, label) do
    with {:ok, {_module, placement}} <- NpcRegistry.module_for_unit(gid),
         true <- NpcSession.visible?(gid) do
      label not in @touch_labels or
        Placement.touch_area_contains?(placement, game_state.map_name, game_state.x, game_state.y)
    else
      _gone_or_hidden -> false
    end
  end

  defp queue(state), do: Map.get(state, :npc_event_queue, [])
end
