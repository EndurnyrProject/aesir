defmodule Aesir.ZoneServer.Unit.Player.Handlers.InventoryManager do
  @moduledoc """
  Handles player inventory operations including loading and state management.
  """

  require Logger

  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Aesir.ZoneServer.Unit.Player.Handlers.PacketHandler
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

  @doc """
  Gives `amount` of `item_def` to this session's character.

  Runs the persist-first add through `InventoryOps`, advances
  `game_state.inventory`, and notifies the client with an `ItemAdded` for each
  affected slot. On `{:error, :overweight}` (or any DB error) the state is left
  untouched and nothing is sent.
  """
  @spec handle_give_item(ItemDefinition.t(), pos_integer(), map()) :: {:noreply, map()}
  def handle_give_item(%ItemDefinition{} = item_def, amount, %{game_state: game_state} = state) do
    case InventoryOps.add(
           game_state.character_id,
           game_state.inventory,
           game_state.stats,
           item_def,
           amount
         ) do
      {:ok, persisted, change} ->
        Enum.each(affected_indices(change), fn index ->
          item = PlayerState.get_by_index(persisted, index)
          MessageRouter.send_to(state.connection_pid, PacketHandler.item_added(item, index))
        end)

        {:noreply, %{state | game_state: %{game_state | inventory: persisted}}}

      {:error, reason} ->
        Logger.warning(
          "give_item failed for #{game_state.character_id} (#{item_def.id} x#{amount}): #{inspect(reason)}"
        )

        {:noreply, state}
    end
  end

  defp affected_indices({:added, index, _item}), do: [index]
  defp affected_indices({:stacked, index, _total}), do: [index]

  defp affected_indices({:split, [{topped_index, _}, {new_index, _}]}),
    do: [topped_index, new_index]
end
