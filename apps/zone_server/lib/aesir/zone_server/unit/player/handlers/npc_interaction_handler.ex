defmodule Aesir.ZoneServer.Unit.Player.Handlers.NpcInteractionHandler do
  @moduledoc """
  Handles NPC clicks and dialog responses for a player session.

  A click resolves the unit to a shop window or a bespoke NPC module; the
  latter starts a supervised, monitored `Script.Interaction` process whose pid
  is stored as the session's interaction lock. One dialog at a time: a click
  while a lock is held is ignored (matches the client), and dialog responses
  are only forwarded to the locked interaction.
  """

  alias Aesir.Net.NpcInteract
  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry
  alias Aesir.ZoneServer.Npc.Shop.Registry, as: ShopRegistry
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Interaction
  alias Aesir.ZoneServer.Unit.Player.Handlers.NpcShopHandler

  @doc """
  Processes an NPC click (protobuf analogue of CZ_CONTACTNPC 0x0090).

  Ignored while an interaction lock is held. A gid that resolves to neither a
  shop nor an NPC module is ignored.
  """
  @spec handle_talk(integer(), map()) :: {:noreply, map()}
  def handle_talk(_gid, %{interaction_lock: lock} = state) when not is_nil(lock) do
    {:noreply, state}
  end

  def handle_talk(gid, %{game_state: game_state} = state) do
    case ShopRegistry.fetch(gid) do
      {:ok, shop} -> NpcShopHandler.open_window(state, shop)
      :error -> talk_to_npc(gid, game_state, state)
    end
  end

  @doc """
  Forwards the player's response to the pending NpcDialog to the locked
  interaction process. Dropped when no dialog is active or the response
  carries a different npc_id than the active interaction.
  """
  @spec handle_interact(NpcInteract.t(), map()) :: {:noreply, map()}
  def handle_interact(
        %NpcInteract{npc_id: gid} = msg,
        %{interaction_lock: {pid, _ref, gid}} = state
      ) do
    send(pid, {:npc_interact, msg})
    {:noreply, state}
  end

  def handle_interact(%NpcInteract{}, state) do
    {:noreply, state}
  end

  # Resolves the clicked gid to its bespoke NPC module and starts a supervised,
  # monitored interaction process, storing the lock. A gid that resolves to no
  # NPC module is ignored. Reached only after the shop branch declines the gid.
  defp talk_to_npc(gid, game_state, state) do
    case NpcRegistry.module_for_unit(gid) do
      {:ok, {module, _placement}} ->
        base_ctx =
          Ctx.from_session(
            %{game_state: game_state, connection_pid: state.connection_pid},
            {:npc, module.npc_id()}
          )

        base_ctx = %{base_ctx | npc_gid: gid}
        {:ok, pid} = Interaction.start(self(), module, base_ctx)
        ref = Process.monitor(pid)

        {:noreply, %{state | interaction_lock: {pid, ref, gid}}}

      :error ->
        {:noreply, state}
    end
  end
end
