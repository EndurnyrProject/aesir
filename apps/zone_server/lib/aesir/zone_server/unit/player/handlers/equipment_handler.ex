defmodule Aesir.ZoneServer.Unit.Player.Handlers.EquipmentHandler do
  @moduledoc """
  Orchestrates equip/unequip requests for a player session.

  Runs the pure inventory core, commits the change persist-first through
  `InventoryOps` (single transaction, memory advances only after the DB commit),
  then synchronizes the result to the client (equip/takeoff acks, recomputed stat
  params, weight) and emits the per-slot appearance changes to the equipping
  player and nearby players.

  On any failure — invalid index, unmet requirement, broken item, or a DB error —
  the in-memory state is left untouched and only a failure ack is sent.
  """

  require Logger

  import Bitwise

  alias Aesir.Commons.StatusParams
  alias Aesir.Net.EquipResult
  alias Aesir.Net.UnequipResult
  alias Aesir.ZoneServer.Mmo.ItemManagement.EquipLocation
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry, as: StatusRegistry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Inventory.Weight
  alias Aesir.ZoneServer.Unit.Player.Appearance
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Aesir.ZoneServer.Unit.Player.Handlers.StatusManager
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.StateCommit
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.StatusSync

  @equip_result_ok 0
  @equip_result_fail_level 1
  @equip_result_fail 2

  @unequip_result_success 0
  @unequip_result_failure 1

  @strip_statuses %{
    right_hand: :sc_stripweapon,
    left_hand: :sc_stripshield,
    armor: :sc_striparmor,
    head_top: :sc_striphelm
  }

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
      {:ok, new_inventory, {:equipped, _index, mask, _unequipped} = change} ->
        if any_slot_blocked?(game_state.character_id, mask) do
          send_packet(state, equip_failure_result(server_index, :fail))
          {:noreply, state}
        else
          commit_equip(server_index, new_inventory, change, state)
        end

      {:error, reason} ->
        send_packet(state, equip_failure_result(server_index, equip_failure(reason)))
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
        send_packet(state, unequip_failure_result(server_index))
        {:noreply, state}
    end
  end

  @doc """
  Force-unequips the item in `slot`, then applies the matching Divest status.
  """
  @spec handle_strip(atom(), keyword(), map()) :: {:noreply, map()}
  def handle_strip(slot, status_opts, %{game_state: game_state} = state) do
    status_id = Map.fetch!(@strip_statuses, slot)

    state =
      case equipped_item_in_slot(game_state.inventory, slot) do
        {server_index, _item} ->
          {:noreply, state} = handle_unequip(server_index, state)
          state

        nil ->
          state
      end

    # The Divest skill already rolled its own success; the status apply must not
    # double-dip the generic debuff resistance roll.
    :ok =
      StatusInterpreter.apply_status(
        :player,
        game_state.character_id,
        status_id,
        Keyword.put(status_opts, :bypass_resistance, true)
      )

    {:noreply, StatusManager.recalculate_after_status_change(state)}
  end

  defp commit_equip(
         server_index,
         new_inventory,
         {:equipped, _idx, mask, unequipped} = change,
         state
       ) do
    %{game_state: game_state} = state
    old_equipment = game_state.stats.equipment

    case InventoryOps.apply_change(
           game_state.character_id,
           game_state.inventory,
           new_inventory,
           change
         ) do
      {:ok, persisted} ->
        if weapon_unequipped?(game_state.inventory, unequipped) do
          remove_weapon_unequip_statuses(game_state.character_id)
        end

        updated_game_state = advance(game_state, persisted)

        send_packet(state, equip_success_result(server_index, mask))
        Enum.each(unequipped, &send_packet(state, unequip_success_result(&1, 0)))

        sync_after_change(updated_game_state, state)
        notify_appearance(state, old_equipment, updated_game_state)
        enforce_weapon_requirements(updated_game_state)

        {:noreply, StateCommit.commit(state, updated_game_state)}

      {:error, reason} ->
        Logger.warning("Equip persist failed for #{game_state.character_id}: #{inspect(reason)}")
        send_packet(state, equip_failure_result(server_index, :fail))
        {:noreply, state}
    end
  end

  defp commit_unequip(server_index, new_inventory, change, state) do
    %{game_state: game_state} = state
    mask = unequipped_mask(game_state.inventory, server_index)
    old_equipment = game_state.stats.equipment

    case InventoryOps.apply_change(
           game_state.character_id,
           game_state.inventory,
           new_inventory,
           change
         ) do
      {:ok, persisted} ->
        if right_hand?(mask) do
          remove_weapon_unequip_statuses(game_state.character_id)
        end

        updated_game_state = advance(game_state, persisted)

        send_packet(state, unequip_success_result(server_index, mask))
        sync_after_change(updated_game_state, state)
        notify_appearance(state, old_equipment, updated_game_state)
        enforce_weapon_requirements(updated_game_state)

        {:noreply, StateCommit.commit(state, updated_game_state)}

      {:error, reason} ->
        Logger.warning(
          "Unequip persist failed for #{game_state.character_id}: #{inspect(reason)}"
        )

        send_packet(state, unequip_failure_result(server_index))
        {:noreply, state}
    end
  end

  # Advances the in-memory state: install the persisted inventory, recompute
  # stats from the now-current equipped items, and refresh the walk speed, which
  # equipment can change through the `bSpeedRate` bonus.
  defp advance(game_state, persisted) do
    equipped = Map.values(Inventory.equipped_items(persisted))
    stats = Stats.calculate_stats(game_state.stats, game_state.character_id, equipped)

    %{
      game_state
      | inventory: persisted,
        stats: stats,
        walk_speed: StatusManager.walk_speed_for(stats)
    }
  end

  defp sync_after_change(game_state, %{connection_pid: connection_pid}) do
    StatusSync.send_stat_updates(connection_pid, game_state.stats)

    StatusSync.send_params(connection_pid, %{
      StatusParams.weight() => Weight.current_weight(game_state.inventory),
      StatusParams.max_weight() => Weight.max_weight(game_state.stats),
      StatusParams.speed() => game_state.walk_speed
    })
  end

  # Diffs the pre/post equipment and emits one SpriteChange per changed look slot
  # to the equipping player (direct, independent of the spatial index) and to
  # nearby players. The equipping player is in `visible_players`, so the broadcast
  # excludes self to avoid a double delivery. Slots whose view is unchanged (e.g.
  # view-0 ammo) emit nothing.
  defp notify_appearance(state, old_equipment, game_state) do
    game_state.character_id
    |> Appearance.diff(old_equipment, game_state.stats.equipment)
    |> Enum.each(fn change ->
      send_packet(state, change)
      Broadcast.to_visible_players(game_state, change, exclude_id: game_state.character_id)
    end)
  end

  # Ends any active status whose `require_weapon` list no longer includes the
  # currently wielded weapon type, derived the same way `Stats` derives it.
  defp enforce_weapon_requirements(game_state) do
    weapon_type = Stats.weapon_type(game_state.stats.equipment)
    StatusInterpreter.enforce_weapon_requirements(:player, game_state.character_id, weapon_type)
  end

  defp equipped_item_in_slot(inventory, slot) do
    bit = EquipLocation.location_bit(slot)

    Enum.find(Inventory.equipped_items(inventory), fn {_index, item} ->
      (item.equip &&& bit) != 0
    end)
  end

  defp any_slot_blocked?(character_id, mask) do
    Enum.any?(EquipLocation.bitmask_to_location_atoms(mask), fn slot ->
      StatusInterpreter.equip_blocked?(:player, character_id, slot)
    end)
  end

  defp unequipped_mask(inventory, server_index) do
    case Map.get(inventory, server_index) do
      nil -> 0
      item -> item.equip
    end
  end

  defp weapon_unequipped?(inventory, unequipped_indices) do
    Enum.any?(unequipped_indices, fn index ->
      inventory
      |> unequipped_mask(index)
      |> right_hand?()
    end)
  end

  defp right_hand?(mask) do
    :right_hand in EquipLocation.bitmask_to_location_atoms(mask)
  end

  defp remove_weapon_unequip_statuses(character_id) do
    :player
    |> StatusStorage.get_unit_statuses(character_id)
    |> Enum.each(fn status ->
      definition = StatusRegistry.get_definition(status.type)

      if definition && :remove_on_unequip_weapon in definition.flags do
        StatusInterpreter.remove_status(:player, character_id, status.type)
      end
    end)
  end

  defp equip_failure(:requirement_unmet), do: :level
  defp equip_failure(_reason), do: :fail

  # Equip result: a pure ack. The server index carries the +2 client offset,
  # mirroring legacy ZcAckWearEquip. `view_id` is retained in the proto but always
  # 0 — self appearance arrives via the self-targeted SpriteChange. Result codes
  # are preserved (0 ok / 1 fail-level / 2 fail).
  defp equip_success_result(server_index, wear_location) do
    %EquipResult{
      index: PlayerState.client_index(server_index),
      wear_location: wear_location,
      view_id: 0,
      result: @equip_result_ok
    }
  end

  defp equip_failure_result(server_index, :level) do
    %EquipResult{index: PlayerState.client_index(server_index), result: @equip_result_fail_level}
  end

  defp equip_failure_result(server_index, :fail) do
    %EquipResult{index: PlayerState.client_index(server_index), result: @equip_result_fail}
  end

  # Unequip result: rAthena inverts the flag (0 = success, 1 = failure), preserved here.
  defp unequip_success_result(server_index, wear_location) do
    %UnequipResult{
      index: PlayerState.client_index(server_index),
      wear_location: wear_location,
      result: @unequip_result_success
    }
  end

  defp unequip_failure_result(server_index) do
    %UnequipResult{
      index: PlayerState.client_index(server_index),
      result: @unequip_result_failure
    }
  end

  defp send_packet(%{connection_pid: connection_pid}, packet) do
    MessageRouter.send_to(connection_pid, packet)
  end
end
