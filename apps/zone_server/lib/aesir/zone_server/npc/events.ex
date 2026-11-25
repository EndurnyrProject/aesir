defmodule Aesir.ZoneServer.Npc.Events do
  @moduledoc """
  Stateless dispatch facade every rAthena-style NPC event source routes
  through: `donpcevent`/`doevent`-style targeted dispatch (`trigger/1,2`),
  broadcast dispatch to every NPC declaring a label (`trigger_all/1`), and
  player-attached dispatch for events that need a live session (`OnTouch`,
  `doevent`, `trigger_attached/4`).

  Targeted and broadcast dispatch run **detached** (`Ctx.detached/2` — no
  player, no session): each hit spawns its own supervised, unlinked task
  under `Aesir.ZoneServer.Npc.InteractionSupervisor`, so one handler crashing
  never takes another down, nor the caller that fired the event.

  `run_on_init/1` is the boot-time (and `@reloadscript`-time) counterpart:
  synchronous, so callers can await every `OnInit` handler before proceeding,
  but still isolates each NPC's handler in its own detached task so one
  crashing or hanging NPC cannot block or fail the others. A handler that
  sleeps counts as done, as in rAthena, where `npc_event_doall` moves on once
  a script suspends.
  """

  require Logger

  alias Aesir.ZoneServer.Npc.Registry
  alias Aesir.ZoneServer.Npc.Session, as: NpcSession
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Interaction

  @supervisor Aesir.ZoneServer.Npc.InteractionSupervisor
  @on_init_timeout 5_000

  defp supervisor do
    ProcessTree.get({Aesir.ZoneServer.Npc.InteractionSupervisor, :server}) || @supervisor
  end

  @doc """
  Targeted, detached event dispatch — what `donpcevent "Name::OnLabel"`
  compiles to.

  Parses `ref` as `"Name::OnLabel"` and resolves it exactly like
  `trigger/2`. A malformed ref (no `"::"`) logs a warning and returns `:ok`,
  matching rAthena's no-op-on-bad-target behavior.
  """
  @spec trigger(String.t()) :: :ok
  def trigger(ref) do
    case String.split(ref, "::", parts: 2) do
      [name, label] ->
        trigger(name, label)

      _malformed ->
        Logger.warning("npc event trigger: malformed ref #{inspect(ref)}")
        :ok
    end
  end

  @doc """
  Targeted, detached event dispatch given the unique name and label
  separately.

  Resolves every placement registered under `name` and spawns a detached
  `on_event/2` task for each whose module declares `label` in `events/0`. An
  unknown name or a name with no matching handler logs a warning and returns
  `:ok`.
  """
  @spec trigger(String.t(), String.t()) :: :ok
  def trigger(name, label) do
    case Registry.by_name(name) do
      [] ->
        Logger.warning("npc event trigger: unknown name #{inspect(name)}")
        :ok

      entries ->
        dispatch_named(name, label, entries)
    end
  end

  @doc """
  Broadcast, detached event dispatch: fires `label` on every NPC declaring
  it in `events/0` (the clock scheduler's `OnTimerNNNN`, global `OnLabel`
  hooks, ...). Silently a no-op when nothing declares `label`.
  """
  @spec trigger_all(String.t()) :: :ok
  def trigger_all(label) do
    label
    |> Registry.entries_for_label()
    |> Enum.each(fn {module, gid} -> spawn_detached(module, gid, label) end)
  end

  @doc """
  Targeted, detached event dispatch for an already-known gid.

  Resolves `gid` to its module and spawns a detached `on_event/2` task when
  the module declares `label` in `events/0`. An unresolved gid or an
  undeclared label logs a warning and returns `:ok`, matching this module's
  fire-and-forget contract.
  """
  @spec trigger_gid(non_neg_integer(), String.t()) :: :ok
  def trigger_gid(gid, label), do: trigger_gid(gid, label, nil)

  @doc """
  Runs a label of the NPC's own timer (`npc_timerevent` with no attached
  player): what `Npc.Session`'s timer fire invokes. Dispatched like
  `trigger_gid/2`, but the label runs inside an `:own` label run
  (`Npc.Session.begin_run/2`), so until it first waits or ends its timer
  commands see no attached player.
  """
  @spec trigger_timer(non_neg_integer(), String.t()) :: :ok
  def trigger_timer(gid, label), do: trigger_gid(gid, label, :own)

  defp trigger_gid(gid, label, run) do
    with {:ok, {module, _placement}} <- Registry.module_for_unit(gid),
         true <- label in module.events() do
      spawn_detached(module, gid, label, nil, run)
    else
      :error ->
        Logger.warning("npc event trigger: unresolved gid #{inspect(gid)}")
        :ok

      false ->
        Logger.warning("npc event trigger: #{inspect(gid)} has no handler for #{inspect(label)}")
        :ok
    end
  end

  @doc """
  Detached event dispatch attached to a non-player unit: what a monster
  stepping into an NPC's trigger area fires (`OnTouchNPC`, run with the
  monster as the script's `rid`).

  Spawns a detached `on_event/2` task whose ctx carries `unit` in
  `Ctx.attached_unit`; player commands still end the script. Returns
  `{:error, :no_handler}` when `gid` does not resolve or its module does not
  declare `label`.
  """
  @spec trigger_unit(non_neg_integer(), String.t(), {:mob, integer()}) ::
          :ok | {:error, :no_handler}
  def trigger_unit(gid, label, {:mob, _id} = unit) do
    with {:ok, {module, _placement}} <- Registry.module_for_unit(gid),
         true <- label in module.events() do
      spawn_detached(module, gid, label, unit)
    else
      _not_handled -> {:error, :no_handler}
    end
  end

  @doc """
  Runs `on_event("OnInit", ctx)` once per placement declaring it, synchronously.

  Meant to be called once at boot, right after the NPC registry loads, and
  again by `@reloadscript` after `Registry.reload/1` — rAthena semantics.
  Every `{module, gid}` in `Registry.entries_for_label("OnInit")` gets its own
  detached task dispatched straight to the declaring module (so a cell shared by
  a non-`OnInit` NPC cannot misroute the event), then this waits up to
  `:timeout` (default #{@on_init_timeout}ms; a test seam, not a production
  knob) total for each of them to end or `sleep`. A handler that sleeps is left
  running unawaited. A handler that raises is logged and does not stop the
  others; a handler still running past the timeout is logged as a straggler
  and killed. Always returns `:ok` so the boot sequence proceeds regardless of
  outcome.
  """
  @spec run_on_init(timeout: non_neg_integer()) :: :ok
  def run_on_init(opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @on_init_timeout)

    "OnInit"
    |> Registry.entries_for_label()
    |> Enum.map(&start_on_init_task/1)
    |> await_on_init(timeout)

    :ok
  end

  @doc """
  Player-attached event dispatch (`OnTouch`, `doevent`, ...).

  Resolves `gid` to its NPC module and, when the module declares `label` in
  `events/0`, starts a real `Script.Interaction` entering at
  `on_event(label, ctx)` instead of `on_talk/1`. Returns `{:error,
  :no_handler}` when `gid` resolves but the label isn't declared, or when
  `gid` doesn't resolve at all — callers (e.g. `OnTouch`) use this to fall
  back to `on_talk/1`.

  `base_ctx` and `session_pid` are supplied by the caller exactly as they
  would be to `Interaction.start/3`; this function does not build player
  contexts itself.
  """
  @spec trigger_attached(non_neg_integer(), String.t(), Ctx.t(), pid()) ::
          {:ok, pid()} | {:error, term()}
  def trigger_attached(gid, label, %Ctx{} = base_ctx, session_pid) do
    with {:ok, {module, _placement}} <- Registry.module_for_unit(gid),
         true <- label in module.events() do
      Interaction.start(session_pid, module, base_ctx, fn ctx -> module.on_event(label, ctx) end)
    else
      _not_handled -> {:error, :no_handler}
    end
  end

  @doc """
  Runs a player-attached timer label (`npc_timerevent`, or `npc_timerevent_quit`
  for `OnTimerQuit`) as an attached `Script.Interaction`, the way
  `trigger_attached/4` does, but inside a label run (`Npc.Session.begin_run/2`):
  until the label first waits or ends, the NPC's attached player is the
  script's player and its timer reads `time_ms`; then the NPC's own values
  are back. A quit run of the attached player itself detaches it.

  Unlike `trigger_attached/4` the NPC's enabled state is not checked: a timer
  fires regardless. Returns `{:error, :no_handler}` when `gid` does not resolve
  or does not declare `label`.
  """
  @spec trigger_timer_attached(
          non_neg_integer(),
          String.t(),
          Ctx.t(),
          pid(),
          integer(),
          :fire | :quit
        ) :: {:ok, pid()} | {:error, term()}
  def trigger_timer_attached(gid, label, %Ctx{} = base_ctx, session_pid, time_ms, kind) do
    with {:ok, {module, _placement}} <- Registry.module_for_unit(gid),
         true <- label in module.events() do
      Interaction.start(session_pid, module, base_ctx, fn ctx ->
        in_label_run(gid, {kind, ctx.char_id, time_ms}, ctx, &module.on_event(label, &1))
      end)
    else
      _not_handled -> {:error, :no_handler}
    end
  end

  # Runs `fun` inside a label run of `gid` (none for `nil`). The ctx carries
  # the run so the script's first wait closes it; the end closes it otherwise.
  @spec in_label_run(non_neg_integer(), NpcSession.run_kind() | nil, Ctx.t(), (Ctx.t() -> term())) ::
          term()
  defp in_label_run(_gid, nil, ctx, fun), do: fun.(ctx)

  defp in_label_run(gid, kind, ctx, fun) do
    :ok = NpcSession.begin_run(gid, kind)

    try do
      fun.(%{ctx | timer_run: gid})
    after
      NpcSession.end_run(gid)
    end
  end

  @spec dispatch_named(String.t(), String.t(), [Registry.entry()]) :: :ok
  defp dispatch_named(name, label, entries) do
    targets = Enum.filter(entries, fn {module, _placement} -> label in module.events() end)

    case targets do
      [] ->
        Logger.warning("npc event trigger: #{inspect(name)} has no handler for #{inspect(label)}")

      _hit ->
        Enum.each(targets, fn {module, placement} ->
          spawn_detached(module, Registry.entity_id(placement), label)
        end)
    end

    :ok
  end

  @spec spawn_detached(
          module(),
          non_neg_integer(),
          String.t(),
          Ctx.attached_unit(),
          NpcSession.run_kind() | nil
        ) :: :ok
  defp spawn_detached(module, gid, label, unit \\ nil, timer_run \\ nil) do
    ctx = %{Ctx.detached(module, gid) | attached_unit: unit}
    run = fn -> in_label_run(gid, timer_run, ctx, &run_detached(module, label, &1)) end

    case Task.Supervisor.start_child(supervisor(), run) do
      {:ok, _pid} ->
        :ok

      {:error, reason} ->
        Logger.warning(
          "npc event trigger: failed to start detached task for " <>
            "#{inspect({module, label})}: #{inspect(reason)}"
        )

        :ok
    end
  end

  @spec start_on_init_task({module(), non_neg_integer()}) :: {non_neg_integer(), Task.t()}
  defp start_on_init_task({module, gid}) do
    ctx = %{Ctx.detached(module, gid) | awaiter: self()}

    task =
      Task.Supervisor.async_nolink(supervisor(), fn -> run_detached(module, "OnInit", ctx) end)

    {gid, task}
  end

  @spec await_on_init([{non_neg_integer(), Task.t()}], non_neg_integer()) :: :ok
  defp await_on_init(gid_tasks, timeout) do
    deadline = System.monotonic_time(:millisecond) + timeout

    gid_tasks
    |> Map.new(fn {gid, task} -> {task.ref, {gid, task}} end)
    |> await_pending(deadline, timeout)
  end

  # Waits for every pending task to reply, crash or report that it sleeps
  # (`Dsl.Dialog.sleep/2` sends `{:script_suspended, pid}` to `ctx.awaiter`).
  # A sleeping task is ignored, not killed: it finishes on its own.
  @spec await_pending(
          %{reference() => {non_neg_integer(), Task.t()}},
          integer(),
          non_neg_integer()
        ) ::
          :ok
  defp await_pending(pending, _deadline, _timeout) when map_size(pending) == 0, do: :ok

  defp await_pending(pending, deadline, timeout) do
    remaining = max(deadline - System.monotonic_time(:millisecond), 0)

    receive do
      {ref, _result} when is_map_key(pending, ref) ->
        Process.demonitor(ref, [:flush])
        await_pending(Map.delete(pending, ref), deadline, timeout)

      {:DOWN, ref, :process, _pid, reason} when is_map_key(pending, ref) ->
        {gid, _task} = pending[ref]
        Logger.warning("npc OnInit: gid #{inspect(gid)} crashed: #{inspect(reason)}")
        await_pending(Map.delete(pending, ref), deadline, timeout)

      {:script_suspended, pid} ->
        pending |> drop_suspended(pid) |> await_pending(deadline, timeout)
    after
      remaining -> Enum.each(pending, fn {_ref, gid_task} -> abandon(gid_task, timeout) end)
    end
  end

  defp drop_suspended(pending, pid) do
    case Enum.find(pending, fn {_ref, {_gid, task}} -> task.pid == pid end) do
      {ref, {_gid, task}} ->
        Task.ignore(task)
        Map.delete(pending, ref)

      nil ->
        pending
    end
  end

  defp abandon({gid, task}, timeout) do
    Logger.warning(
      "npc OnInit: gid #{inspect(gid)} did not finish within #{timeout}ms, abandoning"
    )

    Task.shutdown(task, :brutal_kill)
  end

  # Runs the handler with nothing swallowed: an exception, exit, or throw is
  # logged with the {module, label, reason} that caused it, then propagated
  # faithfully so the task still dies with its original reason — only the log
  # line is new, not the crash behavior. The one exception is the script
  # termination protocol: `{:script_end, ctx}` is a transpiled `close`/`end`
  # unwinding cleanly, not a crash, so it resolves to the final ctx.
  @spec run_detached(module(), String.t(), Ctx.t()) :: any()
  defp run_detached(module, label, ctx) do
    module.on_event(label, ctx)
  rescue
    reason ->
      log_crash(module, label, reason)
      reraise reason, __STACKTRACE__
  catch
    :throw, {:script_end, %Ctx{} = ctx} ->
      ctx

    :exit, reason ->
      log_crash(module, label, reason)
      exit(reason)

    :throw, value ->
      log_crash(module, label, value)
      throw(value)
  end

  @spec log_crash(module(), String.t(), term()) :: :ok
  defp log_crash(module, label, reason) do
    Logger.error("npc event crashed: #{inspect({module, label, reason})}")
  end
end
