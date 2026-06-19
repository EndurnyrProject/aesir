defmodule Aesir.ZoneServer.Unit.Player.Handlers.EquipmentHandler do
  @moduledoc """
  Orchestrates equip/unequip requests for a player session.

  Runs the pure inventory core, commits the change persist-first through
  `InventoryOps` (single transaction, memory advances only after the DB commit),
  then synchronizes the result to the client (equip/takeoff acks, recomputed stat
  params, weight) and broadcasts the appearance change to nearby players.

  On any failure — invalid index, unmet requirement, broken item, or a DB error —
  the in-memory state is left untouched and only a failure ack is sent.
  """

  require Logger

  alias Aesir.Commons.StatusParams
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Packets.ZcAckTakeoffEquip
  alias Aesir.ZoneServer.Packets.ZcAckWearEquip
  alias Aesir.ZoneServer.Packets.ZcSpriteChange
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Inventory.Weight
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.StatusSync

  @doc """
  Handles an equip request for the item at `server_index` into `position`.
  """
  @spec handle_equip(non_neg_integer(), non_neg_integer(), map()) :: {:noreply, map()}
  def handle_equip(server_index, position, %{game_state: game_state} = state) do
    ctx = %{
      job_id: game_state.stats.progression.job_id,
      base_level: game_state.stats.progression.base_level
    }

    case Inventory.equip(game_state.inventory, server_index, position, ctx) do
      {:ok, new_inventory, {:equipped, _index, _mask, _unequipped} = change} ->
        commit_equip(server_index, new_inventory, change, state)

      {:error, reason} ->
        send_packet(state, ZcAckWearEquip.failure(server_index, equip_failure(reason)))
        {:noreply, state}
    end
  end

  @doc """
  Handles an unequip request for the item at `server_index`.
  """
  @spec handle_unequip(non_neg_integer(), map()) :: {:noreply, map()}
  def handle_unequip(server_index, %{game_state: game_state} = state) do
    case Inventory.unequip(game_state.inventory, server_index) do
      {:ok, new_inventory, {:unequipped, _index} = change} ->
        commit_unequip(server_index, new_inventory, change, state)

      {:error, _reason} ->
        send_packet(state, ZcAckTakeoffEquip.failure(server_index))
        {:noreply, state}
    end
  end

  defp commit_equip(
         server_index,
         new_inventory,
         {:equipped, _idx, mask, unequipped} = change,
         state
       ) do
    %{game_state: game_state} = state

    case InventoryOps.apply_change(
           game_state.character_id,
           game_state.inventory,
           new_inventory,
           change
         ) do
      {:ok, persisted} ->
        updated_game_state = advance(game_state, persisted)

        view_id = equipped_view(persisted, mask)
        send_packet(state, ZcAckWearEquip.success(server_index, mask, view_id))
        Enum.each(unequipped, &send_packet(state, ZcAckTakeoffEquip.success(&1, 0)))

        sync_after_change(updated_game_state, state)
        broadcast_appearance(updated_game_state)

        {:noreply, %{state | game_state: updated_game_state}}

      {:error, reason} ->
        Logger.warning("Equip persist failed for #{game_state.character_id}: #{inspect(reason)}")
        send_packet(state, ZcAckWearEquip.failure(server_index, :fail))
        {:noreply, state}
    end
  end

  defp commit_unequip(server_index, new_inventory, change, state) do
    %{game_state: game_state} = state
    mask = unequipped_mask(game_state.inventory, server_index)

    case InventoryOps.apply_change(
           game_state.character_id,
           game_state.inventory,
           new_inventory,
           change
         ) do
      {:ok, persisted} ->
        updated_game_state = advance(game_state, persisted)

        send_packet(state, ZcAckTakeoffEquip.success(server_index, mask))
        sync_after_change(updated_game_state, state)
        broadcast_appearance(updated_game_state)

        {:noreply, %{state | game_state: updated_game_state}}

      {:error, reason} ->
        Logger.warning(
          "Unequip persist failed for #{game_state.character_id}: #{inspect(reason)}"
        )

        send_packet(state, ZcAckTakeoffEquip.failure(server_index))
        {:noreply, state}
    end
  end

  # Advances the in-memory state: install the persisted inventory and recompute
  # stats from the now-current equipped items.
  defp advance(game_state, persisted) do
    equipped = Map.values(Inventory.equipped_items(persisted))
    stats = Stats.calculate_stats(game_state.stats, game_state.character_id, equipped)
    %{game_state | inventory: persisted, stats: stats}
  end

  defp sync_after_change(game_state, %{connection_pid: connection_pid}) do
    StatusSync.send_stat_updates(connection_pid, game_state.stats)

    StatusSync.send_params(connection_pid, %{
      StatusParams.weight() => Weight.current_weight(game_state.inventory),
      StatusParams.max_weight() => Weight.max_weight(game_state.stats)
    })
  end

  defp broadcast_appearance(game_state) do
    packet =
      ZcSpriteChange.weapon(
        game_state.account_id,
        Stats.weapon_view(game_state.stats.equipment),
        Stats.shield_view(game_state.stats.equipment)
      )

    Broadcast.to_visible_players(game_state, packet, exclude_id: game_state.character_id)
  end

  defp equipped_view(inventory, mask) do
    inventory
    |> Map.values()
    |> Enum.find(fn item -> item.equip == mask end)
    |> view_of()
  end

  defp view_of(nil), do: 0
  defp view_of(item), do: item_view(item.nameid)

  defp item_view(nameid) do
    case ItemManagement.get_item_by_id(nameid) do
      {:ok, %{view: view}} -> view
      {:error, :item_not_found} -> 0
    end
  end

  defp unequipped_mask(inventory, server_index) do
    case Map.get(inventory, server_index) do
      nil -> 0
      item -> item.equip
    end
  end

  defp equip_failure(:requirement_unmet), do: :level
  defp equip_failure(_reason), do: :fail

  defp send_packet(%{connection_pid: connection_pid}, packet) do
    send(connection_pid, {:send_packet, packet})
  end
end
