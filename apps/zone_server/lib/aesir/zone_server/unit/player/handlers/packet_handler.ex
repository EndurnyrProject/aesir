defmodule Aesir.ZoneServer.Unit.Player.Handlers.PacketHandler do
  @moduledoc """
  Handles incoming packet processing for player sessions.
  Extracted from PlayerSession to improve modularity and maintainability.
  """

  require Logger

  alias Aesir.Commons.StatusParams
  alias Aesir.ZoneServer.Packets.ZcAckReqnameall
  alias Aesir.ZoneServer.Packets.ZcEquipitemList
  alias Aesir.ZoneServer.Packets.ZcLongparChange
  alias Aesir.ZoneServer.Packets.ZcNormalItemlist
  alias Aesir.ZoneServer.Packets.ZcNotifyTime
  alias Aesir.ZoneServer.Packets.ZcParChange
  alias Aesir.ZoneServer.Unit.UnitRegistry

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
        0x007D,
        _packet_data,
        %{character: character, connection_pid: connection_pid, game_state: game_state} = state
      ) do
    Logger.debug("Player #{character.id} finished loading map (LoadEndAck)")

    # Send weight updates to client
    weight_updates = %{
      StatusParams.weight() => 0,
      StatusParams.max_weight() => 1000
    }

    Enum.each(weight_updates, fn {param_id, value} ->
      packet = build_status_packet(param_id, value)
      send(connection_pid, {:send_packet, packet})
    end)

    # Send experience and skill point status (sent later in LoadEndAck sequence)
    # TODO: the next base exp and job exp will come from a different place
    experience_updates = %{
      StatusParams.next_base_exp() => 100,
      StatusParams.next_job_exp() => 100,
      StatusParams.skill_point() => character.skill_point
    }

    Enum.each(experience_updates, fn {param_id, value} ->
      packet = build_status_packet(param_id, value)
      send(connection_pid, {:send_packet, packet})
    end)

    send_stat_updates(connection_pid, game_state.stats)
    send_inventory_data(connection_pid, game_state.inventory_items)

    # TODO: Send remaining initial game data to client
    # - Skill list

    send(self(), :spawn_player)

    {:noreply, state}
  end

  # CZ_REQUEST_TIME - Client requesting server time
  def handle_packet(0x007E, _packet_data, %{connection_pid: connection_pid} = state) do
    server_tick = System.system_time(:millisecond) |> rem(0x100000000)

    packet = %ZcNotifyTime{
      server_tick: server_tick
    }

    send(connection_pid, {:send_packet, packet})
    {:noreply, state}
  end

  # CZ_REQUEST_TIME2 - Alternative client time request
  def handle_packet(0x0360, _packet_data, %{connection_pid: connection_pid} = state) do
    server_tick = System.system_time(:millisecond) |> rem(0x100000000)

    packet = %ZcNotifyTime{
      server_tick: server_tick
    }

    send(connection_pid, {:send_packet, packet})
    {:noreply, state}
  end

  def handle_packet(
        0x0368,
        packet_data,
        %{character: character, connection_pid: connection_pid} = state
      ) do
    name =
      if packet_data.char_id == character.account_id do
        character.name
      else
        case find_player_name_by_account_id(packet_data.char_id) do
          {:ok, player_name} -> player_name
          {:error, :not_found} -> ""
        end
      end

    packet = %ZcAckReqnameall{
      gid: packet_data.char_id,
      name: name,
      party_name: "",
      guild_name: "",
      position_name: ""
    }

    send(connection_pid, {:send_packet, packet})
    {:noreply, state}
  end

  # CZ_REQUEST_MOVE - Player movement request
  def handle_packet(0x035F, packet_data, state) do
    GenServer.cast(self(), {:request_move, packet_data.dest_x, packet_data.dest_y})
    {:noreply, state}
  end

  # Fallback for unknown packets
  def handle_packet(packet_id, _packet_data, state) do
    Logger.warning("Unhandled packet in PacketHandler: 0x#{Integer.to_string(packet_id, 16)}")
    {:noreply, state}
  end

  def build_status_packet(param_id, value) do
    experience_params = [
      StatusParams.base_exp(),
      StatusParams.job_exp(),
      StatusParams.next_base_exp(),
      StatusParams.next_job_exp()
    ]

    if param_id in experience_params do
      %ZcLongparChange{var_id: param_id, value: value}
    else
      %ZcParChange{var_id: param_id, value: value}
    end
  end

  def send_stat_updates(connection_pid, stats) do
    status_updates = %{
      # Base stats
      StatusParams.str() => stats.base_stats.str,
      StatusParams.agi() => stats.base_stats.agi,
      StatusParams.vit() => stats.base_stats.vit,
      StatusParams.int() => stats.base_stats.int,
      StatusParams.dex() => stats.base_stats.dex,
      StatusParams.luk() => stats.base_stats.luk,

      # Derived stats
      StatusParams.max_hp() => stats.derived_stats.max_hp,
      StatusParams.max_sp() => stats.derived_stats.max_sp,
      StatusParams.hp() => stats.current_state.hp,
      StatusParams.sp() => stats.current_state.sp,
      StatusParams.aspd() => stats.derived_stats.aspd,

      # Combat stats
      StatusParams.hit() => stats.combat_stats.hit,
      StatusParams.flee1() => stats.combat_stats.flee,
      StatusParams.critical() => stats.combat_stats.critical,
      StatusParams.atk1() => stats.combat_stats.atk,
      StatusParams.def1() => stats.combat_stats.def,

      # Progression
      StatusParams.base_level() => stats.progression.base_level,
      StatusParams.job_level() => stats.progression.job_level,
      StatusParams.base_exp() => stats.progression.base_exp,
      StatusParams.job_exp() => stats.progression.job_exp
    }

    Enum.each(status_updates, fn {param_id, value} ->
      packet = build_status_packet(param_id, value)
      send(connection_pid, {:send_packet, packet})
    end)
  end

  defp send_inventory_data(connection_pid, inventory_items) do
    # Send normal inventory items (non-equipped)
    normal_itemlist = ZcNormalItemlist.from_inventory_items(inventory_items)
    send(connection_pid, {:send_packet, normal_itemlist})

    # Send equipped items
    equipitem_list = ZcEquipitemList.from_inventory_items(inventory_items)
    send(connection_pid, {:send_packet, equipitem_list})
  end

  defp find_player_name_by_account_id(account_id) do
    # Use efficient reverse lookup to find character ID from account ID
    case UnitRegistry.get_char_id_by_account(account_id) do
      {:ok, char_id} ->
        # Found the character, get the name
        UnitRegistry.get_player_name(char_id)

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end
end
