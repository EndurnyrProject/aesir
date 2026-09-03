defmodule Aesir.ZoneServer.Unit.Player.Handlers.CardHandler do
  @moduledoc """
  Orchestrates card target discovery and confirmed card compounding.
  """

  require Logger

  alias Aesir.Commons.StatusParams
  alias Aesir.Net.CardComposeRequest
  alias Aesir.Net.CardComposeResult
  alias Aesir.Net.CardTargetList
  alias Aesir.Net.ItemUseResult
  alias Aesir.ZoneServer.Mmo.ItemManagement.CardCompounding
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Unit.Inventory.Weight
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Aesir.ZoneServer.Unit.Player.InventoryView
  alias Aesir.ZoneServer.Unit.Player.PlayerEvents
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.Player.StateCommit
  alias Aesir.ZoneServer.Unit.Player.StatusSync

  @result_codes %{
    card_not_found: :CARD_COMPOSE_CARD_NOT_FOUND,
    not_a_card: :CARD_COMPOSE_NOT_A_CARD,
    card_source_equipped: :CARD_COMPOSE_SOURCE_EQUIPPED,
    target_not_found: :CARD_COMPOSE_TARGET_NOT_FOUND,
    same_inventory_slot: :CARD_COMPOSE_SAME_INVENTORY_SLOT,
    not_equipment: :CARD_COMPOSE_NOT_EQUIPMENT,
    target_unidentified: :CARD_COMPOSE_TARGET_UNIDENTIFIED,
    target_equipped: :CARD_COMPOSE_TARGET_EQUIPPED,
    location_mismatch: :CARD_COMPOSE_LOCATION_MISMATCH,
    no_free_socket: :CARD_COMPOSE_NO_FREE_SOCKET
  }

  @doc "Sends the compatible equipment targets for a validated card inventory slot."
  @spec open_picker(non_neg_integer(), SessionState.t() | map()) ::
          {:noreply, SessionState.t() | map()}
  def open_picker(server_index, %{connection_pid: connection_pid, game_state: game_state} = state) do
    case CardCompounding.eligible_targets(game_state.inventory, server_index) do
      {:ok, equipment_indices} ->
        MessageRouter.send_to(connection_pid, %CardTargetList{
          card_index: PlayerState.client_index(server_index),
          equipment_indices: Enum.map(equipment_indices, &PlayerState.client_index/1)
        })

      {:error, _reason} ->
        MessageRouter.send_to(connection_pid, %ItemUseResult{
          index: PlayerState.client_index(server_index),
          ok: false,
          reason: 3
        })
    end

    {:noreply, state}
  end

  @doc "Revalidates and compounds a confirmed card request."
  @spec handle_compose(CardComposeRequest.t(), SessionState.t()) ::
          {:noreply, SessionState.t()}
  def handle_compose(%CardComposeRequest{} = request, %{game_state: game_state} = state) do
    card_index = PlayerState.server_index(request.card_index)
    equipment_index = PlayerState.server_index(request.equipment_index)

    compose = CardCompounding.compound(game_state.inventory, card_index, equipment_index)

    if game_state.disable_item_use do
      send_compose_result(request, :CARD_COMPOSE_ITEM_USE_DISABLED, state)
    else
      case compose do
        {:ok, next_inventory, change} ->
          persist_compose(request, card_index, equipment_index, next_inventory, change, state)

        {:error, reason} ->
          send_compose_result(request, Map.fetch!(@result_codes, reason), state)
      end
    end
  end

  defp persist_compose(
         request,
         card_index,
         equipment_index,
         next_inventory,
         change,
         %{connection_pid: connection_pid, game_state: game_state} = state
       ) do
    case InventoryOps.apply_change(
           game_state.character_id,
           game_state.inventory,
           next_inventory,
           change
         ) do
      {:ok, persisted_inventory} ->
        updated_game_state = %{game_state | inventory: persisted_inventory}
        committed = StateCommit.commit(state, updated_game_state)
        equipment = Map.fetch!(persisted_inventory, equipment_index)

        MessageRouter.send_to(connection_pid, InventoryView.item_removed(card_index, 1))

        MessageRouter.send_to(connection_pid, %CardComposeResult{
          card_index: request.card_index,
          equipment_index: request.equipment_index,
          code: :CARD_COMPOSE_SUCCESS,
          cards: [equipment.card0, equipment.card1, equipment.card2, equipment.card3]
        })

        StatusSync.send_params(connection_pid, %{
          StatusParams.weight() => Weight.current_weight(persisted_inventory)
        })

        PlayerEvents.inventory_changed(game_state.character_id)
        {:noreply, committed}

      {:error, reason} ->
        source_row = Map.fetch!(game_state.inventory, card_index)
        target_row = Map.fetch!(game_state.inventory, equipment_index)

        Logger.warning(
          "Card compose persist failed for character #{game_state.character_id} " <>
            "(source inventory row #{source_row.id} at slot #{card_index}, " <>
            "target inventory row #{target_row.id} at slot #{equipment_index}): " <>
            inspect(reason)
        )

        send_compose_result(request, :CARD_COMPOSE_PERSISTENCE_FAILED, state)
    end
  end

  defp send_compose_result(request, code, %{connection_pid: connection_pid} = state) do
    MessageRouter.send_to(connection_pid, %CardComposeResult{
      card_index: request.card_index,
      equipment_index: request.equipment_index,
      code: code,
      cards: []
    })

    {:noreply, state}
  end
end
