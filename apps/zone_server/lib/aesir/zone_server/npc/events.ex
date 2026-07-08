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
  """

  require Logger

  alias Aesir.ZoneServer.Npc.Registry
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Interaction

  @supervisor Aesir.ZoneServer.Npc.InteractionSupervisor

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
    |> Registry.gids_for_label()
    |> Enum.each(fn gid ->
      case Registry.module_for_unit(gid) do
        {:ok, {module, _placement}} -> spawn_detached(module, gid, label)
        :error -> :ok
      end
    end)
  end

  @doc """
  Targeted, detached event dispatch for an already-known gid — what
  `Npc.Session`'s timer fire invokes.

  Resolves `gid` to its module and spawns a detached `on_event/2` task when
  the module declares `label` in `events/0`. An unresolved gid or an
  undeclared label logs a warning and returns `:ok`, matching this module's
  fire-and-forget contract.
  """
  @spec trigger_gid(non_neg_integer(), String.t()) :: :ok
  def trigger_gid(gid, label) do
    with {:ok, {module, _placement}} <- Registry.module_for_unit(gid),
         true <- label in module.events() do
      spawn_detached(module, gid, label)
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

  @spec spawn_detached(module(), non_neg_integer(), String.t()) :: :ok
  defp spawn_detached(module, gid, label) do
    case Task.Supervisor.start_child(@supervisor, fn -> run_detached(module, gid, label) end) do
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

  # Runs the handler with nothing swallowed: an exception, exit, or throw is
  # logged with the {module, label, reason} that caused it, then propagated
  # faithfully so the task still dies with its original reason — only the log
  # line is new, not the crash behavior.
  @spec run_detached(module(), non_neg_integer(), String.t()) :: any()
  defp run_detached(module, gid, label) do
    module.on_event(label, Ctx.detached(module, gid))
  rescue
    reason ->
      log_crash(module, label, reason)
      reraise reason, __STACKTRACE__
  catch
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
