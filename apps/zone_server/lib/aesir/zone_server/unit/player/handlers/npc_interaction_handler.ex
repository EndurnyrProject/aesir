defmodule Aesir.ZoneServer.Unit.Player.Handlers.NpcInteractionHandler do
  @moduledoc """
  Handles NPC clicks and responses to NPC, skill and item dialogs.

  A click resolves the unit to a shop window or a bespoke NPC module; the
  latter starts a supervised, monitored `Script.Interaction` process whose pid
  is stored as the session's interaction lock. One dialog at a time: a click
  while a lock is held is ignored (matches the client), and dialog responses
  are only forwarded to the locked interaction, including a teleport item's
  synthetic dialog id.

  A click on a bespoke NPC module gid that is currently hidden
  (`Npc.Session.hidden?/1`, also set by `disablenpc`), or that has no client
  view at all (`Npc.Packets.visible?/1`, a `-1` sprite event NPC), starts no
  interaction, as in the reference: this guards against a click the
  client sent just before the vanish packet arrived, and against a synthetic
  click on a touch area that must not be talked to. A cloaked NPC stays
  clickable, as in the reference.

  A click also needs the player on the NPC's map and within
  `Config.view_range/0` + 1 cells of it on both axes. A floating NPC is on no
  map, so it always fails.

  A script attaching to the player over an open dialog (an attached `OnTimer`
  label) takes the lock and keeps the open dialog beneath it
  (`SessionState.take_over_npc_dialog/2`, rAthena `script_attach_state`). The
  dialog beneath comes back when the taker ends or detaches the player, and
  is lost when the taker pauses for the player (`script_paused/2`).
  """

  alias Aesir.Commons.GameMode
  alias Aesir.Net.NpcInteract
  alias Aesir.Net.SystemNotice
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Npc.Packets, as: NpcPackets
  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry
  alias Aesir.ZoneServer.Npc.Session, as: NpcSession
  alias Aesir.ZoneServer.Npc.Shop.Registry, as: ShopRegistry
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Interaction
  alias Aesir.ZoneServer.Unit.Player.Handlers.NpcEventQueue
  alias Aesir.ZoneServer.Unit.Player.Handlers.NpcShopHandler
  alias Aesir.ZoneServer.Unit.Player.SessionState

  @doc """
  Processes an NPC click (`NpcTalk`).

  A click while the player cannot act answers with the busy notice in renewal
  and is dropped silently in pre-renewal, as the reference does. A gid that
  resolves to neither a shop nor an NPC module is ignored.
  """
  @spec handle_talk(integer(), SessionState.t()) :: {:noreply, SessionState.t()}
  def handle_talk(gid, %{game_state: game_state} = state) do
    if SessionState.interaction_blocked?(state) or SessionState.work_in_progress?(state) or
         SessionState.npc_shop_open?(state) do
      refuse_busy(state)
    else
      case ShopRegistry.fetch(gid) do
        {:ok, shop} -> NpcShopHandler.open_window(state, shop)
        :error -> talk_to_npc(gid, game_state, state)
      end
    end
  end

  defp refuse_busy(%{connection_pid: connection_pid} = state) do
    if GameMode.mode() == :renewal do
      MessageRouter.send_to(connection_pid, %SystemNotice{id: :SYSTEM_NOTICE_ID_BUSY})
    end

    {:noreply, state}
  end

  @doc """
  Resolves `gid` to its bespoke NPC module and starts a supervised, monitored
  interaction process, storing the lock. A gid that resolves to no NPC
  module, one the player is not near (another map, a floating NPC, or more
  than `Config.view_range/0` + 1 cells away), one that is
  currently hidden (which `disablenpc` also sets) or client-invisible, or a
  player already held by a script is a no-op. Only the hide blocks a click
  on a visible NPC, so a cloaked NPC can still be talked to.

  Public so `TouchHandler`'s click fallback (a trigger area whose module
  declares no touch label, the reference warper behaviour) can start the same
  `on_talk/1` interaction the click path does, without duplicating this
  resolution/visibility/lock logic.
  """
  @spec talk_to_npc(non_neg_integer(), map(), SessionState.t()) :: {:noreply, SessionState.t()}
  def talk_to_npc(gid, game_state, state) do
    with false <- SessionState.in_script?(state),
         {:ok, {module, placement}} <- NpcRegistry.module_for_unit(gid),
         true <- near?(game_state, placement),
         false <- NpcSession.hidden?(gid),
         true <- NpcPackets.visible?({module, placement}) do
      base_ctx =
        Ctx.from_session(
          %{game_state: game_state, connection_pid: state.connection_pid},
          {:npc, module.npc_id()}
        )

      base_ctx = %{base_ctx | npc_gid: gid}
      {:ok, pid} = Interaction.start(self(), module, base_ctx)
      ref = Process.monitor(pid)

      {:noreply, SessionState.hold_npc_dialog(state, {pid, ref, gid})}
    else
      _not_visible_or_no_module -> {:noreply, state}
    end
  end

  defp near?(%{map_name: map, x: x, y: y}, %{map: map, x: nx, y: ny}) when is_binary(map),
    do: Geometry.in_tile_range?(x, y, nx, ny, Config.view_range() + 1)

  defp near?(_game_state, _placement), do: false

  @doc """
  Frees the player from the script `pid` runs when that script detaches it
  (the `sleep` and `detachrid` script commands): the script goes on without the
  player, and the dialog it held beneath it, if any, holds the player again
  (`SessionState.end_npc_dialog/1`); otherwise the player can act again.
  Events queued behind the script stay queued, as the reference detaches
  without dequeuing them; the next script to end releases them. A backed-up
  script detaching only leaves the stack; any other `pid` changes nothing.
  """
  @spec detach_script(pid(), SessionState.t()) :: SessionState.t()
  def detach_script(pid, %{interaction_lock: {pid, ref, _gid}} = state) do
    Process.demonitor(ref, [:flush])
    {_restored_or_released, state} = SessionState.end_npc_dialog(state)
    grant_attaches(state)
  end

  def detach_script(pid, state) do
    {lost, kept} = Enum.split_with(backups(state), &match?({{^pid, _ref, _gid}, _flag}, &1))
    Enum.each(lost, fn {{_pid, ref, _gid}, _flag} -> Process.demonitor(ref, [:flush]) end)
    Map.put(state, :dialog_backups, kept)
  end

  @doc """
  Ends the running dialog when its script process exits (close, idle timeout,
  crash): the progress bar it started is released, then the dialog it held
  beneath it takes the player back, or, with none, the player is free and the
  first NPC event queued meanwhile is released (rAthena `script_detach_state`,
  which dequeues only when it restores no previous script).
  """
  @spec script_ended(SessionState.t()) :: SessionState.t()
  def script_ended(%{interaction_lock: {_pid, _ref, gid}} = state) do
    state =
      case Map.get(state, :progress_bar) do
        %{npc_gid: ^gid} -> SessionState.release_progress_bar(state)
        _not_its_bar -> state
      end

    case SessionState.end_npc_dialog(state) do
      {:restored, state} -> grant_attaches(state)
      {:released, state} -> state |> NpcEventQueue.release() |> grant_attaches()
    end
  end

  @doc """
  The running script `pid` paused for the player (a dialog page, menu, input,
  progress bar or close): the dialogs it took over are lost for good, as
  rAthena frees the backed-up script of a script that stops to wait
  ("Double continuation"), and their scripts end. A skill-staged dialog is no
  script and stays beneath. Now that the script waits, the scripts waiting to
  attach take the player over (`attach/2`). A pause from any other script
  changes nothing.
  """
  @spec script_paused(pid(), SessionState.t()) :: SessionState.t()
  def script_paused(pid, %{interaction_lock: {pid, _ref, _gid}} = state) do
    system_gid = SessionState.system_dialog_gid()

    {kept, lost} =
      Enum.split_with(backups(state), &match?({{_pid, _ref, ^system_gid}, _flag}, &1))

    Enum.each(lost, fn {{lost_pid, ref, _gid}, _flag} ->
      Process.demonitor(ref, [:flush])
      Process.exit(lost_pid, :shutdown)
    end)

    state
    |> Map.merge(%{dialog_backups: kept, dialog_running?: false})
    |> grant_attaches()
  end

  def script_paused(_pid, state), do: state

  @doc """
  Attaches a script to the player (rAthena `script_attach_state`), taking
  over the dialog holding them, if any (`SessionState.take_over_npc_dialog/2`).
  The reference only ever attaches over a script that waits, so while the
  holding script runs between two waits the request waits its turn, in
  order, until that script waits, detaches the player or ends. A request is
  a timer label to start or a script process asking through
  `handle_attach_script/5`, which is answered when it attaches.
  """
  @spec attach(SessionState.t(), SessionState.dialog_attach()) :: SessionState.t()
  def attach(state, request) do
    queued = Map.update(state, :dialog_attaches, [request], &(&1 ++ [request]))
    grant_attaches(queued)
  end

  @doc """
  Handles a script asking to attach to this player (`attachrid`, or a
  `sleep2` waking up). Without `force` a player held by a script refuses it
  (`buildin_attachrid`'s `!sd->npc_id || force`); the script already holding
  the player is attached already. Otherwise it attaches (`attach/2`) and is
  answered `{:ok, %{game_state, connection_pid}}` once it has.
  """
  @spec handle_attach_script(
          SessionState.t(),
          GenServer.from(),
          pid(),
          non_neg_integer(),
          boolean()
        ) ::
          {:reply, term(), SessionState.t()} | {:noreply, SessionState.t()}
  def handle_attach_script(state, from, pid, gid, force?) do
    case Map.get(state, :interaction_lock) do
      {^pid, _ref, _gid} when force? -> {:reply, {:ok, attach_info(state)}, state}
      lock when lock != nil and not force? -> {:reply, :busy, state}
      _free_or_forced -> {:noreply, attach(state, {:reply, from, pid, gid})}
    end
  end

  @doc """
  Drops the backed-up dialog whose script monitor `ref` fired (it timed out
  or crashed while beneath another). `:error` when `ref` is no backed-up
  dialog's.
  """
  @spec backup_ended(reference(), SessionState.t()) :: {:ok, SessionState.t()} | :error
  def backup_ended(ref, state) do
    case Enum.split_with(backups(state), &match?({{_pid, ^ref, _gid}, _flag}, &1)) do
      {[], _kept} -> :error
      {_ended, kept} -> {:ok, Map.put(state, :dialog_backups, kept)}
    end
  end

  @doc """
  Forwards the player's response to the pending NpcDialog to the locked
  interaction process. Dropped when no dialog is active or the response
  carries a different npc_id than the active interaction.

  While a progress bar runs, the client's report (`progress`, or `cancel` for
  a bar it cancelled) ends the bar and releases the work flag: reported before
  the bar fills it ends the script, after it the script continues. Any other
  response is dropped until the bar fills.
  """
  @spec handle_interact(NpcInteract.t(), SessionState.t()) :: {:noreply, SessionState.t()}
  def handle_interact(%NpcInteract{npc_id: gid, response: {kind, _}} = msg, state) do
    case Map.get(state, :progress_bar) do
      %{npc_gid: ^gid, deadline: deadline} ->
        cond do
          kind in [:progress, :cancel] and System.monotonic_time(:millisecond) >= deadline ->
            forward(msg, SessionState.release_progress_bar(state))

          kind in [:progress, :cancel] ->
            cancel = %NpcInteract{npc_id: gid, response: {:cancel, true}}
            forward(cancel, SessionState.release_progress_bar(state))

          System.monotonic_time(:millisecond) >= deadline ->
            forward(msg, state)

          true ->
            {:noreply, state}
        end

      _no_bar_for_this_npc ->
        forward(msg, state)
    end
  end

  defp forward(
         %NpcInteract{npc_id: gid} = msg,
         %{interaction_lock: {pid, _ref, gid}} = state
       ) do
    send(pid, {:npc_interact, msg})
    {:noreply, SessionState.resume_npc_dialog(state)}
  end

  # A skill-staged dialog beneath a script's is no script state in the
  # reference (its menu answers on its own), so it still gets its answer.
  defp forward(%NpcInteract{npc_id: gid} = msg, state) do
    if gid == SessionState.system_dialog_gid() do
      Enum.each(backups(state), fn
        {{pid, _ref, ^gid}, _flag} -> send(pid, {:npc_interact, msg})
        _script_dialog -> :ok
      end)
    end

    {:noreply, state}
  end

  defp backups(state), do: Map.get(state, :dialog_backups, [])

  # Hands the player to the first waiting script while the holder waits (or
  # there is none), then stops: the new holder runs until its own wait.
  defp grant_attaches(state) do
    case Map.get(state, :dialog_attaches, []) do
      [] ->
        state

      [request | rest] ->
        state = Map.put(state, :dialog_attaches, rest)

        if Map.get(state, :interaction_lock) != nil and Map.get(state, :dialog_running?),
          do: Map.put(state, :dialog_attaches, [request | rest]),
          else: state |> grant(request) |> grant_attaches()
    end
  end

  defp grant(state, {:start, start, gid}) do
    case start.() do
      {:ok, pid} -> SessionState.take_over_npc_dialog(state, {pid, Process.monitor(pid), gid})
      {:error, _no_handler} -> state
    end
  end

  defp grant(state, {:reply, from, pid, gid}) do
    if Process.alive?(pid) do
      state = SessionState.take_over_npc_dialog(state, {pid, Process.monitor(pid), gid})
      GenServer.reply(from, {:ok, attach_info(state)})
      state
    else
      state
    end
  end

  defp attach_info(state),
    do: %{game_state: state.game_state, connection_pid: state.connection_pid}
end
