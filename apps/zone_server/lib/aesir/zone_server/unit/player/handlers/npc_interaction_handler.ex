defmodule Aesir.ZoneServer.Unit.Player.Handlers.NpcInteractionHandler do
  @moduledoc """
  Handles NPC clicks and dialog responses for a player session.

  A click resolves the unit to a shop window or a bespoke NPC module; the
  latter starts a supervised, monitored `Script.Interaction` process whose pid
  is stored as the session's interaction lock. One dialog at a time: a click
  while a lock is held is ignored (matches the client), and dialog responses
  are only forwarded to the locked interaction.

  A click on a bespoke NPC module gid that is currently disabled or hidden
  (`Npc.Session.visible?/1`) starts no interaction: the movement diff already
  keeps such an NPC off the client's screen, but this guards against a click
  the client sent just before the vanish packet arrived.
  """

  alias Aesir.Commons.GameMode
  alias Aesir.Net.NpcInteract
  alias Aesir.Net.SystemNotice
  alias Aesir.ZoneServer.Network.MessageRouter
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
  module, or one that is currently disabled/hidden, is a no-op.

  Public so `MovementHandler`'s `OnTouch` fallback (a trigger area whose
  module declares no `OnTouch` label — rAthena warper behavior) can start the
  same `on_talk/1` interaction the click path does, without duplicating this
  resolution/visibility/lock logic.
  """
  @spec talk_to_npc(non_neg_integer(), map(), SessionState.t()) :: {:noreply, SessionState.t()}
  def talk_to_npc(gid, game_state, state) do
    with false <- SessionState.interaction_blocked?(state),
         {:ok, {module, _placement}} <- NpcRegistry.module_for_unit(gid),
         true <- NpcSession.visible?(gid) do
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
