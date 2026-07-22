defmodule Aesir.ZoneServer.Unit.Player.Handlers.VisibilityHandler do
  @moduledoc """
  Player-facing visibility glue: another player entering or leaving this
  session's view.

  On entry the entering unit's `UnitSpawn` (built by `SpawnView`), its active
  status icons and, when it is running an open vending shop, its board are
  pushed to this session's connection. On exit a `UnitDespawn` vanish packet
  is sent.
  """

  alias Aesir.Net.UnitDespawn
  alias Aesir.Net.VendingBoardShown
  alias Aesir.ZoneServer.Constants.DespawnReason
  alias Aesir.ZoneServer.Mmo.StatusEffect.StatusDisplay
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SpawnView
  alias Aesir.ZoneServer.Unit.UnitRegistry
  alias Aesir.ZoneServer.Unit.Vending.Registry, as: VendingRegistry

  @doc """
  Sends the entering player's spawn packet, active icons and (if any) vending
  board to this session. Reads the other player's state straight from the
  registry instead of round-tripping through their process to fetch it.
  """
  @spec entered_view(non_neg_integer(), map()) :: {:noreply, map()}
  def entered_view(other_char_id, state) do
    case UnitRegistry.get_unit(:player, other_char_id) do
      {:ok, {_module, %PlayerState{} = other_game_state, _pid}} ->
        MessageRouter.send_to(state.connection_pid, SpawnView.build(other_game_state))
        send_active_icons(:player, other_char_id, state.game_state.character_id)
        maybe_send_vending_board(state.connection_pid, other_char_id)

      _ ->
        :ok
    end

    {:noreply, state}
  end

  @doc """
  Sends a vanish packet to this session for a player that left its view.
  """
  @spec left_view(non_neg_integer(), map()) :: {:noreply, map()}
  def left_view(other_char_id, state) do
    packet = %UnitDespawn{
      gid: other_char_id,
      reason: DespawnReason.out_of_sight()
    }

    MessageRouter.send_to(state.connection_pid, packet)

    {:noreply, state}
  end

  defp maybe_send_vending_board(connection_pid, char_id) do
    case VendingRegistry.get(char_id) do
      {:ok, %{title: title}} ->
        MessageRouter.send_to(connection_pid, %VendingBoardShown{unit_id: char_id, title: title})

      :error ->
        :ok
    end
  end

  defp send_active_icons(unit_type, subject_id, observer_id) do
    unit_type
    |> StatusDisplay.active_icons(subject_id)
    |> Enum.each(&Broadcast.to_player(observer_id, &1))
  end
end
