defmodule Aesir.ZoneServer.Unit.Player.Handlers.PacketHandler do
  @moduledoc """
  Handles incoming packet processing for player sessions.
  Extracted from PlayerSession to improve modularity and maintainability.
  """

  require Logger

  alias Aesir.Commons.StatusParams
  alias Aesir.Commons.Utils.ServerTick
  alias Aesir.ZoneServer.Mmo.Leveling
  alias Aesir.ZoneServer.Mmo.StatPoint
  alias Aesir.ZoneServer.Packets.CzRequestChat
  alias Aesir.ZoneServer.Packets.CzRestart
  alias Aesir.ZoneServer.Packets.CzStatusChange
  alias Aesir.ZoneServer.Packets.CzUseSkill
  alias Aesir.ZoneServer.Packets.ZcAckReqname
  alias Aesir.ZoneServer.Packets.ZcAckReqnameall
  alias Aesir.ZoneServer.Packets.ZcEquipitemList
  alias Aesir.ZoneServer.Packets.ZcNormalItemlist
  alias Aesir.ZoneServer.Packets.ZcNotifyChat
  alias Aesir.ZoneServer.Packets.ZcNotifyTime
  alias Aesir.ZoneServer.Packets.ZcSkillinfoList
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Player.Handlers.HealthHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.StatAllocationHandler
  alias Aesir.ZoneServer.Unit.Player.StatusSync
  alias Aesir.ZoneServer.Unit.UnitRegistry

  # Chat constants
  @chat_max_size 255

  # Packet IDs
  @cz_notify_actorinit 0x007D
  @cz_request_time 0x007E
  @cz_request_time2 0x0360
  @cz_reqname2 0x0368
  @cz_request_move 0x035F
  @cz_request_act 0x0437
  @cz_use_skill 0x0113
  @cz_request_chat 0x008C
  @cz_restart 0x00B2
  @cz_status_change 0x00BB

  @doc """
  Processes an incoming packet for a player session.

  ## Parameters
    - packet_id: The packet ID (integer)
    - packet_data: The parsed packet data
    - state: The player session state

  ## Returns
    - {:noreply, updated_state} - Normal packet processing
    - {:noreply, state, timeout} - Processing with timeout
  """
  def handle_packet(packet_id, packet_data, state)

  # CZ_NOTIFY_ACTORINIT - Player finished loading map
  def handle_packet(
        @cz_notify_actorinit,
        _packet_data,
        %{connection_pid: connection_pid, game_state: game_state} = state
      ) do
    Logger.debug("Player #{game_state.character_id} finished loading map (LoadEndAck)")

    # Send weight updates to client
    StatusSync.send_params(connection_pid, %{
      StatusParams.weight() => 0,
      StatusParams.max_weight() => 1000
    })

    # Send experience and skill point status (sent later in LoadEndAck sequence)
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
    send_inventory_data(connection_pid, game_state.inventory_items)

    skill_list = ZcSkillinfoList.from_learned(game_state.stats.progression.learned_skills)
    send(connection_pid, {:send_packet, skill_list})

    send(self(), :spawn_player)

    {:noreply, state}
  end

  # CZ_REQUEST_TIME - Client requesting server time
  def handle_packet(@cz_request_time, _packet_data, %{connection_pid: connection_pid} = state) do
    server_tick = ServerTick.now()

    packet = %ZcNotifyTime{
      server_tick: server_tick
    }

    send(connection_pid, {:send_packet, packet})
    {:noreply, state}
  end

  # CZ_REQUEST_TIME2 - Alternative client time request
  def handle_packet(@cz_request_time2, _packet_data, %{connection_pid: connection_pid} = state) do
    server_tick = ServerTick.now()

    packet = %ZcNotifyTime{
      server_tick: server_tick
    }

    send(connection_pid, {:send_packet, packet})
    {:noreply, state}
  end

  # CZ_REQNAME2 - Client requesting entity name
  def handle_packet(
        @cz_reqname2,
        packet_data,
        %{
          game_state: game_state,
          connection_pid: connection_pid
        } = state
      ) do
    entity_id = packet_data.entity_id

    cond do
      entity_id == game_state.account_id ->
        packet = %ZcAckReqnameall{
          gid: game_state.account_id,
          name: game_state.character_name,
          party_name: "",
          guild_name: "",
          position_name: ""
        }

        send(connection_pid, {:send_packet, packet})

      MapSet.member?(game_state.visible_players, entity_id) ->
        case UnitRegistry.get_player_name(entity_id) do
          {:ok, player_name} ->
            packet = %ZcAckReqnameall{
              gid: entity_id,
              name: player_name,
              party_name: "",
              guild_name: "",
              position_name: ""
            }

            send(connection_pid, {:send_packet, packet})

          {:error, :not_found} ->
            Logger.warning(
              "Player #{entity_id} in visible set but not found in registry (lagged client)"
            )
        end

      MapSet.member?(game_state.visible_mobs, entity_id) ->
        case UnitRegistry.get_unit(:mob, entity_id) do
          {:ok, {_module, mob_state, _pid}} ->
            packet = %ZcAckReqname{
              char_id: entity_id,
              name: mob_state.mob_data.name
            }

            send(connection_pid, {:send_packet, packet})

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

  # CZ_REQUEST_MOVE - Player movement request
  def handle_packet(@cz_request_move, packet_data, state) do
    GenServer.cast(self(), {:request_move, packet_data.dest_x, packet_data.dest_y})
    {:noreply, state}
  end

  # CZ_REQUEST_ACT - Player action request (attack, sit, stand, etc.)
  def handle_packet(@cz_request_act, packet_data, state) do
    case packet_data.action do
      action when action in [0, 7] ->
        # Attack actions (0 = single attack, 7 = continuous attack)
        GenServer.cast(self(), {:request_attack, packet_data.target_id, action})

      2 ->
        # Sit down
        Logger.debug("Player sitting down")

      3 ->
        # Stand up
        Logger.debug("Player standing up")

      _ ->
        Logger.warning("Unknown action type in CZ_REQUEST_ACT: #{packet_data.action}")
    end

    {:noreply, state}
  end

  # CZ_USE_SKILL - Player casts a targeted skill
  def handle_packet(
        @cz_use_skill,
        %CzUseSkill{skill_id: skill_id, level: level, target_id: target_id},
        state
      ) do
    GenServer.cast(self(), {:use_skill, skill_id, level, target_id})
    {:noreply, state}
  end

  # CZ_RESTART - Death dialog response (respawn / return to char-select)
  def handle_packet(@cz_restart, %CzRestart{type: type}, state) do
    HealthHandler.handle_restart(type, state)
  end

  # CZ_REQUEST_CHAT - Player sending an area chat message
  def handle_packet(
        @cz_request_chat,
        %CzRequestChat{message: raw_message},
        %{game_state: game_state, connection_pid: connection_pid} = state
      ) do
    # 1. Message Validation
    # Max chat size from rAthena is 256 bytes (including null terminator)
    if byte_size(raw_message) > @chat_max_size do
      Logger.warning("Player #{game_state.character_id} sent a message exceeding maximum length.")
      # Optionally send an error message to the client
      {:noreply, state}
    else
      # rAthena expects "CharName : Message"
      # We need to extract the actual message and validate the prefix
      name_prefix = game_state.character_name <> " : "

      if String.starts_with?(raw_message, name_prefix) do
        chat_message = raw_message

        # 2. Construct ZcNotifyChat packet
        packet = %ZcNotifyChat{
          gid: game_state.character_id,
          message: chat_message
        }

        # 3. Broadcasting
        # To self
        send(connection_pid, {:send_packet, packet})

        # To visible players (excluding self)
        Broadcast.to_visible_players(game_state, packet, exclude_id: game_state.character_id)
      else
        Logger.warning(
          "Player #{game_state.character_id} sent a malformed chat message (expected '#{name_prefix}'). Message: '#{raw_message}'"
        )
      end

      {:noreply, state}
    end
  end

  # CZ_STATUS_CHANGE - Player spends status points to raise a stat
  def handle_packet(
        @cz_status_change,
        %CzStatusChange{status_id: status_id, amount: amount},
        state
      ) do
    StatAllocationHandler.handle_status_up(status_id, amount, state)
  end

  # Fallback for unknown packets
  def handle_packet(packet_id, _packet_data, state) do
    Logger.warning("Unhandled packet in PacketHandler: 0x#{Integer.to_string(packet_id, 16)}")
    {:noreply, state}
  end

  defp send_inventory_data(connection_pid, inventory_items) do
    # Send normal inventory items (non-equipped)
    normal_itemlist = ZcNormalItemlist.from_inventory_items(inventory_items)
    send(connection_pid, {:send_packet, normal_itemlist})

    # Send equipped items
    equipitem_list = ZcEquipitemList.from_inventory_items(inventory_items)
    send(connection_pid, {:send_packet, equipitem_list})
  end
end
