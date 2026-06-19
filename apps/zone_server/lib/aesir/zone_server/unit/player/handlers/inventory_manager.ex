defmodule Aesir.ZoneServer.Unit.Player.Handlers.InventoryManager do
  @moduledoc """
  Handles player inventory operations including loading and state management.
  """

  require Logger

  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats

  @doc """
  Loads inventory items for a character and sets up the initial game state.

  After building the indexed inventory map, stats are recomputed from the
  equipped items so the player's derived stats and appearance (weapon/shield
  view, ASPD, equipment bonuses) reflect their worn gear at spawn.

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
        inventory = PlayerState.from_list(inventory_items)
        equipped = Map.values(Inventory.equipped_items(inventory))
        stats = Stats.calculate_stats(game_state.stats, character.id, equipped)

        {:ok, %{game_state | inventory: inventory, stats: stats}}

      {:error, reason} ->
        Logger.error("Failed to load inventory for character #{character.id}: #{inspect(reason)}")
        {:error, :inventory_load_failed}
    end
  end
end
