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
  alias Aesir.ZoneServer.Unit.Player.Handlers.NpcShopHandler
  alias Aesir.ZoneServer.Unit.Player.SessionState

  @doc """
  Processes an NPC click (protobuf analogue of CZ_CONTACTNPC 0x0090).

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
  (the `sleep` and `detachrid` script commands): the dialog lock clears so the player
  can act again while the script goes on without it. Events queued behind the
  script stay queued, as the reference detaches without dequeuing them;
  the next script to end releases them. A
  `pid` that no longer holds the lock changes nothing.
  """
  @spec detach_script(pid(), SessionState.t()) :: SessionState.t()
  def detach_script(pid, %{interaction_lock: {pid, ref, _gid}} = state) do
    Process.demonitor(ref, [:flush])
    %{state | interaction_lock: nil, npc_item_flag: nil}
  end

  def detach_script(_pid, state), do: state

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
    {:noreply, state}
  end

  defp forward(%NpcInteract{}, state) do
    {:noreply, state}
  end
end
