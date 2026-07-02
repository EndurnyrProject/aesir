defmodule Aesir.ZoneServer.Unit.Player.Handlers.InventoryManager do
  @moduledoc """
  Handles player inventory operations including loading and state management.
  """

  require Logger

  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Aesir.ZoneServer.Unit.Player.InventoryView
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
  """
  def load_character_inventory(character, game_state) do
    inventory_items = Inventory.load_inventory(character.id)
    inventory = PlayerState.from_list(inventory_items)
    equipped = Map.values(Inventory.equipped_items(inventory))
    stats = Stats.calculate_stats(game_state.stats, character.id, equipped)

    {:ok, %{game_state | inventory: inventory, stats: stats}}
  end

  @doc """
  Gives `amount` of `item_def` to this session's character.

  Runs the persist-first add through `InventoryOps`, advances
  `game_state.inventory`, and notifies the client with an `ItemAdded` for each
  affected slot. On `{:error, :overweight}` (or any DB error) the state is left
  untouched and nothing is sent.

  Returns `{:ok, new_state}` on success and `{:error, reason, state}` (original
  state) on failure so callers can react to a lost add (e.g. re-place a claimed
  ground item).
  """
  @spec handle_give_item(ItemDefinition.t(), pos_integer(), map()) ::
          {:ok, map()} | {:error, term(), map()}
  def handle_give_item(%ItemDefinition{} = item_def, amount, %{game_state: game_state} = state) do
    case InventoryOps.add(
           game_state.character_id,
           game_state.inventory,
           game_state.stats,
           item_def,
           amount
         ) do
      {:ok, persisted, change} ->
        notify_added(state.connection_pid, persisted, change)

        {:ok, %{state | game_state: %{game_state | inventory: persisted}}}

      {:error, reason} ->
        Logger.warning(
          "give_item failed for #{game_state.character_id} (#{item_def.id} x#{amount}): #{inspect(reason)}"
        )

        {:error, reason, state}
    end
  end

  @doc """
  Emits an `ItemAdded` to `connection_pid` for every slot `change` touched,
  reading each affected item from `inventory`.

  Shared by the give-item flow and any session-side commit that needs to notify
  the client of an inventory add it staged earlier (e.g. a skill that produces
  an item).
  """
  @spec notify_added(pid(), Inventory.t(), Inventory.change()) :: :ok
  def notify_added(connection_pid, inventory, change) do
    Enum.each(affected_indices(change), fn index ->
      item = PlayerState.get_by_index(inventory, index)
      MessageRouter.send_to(connection_pid, InventoryView.item_added(item, index))
    end)
  end

  @doc """
  Returns the session indices an add-type `change` touched.

  Shared with the cart move flow, which stages the same change descriptors and
  needs the affected destination slots to emit its `CartItemAdded` deltas.
  """
  @spec affected_indices(Inventory.change()) :: [non_neg_integer()]
  def affected_indices({:added, index, _item}), do: [index]
  def affected_indices({:stacked, index, _total}), do: [index]

  def affected_indices({:split, [{topped_index, _}, {new_index, _}]}),
    do: [topped_index, new_index]
end
