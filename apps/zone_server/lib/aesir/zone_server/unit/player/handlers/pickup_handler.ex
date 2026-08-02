defmodule Aesir.ZoneServer.Unit.Player.Handlers.PickupHandler do
  @moduledoc """
  Handles a player's ground-item pickup, mirroring the move-to-attack flow.

  A pickup request resolves one of two ways:

    * the item is already within `@pickup_range` cells — pick it up immediately;
    * the item is farther away — set a pickup intent, walk to its cell, and pick
      it up when movement completes (`handle_reached_item/1`). A manual move while
      heading to an item cancels the intent (see `MovementHandler`).

  The pickup itself validates distance and carry capacity, atomically claims the
  item from the owning `Map.Coordinator`, gives it through the existing inventory
  path, and always answers the client with a `PickupResult` — failures are
  reported, never silent. The capacity pre-check runs the same limits
  `InventoryOps.add/6` enforces, before the claim. If the give still fails after
  the claim (a DB error), the claimed item is re-placed on the ground (fresh
  ground id) and the player is told `FAILED` rather than wrongly told `OK`.
  """

  alias Aesir.Net.PickupResult
  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Mmo.ItemDrop.GroundItem
  alias Aesir.ZoneServer.Mmo.ItemDrop.GroundItemStore
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Party.Manager, as: PartyManager
  alias Aesir.ZoneServer.Pathfinding
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryManager
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Aesir.ZoneServer.Unit.Player.Handlers.MovementHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @pickup_range 2

  @doc """
  Resolves a pickup request for `ground_id`. Picks the item up immediately when
  it is in range, otherwise walks the player to it (move-to-pickup). The walk
  finishes in `handle_reached_item/1`.
  """
  @spec handle_pickup(pos_integer(), map()) :: {:noreply, map()}
  def handle_pickup(ground_id, %{game_state: gs} = state) do
    case find_in_range(gs, ground_id) do
      {:ok, _item} ->
        do_pickup(ground_id, state)

      {:error, :too_far} ->
        walk_to_item(ground_id, state)
    end
  end

  @doc """
  Completes a move-to-pickup once the player has walked to the item: re-validates
  range, picks the item up, then clears the pickup intent and returns to idle.
  """
  @spec handle_reached_item(map()) :: {:noreply, map()}
  def handle_reached_item(%{game_state: %{pickup_target_id: nil}} = state) do
    {:noreply, state}
  end

  def handle_reached_item(%{game_state: %{pickup_target_id: ground_id}} = state) do
    {:noreply, picked_up} = do_pickup(ground_id, state)

    game_state =
      picked_up.game_state
      |> PlayerState.clear_pickup_intent()
      |> to_idle()

    {:noreply, %{picked_up | game_state: game_state}}
  end

  @spec do_pickup(pos_integer(), map()) :: {:noreply, map()}
  defp do_pickup(ground_id, %{game_state: gs} = state) do
    with {:ok, %GroundItem{nameid: nameid, amount: amount, identified: identified}} <-
           find_in_range(gs, ground_id),
         {:ok, item_def} <- ItemManagement.get_item_by_id(nameid),
         :ok <- InventoryOps.can_add(gs.inventory, gs.stats, item_def, amount),
         {:ok, claimed} <-
           Coordinator.claim_item(gs.map_name, ground_id, gs.character_id, party_ctx(gs)) do
      give_claimed(item_def, amount, identified, claimed, ground_id, state)
    else
      {:error, reason} ->
        reply(state, ground_id, pickup_code(reason))
        {:noreply, state}
    end
  end

  # Locates the requested item anywhere on the map and walks the player onto its
  # cell. Pathfinding is validated before committing the intent so an unreachable
  # item answers TOO_FAR instead of leaving the player stuck in :moving_to_item.
  @spec walk_to_item(pos_integer(), map()) :: {:noreply, map()}
  defp walk_to_item(ground_id, %{game_state: gs} = state) do
    with {:ok, %GroundItem{x: x, y: y}} <- GroundItemStore.get(gs.map_name, ground_id),
         {:ok, map_data} <- MapCache.get(gs.map_name),
         {:ok, [_ | _]} <- Pathfinding.find_path(map_data, {gs.x, gs.y}, {x, y}),
         {:ok, moving} <-
           PlayerState.transition_to(
             PlayerState.set_pickup_intent(gs, ground_id),
             :moving_to_item
           ) do
      MovementHandler.handle_request_move(%{state | game_state: moving}, x, y,
        pickup_initiated: true
      )
    else
      {:error, :gone} ->
        reply(state, ground_id, :GONE)
        {:noreply, state}

      _ ->
        reply(state, ground_id, :TOO_FAR)
        {:noreply, state}
    end
  end

  @spec to_idle(PlayerState.t()) :: PlayerState.t()
  defp to_idle(game_state) do
    case PlayerState.transition_to(game_state, :idle) do
      {:ok, idle} -> idle
      _ -> game_state
    end
  end

  # The claim succeeded (item is off the ground), so a give failure here would
  # otherwise lose the item: re-place it (a fresh ground id, new ItemOnGround) so
  # the player can retry, and answer FAILED rather than a wrong OK.
  @spec give_claimed(
          ItemDefinition.t(),
          pos_integer(),
          boolean(),
          GroundItem.t(),
          pos_integer(),
          map()
        ) :: {:noreply, map()}
  defp give_claimed(
         item_def,
         amount,
         identified,
         %GroundItem{} = claimed,
         ground_id,
         %{game_state: gs} = state
       ) do
    case InventoryManager.handle_give_item(item_def, amount, state, identified) do
      {:ok, new_state} ->
        reply(new_state, ground_id, :OK)
        {:noreply, new_state}

      {:error, _reason, unchanged_state} ->
        redrop_claimed(gs.map_name, claimed)

        reply(unchanged_state, ground_id, :FAILED)
        {:noreply, unchanged_state}
    end
  end

  @spec redrop_claimed(String.t(), GroundItem.t()) :: :ok
  defp redrop_claimed(map_name, %GroundItem{owners: nil} = item) do
    Coordinator.drop_items(
      map_name,
      [{item.nameid, item.amount, item.x, item.y, item.identified}],
      item.x,
      item.y
    )
  end

  defp redrop_claimed(map_name, %GroundItem{owners: owners, unlock_at: unlock_at} = item) do
    Coordinator.drop_items(
      map_name,
      [{item.nameid, item.amount, item.x, item.y, item.identified}],
      item.x,
      item.y,
      ownership: {owners, unlock_at}
    )
  end

  @spec party_ctx(%{party_id: non_neg_integer()}) :: %{
          party_id: non_neg_integer(),
          pickup_share: boolean()
        }
  defp party_ctx(%{party_id: 0}), do: %{party_id: 0, pickup_share: false}

  defp party_ctx(%{party_id: party_id}) when party_id > 0 do
    case PartyManager.get(party_id) do
      {:ok, state} -> %{party_id: party_id, pickup_share: state.item_pickup_share}
      {:error, _reason} -> %{party_id: 0, pickup_share: false}
    end
  end

  @spec find_in_range(map(), pos_integer()) :: {:ok, GroundItem.t()} | {:error, :too_far}
  defp find_in_range(gs, ground_id) do
    gs.map_name
    |> GroundItemStore.query_in_range(gs.x, gs.y, @pickup_range)
    |> Enum.find(&(&1.id == ground_id))
    |> case do
      %GroundItem{} = item -> {:ok, item}
      nil -> {:error, :too_far}
    end
  end

  @spec pickup_code(atom()) :: atom()
  defp pickup_code(:too_far), do: :TOO_FAR
  defp pickup_code(:overweight), do: :OVERWEIGHT
  defp pickup_code(:inventory_full), do: :INVENTORY_FULL
  defp pickup_code(:gone), do: :GONE
  defp pickup_code(:item_not_found), do: :GONE
  defp pickup_code(:protected), do: :LOOT_PROTECTED

  @spec reply(map(), pos_integer(), atom()) :: :ok
  defp reply(%{connection_pid: pid}, ground_id, code) do
    MessageRouter.send_to(pid, %PickupResult{ground_id: ground_id, result: code})
  end
end
