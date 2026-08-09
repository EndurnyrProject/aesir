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
  alias Aesir.ZoneServer.Unit.Concealment
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Homunculus.SpawnView, as: HomunculusSpawnView
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SpawnView
  alias Aesir.ZoneServer.Unit.SpatialIndex
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
        spawn_packet =
          Concealment.reveal(
            SpawnView.build(other_game_state),
            PlayerState.intravision?(state.game_state)
          )

        MessageRouter.send_to(state.connection_pid, spawn_packet)
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

  @doc "Reconciles a Homunculus entry event against current world visibility."
  @spec homunculus_entered_view(pos_integer(), map()) :: {:noreply, map()}
  def homunculus_entered_view(gid, state), do: reconcile_homunculus_visibility(gid, state)

  @doc "Reconciles a Homunculus leave event against current world visibility."
  @spec homunculus_left_view(pos_integer(), map()) :: {:noreply, map()}
  def homunculus_left_view(gid, state), do: reconcile_homunculus_visibility(gid, state)

  @doc "Sends one death packet and clears a visible Homunculus from this observer."
  @spec homunculus_died(pos_integer(), map()) :: {:noreply, map()}
  def homunculus_died(gid, state) do
    if MapSet.member?(state.game_state.visible_homunculi, gid) do
      MessageRouter.send_to(state.connection_pid, %UnitDespawn{
        gid: gid,
        reason: DespawnReason.died()
      })

      publish_homunculus_visibility(state, gid, false)
    else
      {:noreply, state}
    end
  end

  defp reconcile_homunculus_visibility(gid, state) do
    visible? = MapSet.member?(state.game_state.visible_homunculi, gid)

    case {current_homunculus(gid, state.game_state), visible?} do
      {{:visible, homunculus}, false} ->
        MessageRouter.send_to(state.connection_pid, HomunculusSpawnView.build(homunculus))
        send_active_icons(:homunculus, gid, state.game_state.character_id)
        publish_homunculus_visibility(state, gid, true)

      {:hidden, true} ->
        MessageRouter.send_to(state.connection_pid, %UnitDespawn{
          gid: gid,
          reason: DespawnReason.out_of_sight()
        })

        publish_homunculus_visibility(state, gid, false)

      _unchanged ->
        {:noreply, state}
    end
  end

  defp current_homunculus(gid, player) do
    with {:ok, {_module, %HomunculusState{} = homunculus, _pid}} <-
           UnitRegistry.get_unit(:homunculus, gid),
         {:ok, {x, y, map_name}} <- SpatialIndex.get_unit_position(:homunculus, gid),
         true <- map_name == player.map_name,
         true <- abs(x - player.x) + abs(y - player.y) <= player.view_range do
      {:visible, homunculus}
    else
      _ -> :hidden
    end
  end

  defp publish_homunculus_visibility(state, gid, visible?) do
    game_state = update_visible_homunculus(state.game_state, gid, visible?)
    UnitRegistry.update_unit_state(:player, game_state.character_id, game_state)
    {:noreply, %{state | game_state: game_state}}
  end

  defp update_visible_homunculus(game_state, gid, true) do
    %{game_state | visible_homunculi: MapSet.put(game_state.visible_homunculi, gid)}
  end

  defp update_visible_homunculus(game_state, gid, false) do
    %{game_state | visible_homunculi: MapSet.delete(game_state.visible_homunculi, gid)}
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
