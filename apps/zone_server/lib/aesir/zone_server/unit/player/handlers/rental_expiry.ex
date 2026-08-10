defmodule Aesir.ZoneServer.Unit.Player.Handlers.RentalExpiry do
  @moduledoc """
  Removes rental inventory items whose expiry has elapsed during a player session.
  """

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Unit.Player.Handlers.EquipmentHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Aesir.ZoneServer.Unit.Player.InventoryView
  alias Aesir.ZoneServer.Unit.Player.StateCommit
  alias Aesir.ZoneServer.Unit.Rental

  @doc """
  Removes every expired rental from the player's inventory.
  """
  @spec sweep(map(), NaiveDateTime.t()) :: map()
  def sweep(%{game_state: game_state} = state, now) do
    expired_items =
      Enum.filter(game_state.inventory, fn {_index, item} -> Rental.expired?(item, now) end)

    case expired_items do
      [] ->
        state

      _ ->
        state = Enum.reduce(expired_items, state, &remove_expired_item/2)
        StateCommit.commit(state, state.game_state)
    end
  end

  defp remove_expired_item({index, item}, state) do
    state = unequip_if_worn(index, item, state)
    remove_and_notify(index, item.amount, state)
  end

  defp unequip_if_worn(index, item, state) do
    if InventoryItem.equipped?(item) do
      {:noreply, state} = EquipmentHandler.handle_unequip(index, state)
      false = InventoryItem.equipped?(Map.fetch!(state.game_state.inventory, index))
      state
    else
      state
    end
  end

  defp remove_and_notify(index, amount, %{game_state: game_state} = state) do
    {:ok, inventory, _change} =
      InventoryOps.remove(game_state.character_id, game_state.inventory, index, amount)

    MessageRouter.send_to(state.connection_pid, InventoryView.item_removed(index, amount))
    %{state | game_state: %{game_state | inventory: inventory}}
  end
end
