defmodule Aesir.ZoneServer.Unit.Player.Handlers.PickupHandler do
  @moduledoc """
  Handles a player's manual ground-item pickup.

  The flow validates distance and carry capacity, atomically claims the item from
  the owning `Map.Coordinator`, gives it through the existing inventory path, and
  always answers the client with a `PickupResult` — failures are reported, never
  silent.

  Distance is enforced by querying `GroundItemStore` for items within 2 cells of
  the player and looking for the requested
  `ground_id`: an item outside that range is simply absent, so it resolves to
  `TOO_FAR`. The capacity pre-check runs the same limits `InventoryOps.add/6`
  enforces, before the claim. If the give still fails after the claim (a DB
  error), the claimed item is re-placed on the ground (fresh ground id) and the
  player is told `FAILED` rather than wrongly told `OK`.
  """

  alias Aesir.Net.PickupResult
  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Mmo.ItemDrop.GroundItem
  alias Aesir.ZoneServer.Mmo.ItemDrop.GroundItemStore
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryManager
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps

  @pickup_range 2

  @doc """
  Resolves the pickup of `ground_id` for this session, sending exactly one
  `PickupResult` to the client. Returns the (possibly advanced) session state.
  """
  @spec handle_pickup(pos_integer(), map()) :: {:noreply, map()}
  def handle_pickup(ground_id, %{game_state: gs} = state) do
    with {:ok, %GroundItem{nameid: nameid, amount: amount}} <- find_in_range(gs, ground_id),
         {:ok, item_def} <- ItemManagement.get_item_by_id(nameid),
         :ok <- InventoryOps.can_add(gs.inventory, gs.stats, item_def, amount),
         {:ok, claimed} <- Coordinator.claim_item(gs.map_name, ground_id, gs.character_id) do
      give_claimed(item_def, amount, claimed, ground_id, state)
    else
      {:error, reason} ->
        reply(state, ground_id, pickup_code(reason))
        {:noreply, state}
    end
  end

  # The claim succeeded (item is off the ground), so a give failure here would
  # otherwise lose the item: re-place it (a fresh ground id, new ItemOnGround) so
  # the player can retry, and answer FAILED rather than a wrong OK.
  @spec give_claimed(ItemDefinition.t(), pos_integer(), GroundItem.t(), pos_integer(), map()) ::
          {:noreply, map()}
  defp give_claimed(
         item_def,
         amount,
         %GroundItem{} = claimed,
         ground_id,
         %{game_state: gs} = state
       ) do
    case InventoryManager.handle_give_item(item_def, amount, state) do
      {:ok, new_state} ->
        reply(new_state, ground_id, :OK)
        {:noreply, new_state}

      {:error, _reason, unchanged_state} ->
        Coordinator.drop_items(
          gs.map_name,
          [{claimed.nameid, claimed.amount, claimed.x, claimed.y}],
          claimed.x,
          claimed.y
        )

        reply(unchanged_state, ground_id, :FAILED)
        {:noreply, unchanged_state}
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

  @spec reply(map(), pos_integer(), atom()) :: :ok
  defp reply(%{connection_pid: pid}, ground_id, code) do
    MessageRouter.send_to(pid, %PickupResult{ground_id: ground_id, result: code})
  end
end
