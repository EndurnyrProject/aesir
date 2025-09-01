defmodule Aesir.ZoneServer.Unit.Player.Handlers.InventoryManager do
  @moduledoc """
  Handles player inventory operations including loading and state management.
  """

  require Logger

  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @doc """
  Loads inventory items for a character and sets up the initial game state.

  ## Parameters
    - character: The character data
    - game_state: The initial game state
    
  ## Returns
    - {:ok, updated_game_state} - Success with inventory loaded
    - {:error, reason} - Failure during inventory loading
  """
  def load_character_inventory(character, game_state) do
    case Inventory.load_inventory(character.id) do
      {:ok, inventory_items} ->
        updated_game_state =
          game_state
          |> PlayerState.set_inventory(inventory_items)

        {:ok, updated_game_state}

      {:error, reason} ->
        Logger.error("Failed to load inventory for character #{character.id}: #{inspect(reason)}")
        {:error, :inventory_load_failed}
    end
  end
end
