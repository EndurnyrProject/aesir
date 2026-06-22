defmodule Aesir.ZoneServer.Unit.Player.Handlers.PacketHandler do
  @moduledoc """
  Handles incoming packet processing for player sessions.
  Extracted from PlayerSession to improve modularity and maintainability.
  """

  require Logger

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Commons.StatusParams
  alias Aesir.Net.ActionRequest
  alias Aesir.Net.ChatMessage
  alias Aesir.Net.ChatRequest
  alias Aesir.Net.EquipItem
  alias Aesir.Net.GroundSkillCast
  alias Aesir.Net.InventoryList
  alias Aesir.Net.ItemAdded
  alias Aesir.Net.ItemRemoved
  alias Aesir.Net.MapLoaded
  alias Aesir.Net.MoveRequest
  alias Aesir.Net.NameRequest
  alias Aesir.Net.NameResponse
  alias Aesir.Net.Respawn
  alias Aesir.Net.SkillCast
  alias Aesir.Net.SkillInfo
  alias Aesir.Net.SkillList
  alias Aesir.Net.StatUp
  alias Aesir.Net.UnequipItem
  alias Aesir.ZoneServer.Gm.Dispatcher
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.ClientItemType
  alias Aesir.ZoneServer.Mmo.Leveling
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatPoint
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Inventory.Weight
  alias Aesir.ZoneServer.Unit.Player.Handlers.HealthHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.MovementHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.StatAllocationHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.StatusSync
  alias Aesir.ZoneServer.Unit.UnitRegistry

  # Chat constants
  @chat_max_size 255

  @doc """
  Processes a decoded protobuf message routed to the player session.

  Mirrors `handle_packet/3` for the QUIC + protobuf path. Per-feature struct
  clauses are added in their migration slices; everything else falls to a
  logging catch-all.
  """
  def handle_message(message, state)

  # MapLoaded - Player finished loading map (protobuf analogue of CZ_NOTIFY_ACTORINIT)
  def handle_message(%MapLoaded{}, state) do
    handle_map_loaded(state)
  end

  # MoveRequest - Player movement request (protobuf analogue of CZ_REQUEST_MOVE 0x035F)
  def handle_message(%MoveRequest{dest_x: dest_x, dest_y: dest_y}, state) do
    MovementHandler.handle_request_move(state, dest_x, dest_y)
  end

  # ActionRequest - Player action request (protobuf analogue of CZ_REQUEST_ACT 0x0437)
  def handle_message(%ActionRequest{target_id: target_id, action: action}, state) do
    case action do
      action when action in [0, 7] ->
        GenServer.cast(self(), {:request_attack, target_id, action})

      2 ->
        Logger.debug("Player sitting down")

      3 ->
        Logger.debug("Player standing up")

      _ ->
        Logger.warning("Unknown action type in ActionRequest: #{action}")
    end

    {:noreply, state}
  end

  # SkillCast - Player casts a targeted skill (protobuf analogue of CZ_USE_SKILL 0x0113)
  def handle_message(%SkillCast{skill_id: skill_id, level: level, target_id: target_id}, state) do
    GenServer.cast(self(), {:use_skill, skill_id, level, target_id})
    {:noreply, state}
  end

  # GroundSkillCast - Player casts a ground-targeted skill (protobuf analogue of
  # CZ_USE_SKILL_TOGROUND 0x0AF4)
  def handle_message(%GroundSkillCast{skill_id: skill_id, level: level, x: x, y: y}, state) do
    GenServer.cast(self(), {:use_skill_ground, skill_id, level, x, y})
    {:noreply, state}
  end

  # EquipItem - Player equips an item (protobuf analogue of CZ_REQ_WEAR_EQUIP 0x0998).
  # `index` is the client index (server index + 2); the session subtracts the offset.
  def handle_message(%EquipItem{index: index, position: position}, state) do
    GenServer.cast(self(), {:equip_item, index, position})
    {:noreply, state}
  end

  # UnequipItem - Player unequips an item (protobuf analogue of CZ_REQ_TAKEOFF_EQUIP 0x00AB).
  def handle_message(%UnequipItem{index: index}, state) do
    GenServer.cast(self(), {:unequip_item, index})
    {:noreply, state}
  end

  # StatUp - Player spends status points to raise a stat (protobuf analogue of
  # CZ_STATUS_CHANGE 0x00BB).
  def handle_message(%StatUp{stat_id: stat_id, amount: amount}, state) do
    StatAllocationHandler.handle_status_up(stat_id, amount, state)
  end

  # Respawn - Death-menu response: respawn or return to char select (protobuf
  # analogue of CZ_RESTART 0x00B2).
  def handle_message(%Respawn{type: type}, state) do
    HealthHandler.handle_restart(type, state)
  end

  # ChatRequest - Player sends an area chat message (protobuf analogue of
  # CZ_REQUEST_CHAT 0x008C). The client sends "CharName : message"; the prefix
  # and length are validated before the message is echoed to the sender and
  # broadcast to visible players.
  def handle_message(
        %ChatRequest{message: raw_message},
        %{game_state: game_state, connection_pid: connection_pid} = state
      ) do
    name_prefix = game_state.character_name <> " : "

    cond do
      byte_size(raw_message) > @chat_max_size ->
        Logger.warning(
          "Player #{game_state.character_id} sent a message exceeding maximum length."
        )

      command = gm_command(raw_message, name_prefix) ->
        Dispatcher.dispatch(command, %{game_state: game_state, connection_pid: connection_pid})

      String.starts_with?(raw_message, name_prefix) ->
        packet = %ChatMessage{gid: game_state.character_id, message: raw_message}
        MessageRouter.send_to(connection_pid, packet)
        Broadcast.to_visible_players(game_state, packet, exclude_id: game_state.character_id)

      true ->
        Logger.warning(
          "Player #{game_state.character_id} sent a malformed chat message (expected '#{name_prefix}'). Message: '#{raw_message}'"
        )
    end

    {:noreply, state}
  end

  # NameRequest - Client requests an entity's name (protobuf analogue of
  # CZ_REQNAME2 0x0368). Collapses the legacy player (ZC_ACK_REQNAMEALL) and
  # non-player (ZC_ACK_REQNAME) replies into one NameResponse: players fill
  # party/guild/position, mobs/NPCs leave them empty.
  def handle_message(
        %NameRequest{entity_id: entity_id},
        %{game_state: game_state, connection_pid: connection_pid} = state
      ) do
    cond do
      entity_id == game_state.character_id ->
        MessageRouter.send_to(connection_pid, %NameResponse{
          gid: game_state.character_id,
          name: game_state.character_name
        })

      MapSet.member?(game_state.visible_players, entity_id) ->
        case UnitRegistry.get_player_name(entity_id) do
          {:ok, player_name} ->
            MessageRouter.send_to(connection_pid, %NameResponse{gid: entity_id, name: player_name})

          {:error, :not_found} ->
            Logger.warning(
              "Player #{entity_id} in visible set but not found in registry (lagged client)"
            )
        end

      MapSet.member?(game_state.visible_mobs, entity_id) ->
        case UnitRegistry.get_unit(:mob, entity_id) do
          {:ok, {_module, mob_state, _pid}} ->
            MessageRouter.send_to(connection_pid, %NameResponse{
              gid: entity_id,
              name: mob_state.mob_data.name
            })

          {:error, :not_found} ->
            Logger.warning(
              "Mob #{entity_id} in visible set but not found in registry (lagged client)"
            )
        end

      true ->
        Logger.debug("Ignoring name request for entity #{entity_id} (not in view range)")
    end

    {:noreply, state}
  end

  def handle_message(message, state) do
    Logger.warning("Unhandled message in PacketHandler: #{inspect(message.__struct__)}")
    {:noreply, state}
  end

  # Returns the `@`-prefixed command string when `raw_message` carries the valid
  # name prefix and the remainder begins with `@`; otherwise nil. Keeps the chat
  # `cond` flat instead of nesting a check inside the broadcast branch.
  defp gm_command(raw_message, name_prefix) do
    case String.replace_prefix(raw_message, name_prefix, "") do
      ^raw_message -> nil
      "@" <> _ = command -> command
      _ -> nil
    end
  end

  defp handle_map_loaded(%{connection_pid: connection_pid, game_state: game_state} = state) do
    Logger.debug("Player #{game_state.character_id} finished loading map (LoadEndAck)")

    StatusSync.send_params(connection_pid, %{
      StatusParams.weight() => Weight.current_weight(game_state.inventory),
      StatusParams.max_weight() => Weight.max_weight(game_state.stats)
    })

    StatusSync.send_params(connection_pid, %{
      StatusParams.next_base_exp() => Leveling.next_base_exp(game_state.stats.progression),
      StatusParams.next_job_exp() => Leveling.next_job_exp(game_state.stats.progression),
      StatusParams.skill_point() => game_state.stats.progression.skill_point
    })

    base_stats = game_state.stats.base_stats

    StatusSync.send_params(connection_pid, %{
      StatusParams.status_point() => game_state.stats.progression.status_point,
      StatusParams.ustr() => StatPoint.cost_to_raise(base_stats.str),
      StatusParams.uagi() => StatPoint.cost_to_raise(base_stats.agi),
      StatusParams.uvit() => StatPoint.cost_to_raise(base_stats.vit),
      StatusParams.uint() => StatPoint.cost_to_raise(base_stats.int),
      StatusParams.udex() => StatPoint.cost_to_raise(base_stats.dex),
      StatusParams.uluk() => StatPoint.cost_to_raise(base_stats.luk)
    })

    StatusSync.send_stat_updates(connection_pid, game_state.stats)
    send_inventory_data(connection_pid, game_state.inventory)

    skill_list = build_skill_list(game_state.stats.progression.learned_skills)
    MessageRouter.send_to(connection_pid, skill_list)

    send(self(), :spawn_player)

    {:noreply, state}
  end

  defp build_skill_list(learned_skills) do
    skills =
      Enum.flat_map(learned_skills, fn {skill_id, level} ->
        case Catalog.by_id(skill_id) do
          {:ok, definition} -> [to_skill_info(definition, level)]
          :error -> []
        end
      end)

    %SkillList{skills: skills}
  end

  defp to_skill_info(%Definition{} = definition, level) do
    %SkillInfo{
      skill_id: definition.id,
      type: inf_for(definition.target_type),
      level: level,
      sp: Enum.at(definition.sp_cost, level - 1, 0),
      range: definition.range,
      name: definition.name |> Atom.to_string() |> String.upcase(),
      upgradable: false
    }
  end

  defp inf_for(:passive), do: 0
  defp inf_for(:target_enemy), do: 1
  defp inf_for(:ground), do: 2
  defp inf_for(:self), do: 4
  defp inf_for(:target_ally), do: 16

  @doc """
  Builds an `ItemAdded` for an item that just entered the inventory.

  Replaces the legacy `ZC_ITEM_PICKUP_ACK` success path: `server_index` carries the
  +2 client offset, `cards` collapses the four card slots, `type`/`look` are resolved
  from the item database and `result` is the success code (0).
  """
  @spec item_added(InventoryItem.t(), non_neg_integer()) :: ItemAdded.t()
  def item_added(%InventoryItem{} = item, server_index) do
    %ItemAdded{
      index: PlayerState.client_index(server_index),
      amount: item.amount,
      nameid: item.nameid,
      identified: item.identify == 1,
      attribute: item.attribute,
      refine: item.refine,
      cards: [item.card0, item.card1, item.card2, item.card3],
      location: item.equip,
      type: client_type(item.nameid),
      result: 0,
      expire_time: encode_expire_time(item.expire_time),
      look: item_view(item.nameid)
    }
  end

  @doc """
  Builds an `ItemRemoved` for an item that left (or was reduced in) the inventory.

  Replaces the legacy `ZC_DELETE_ITEM_FROM_BODY`: `server_index` carries the +2 client
  offset and `reason` is the rAthena delete-type code (0 = normal removal).
  """
  @spec item_removed(non_neg_integer(), pos_integer(), non_neg_integer()) :: ItemRemoved.t()
  def item_removed(server_index, amount, reason \\ 0) do
    %ItemRemoved{
      index: PlayerState.client_index(server_index),
      amount: amount,
      reason: reason
    }
  end

  # Collapses the legacy 4-packet inventory dump (ZC_INVENTORY_START/ITEMLIST_NORMAL/
  # ITEMLIST_EQUIP/END) into a single InventoryList on the Bulk channel. Items split
  # by `equip`: 0 -> normal (stackable), >0 -> equip (worn), both sorted by the unified
  # server index so the client index space (+2 offset) stays collision-free.
  defp send_inventory_data(connection_pid, inventory) do
    {equipped, stackable} =
      inventory
      |> Enum.sort_by(fn {index, _item} -> index end)
      |> Enum.split_with(fn {_index, item} -> item.equip > 0 end)

    list = %InventoryList{
      normal: Enum.map(stackable, fn {index, item} -> to_inventory_item(index, item) end),
      equip: Enum.map(equipped, fn {index, item} -> to_inventory_item(index, item) end)
    }

    MessageRouter.send_to(connection_pid, list)
  end

  @spec to_inventory_item(non_neg_integer(), InventoryItem.t()) :: Aesir.Net.InventoryItem.t()
  defp to_inventory_item(index, %InventoryItem{} = item) do
    %Aesir.Net.InventoryItem{
      index: PlayerState.client_index(index),
      nameid: item.nameid,
      type: client_type(item.nameid),
      amount: item.amount,
      location: item.equip,
      identified: item.identify == 1,
      attribute: item.attribute,
      refine: item.refine,
      cards: [item.card0, item.card1, item.card2, item.card3],
      expire_time: encode_expire_time(item.expire_time),
      bind_on_equip: item.bound,
      favorite: item.favorite == 1,
      look: item_view(item.nameid)
    }
  end

  @spec client_type(integer()) :: non_neg_integer()
  defp client_type(nameid) do
    case ItemManagement.get_item_by_id(nameid) do
      {:ok, %{type: type}} -> ClientItemType.to_client_type(type)
      {:error, :item_not_found} -> ClientItemType.to_client_type(:etc)
    end
  end

  @spec item_view(integer()) :: integer()
  defp item_view(nameid) do
    case ItemManagement.get_item_by_id(nameid) do
      {:ok, %{view: view}} -> view
      {:error, :item_not_found} -> 0
    end
  end

  @spec encode_expire_time(NaiveDateTime.t() | nil) :: non_neg_integer()
  defp encode_expire_time(nil), do: 0

  defp encode_expire_time(datetime) do
    datetime |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_unix()
  end
end
