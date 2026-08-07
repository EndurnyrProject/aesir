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

  defp supervisor do
    ProcessTree.get({Aesir.ZoneServer.Npc.InteractionSupervisor, :server}) || @supervisor
  end

  @doc """
  Starts a supervised, unlinked interaction process for `module`, returning its pid.

  `base_ctx` is the context the session built (player snapshot, connection,
  `npc_gid`); the spawned process fills in its own `interaction_pid` and the
  `session_ref` monitoring `session_pid`, then runs `entry_fn.(ctx)`.

  `entry_fn` defaults to `module.on_talk/1`, the click-driven entry point;
  callers dispatching an attached event (`OnTouch`, `doevent`, ...) pass
  `fn ctx -> module.on_event(label, ctx) end` instead.
  """
  @spec start(pid(), module(), Ctx.t()) :: {:ok, pid()} | {:error, term()}
  def start(session_pid, module, %Ctx{} = base_ctx) do
    start(session_pid, module, base_ctx, &module.on_talk/1)
  end

  @spec start(pid(), module(), Ctx.t(), (Ctx.t() -> any())) :: {:ok, pid()} | {:error, term()}
  def start(session_pid, module, %Ctx{} = base_ctx, entry_fn) when is_function(entry_fn, 1) do
    Task.Supervisor.start_child(supervisor(), fn ->
      run(base_ctx, module, session_pid, entry_fn)
    end)
  end

  @doc """
  The interaction entry point: monitors the session, runs `on_talk`, then exits.

  Public so it can be the function handed to `Task.Supervisor.start_child/2`.
  """
  @spec run(Ctx.t(), module(), pid()) :: no_return()
  def run(%Ctx{} = base_ctx, module, session_pid) do
    run(base_ctx, module, session_pid, &module.on_talk/1)
  end

  @spec run(Ctx.t(), module(), pid(), (Ctx.t() -> any())) :: no_return()
  def run(%Ctx{} = base_ctx, _module, session_pid, entry_fn) when is_function(entry_fn, 1) do
    session_ref = Process.monitor(session_pid)

    ctx = %{
      base_ctx
      | interaction_pid: self(),
        session_pid: session_pid,
        session_ref: session_ref
    }

    ctx
    |> run_entry(entry_fn)
    |> auto_close()

    exit(:normal)
  end

  # Transpiled scripts end `close`/`end` by throwing `{:script_end, ctx}`;
  # generated entry points catch it themselves, but a hand-written `on_talk`
  # calling a transpiled global function (`Functions.*.call/2`) lets it unwind
  # to here. Catching it makes that a clean end instead of a {:nocatch, _}
  # crash, and hands auto_close the ctx the script terminated with.
  defp run_entry(ctx, entry_fn) do
    entry_fn.(ctx)
  catch
    :throw, {:script_end, %Ctx{} = ctx} -> ctx
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
