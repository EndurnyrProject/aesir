defmodule Aesir.ZoneServer.Script.Interaction do
  @moduledoc """
  The suspendable process backing one NPC conversation.

  Started by the player session on an `NpcTalk` and run straight-line: it
  invokes `module.on_talk/1` and lets the blocking dialog primitives
  (`Aesir.ZoneServer.Script.Dsl.next/1`/`select/2`/`input/2`) suspend on the
  client by `receive`-ing the routed `NpcInteract`. `close/1` (or any normal
  return with un-flushed `mes` text) flushes a terminal `CLOSE` frame, and the
  process exits `:normal`.

  This is a straight-line coroutine, not a `GenServer`: the sequential
  `mes; next; select` authoring style only works because the script *is* the
  process, blocking in place.

  ## Lifecycle (supervised Task, two one-directional monitors, no links)

  The process runs as a `:temporary` child of
  `Aesir.ZoneServer.Npc.InteractionSupervisor` — supervised for graceful
  shutdown and observability, but never restarted (a half-finished dialog can't
  resume). It is **not** linked to the session.

  The session **monitors** this process and clears its interaction lock on the
  `:DOWN` — fired identically for a normal exit, a `close`, an idle timeout, and
  a crash, so the lock always clears and the session always survives. This
  process **monitors the session** in turn (the ref lives on `ctx.session_ref`)
  so its blocking `receive` exits cleanly if the session dies. There is no
  `Process.link` between them: a link is bidirectional and would propagate an
  interaction crash to the session, defeating the crash isolation a monitor
  preserves.
  """

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Dsl

  @supervisor Aesir.ZoneServer.Npc.InteractionSupervisor

  @doc """
  Starts a supervised, unlinked interaction process for `module`, returning its pid.

  `base_ctx` is the context the session built (player snapshot, connection,
  `npc_gid`); the spawned process fills in its own `interaction_pid` and the
  `session_ref` monitoring `session_pid`, then runs `module.on_talk/1`.
  """
  @spec start(pid(), module(), Ctx.t()) :: {:ok, pid()} | {:error, term()}
  def start(session_pid, module, %Ctx{} = base_ctx) do
    Task.Supervisor.start_child(@supervisor, fn -> run(base_ctx, module, session_pid) end)
  end

  @doc """
  The interaction entry point: monitors the session, runs `on_talk`, then exits.

  Public so it can be the function handed to `Task.Supervisor.start_child/2`.
  """
  @spec run(Ctx.t(), module(), pid()) :: no_return()
  def run(%Ctx{} = base_ctx, module, session_pid) do
    session_ref = Process.monitor(session_pid)

    ctx = %{
      base_ctx
      | interaction_pid: self(),
        session_pid: session_pid,
        session_ref: session_ref
    }

    module.on_talk(ctx)
    |> auto_close()

    exit(:normal)
  end

  # Honors the design's "un-flushed mes on normal return auto-flushes a CLOSE":
  # if on_talk returns a ctx (or {ctx, _}) still carrying buffered page text, a
  # CLOSE frame is emitted so the client window always terminates. A ctx whose
  # page is already empty (the common `close/1` path) sends nothing more.
  @spec auto_close(any()) :: :ok
  defp auto_close(%Ctx{page: []}), do: :ok
  defp auto_close(%Ctx{} = ctx), do: _ = Dsl.close(ctx)
  defp auto_close({%Ctx{} = ctx, _value}), do: auto_close(ctx)
  defp auto_close(_other), do: :ok
end
