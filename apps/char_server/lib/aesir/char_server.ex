defmodule Aesir.CharServer do
  @moduledoc """
  Connection handler for the Character Server.
  Processes character-related packets and manages character operations.
  """
  use Aesir.Commons.Network.Connection

  require Logger

  alias Aesir.CharServer.Characters
  alias Aesir.CharServer.CharacterSession
  alias Aesir.Commons.SessionManager
  alias Aesir.CharServer.Packets.AccountIdAck
  alias Aesir.CharServer.Packets.HcAcceptEnter
  alias Aesir.CharServer.Packets.HcAcceptMakechar
  alias Aesir.CharServer.Packets.HcBlockCharacter
  alias Aesir.CharServer.Packets.HcCharacterList
  alias Aesir.CharServer.Packets.HcDeleteChar
  alias Aesir.CharServer.Packets.HcNotifyZonesvr
  alias Aesir.CharServer.Packets.HcRefuseEnter
  alias Aesir.CharServer.Packets.HcRefuseMakechar
  alias Aesir.CharServer.Packets.HcSecondPasswdLogin
  alias Aesir.CharServer.Packets.HcAckCharinfoPerPage
  alias Aesir.CharServer.Packets.ChReqCharDelete2
  alias Aesir.CharServer.Packets.HcCharDelete2Ack

  @impl Aesir.Commons.Network.Connection
  def handle_packet(0x0065, parsed_data, session_data) do
    Logger.info("Character list requested for account: #{parsed_data.aid}")

    account_id_ack = %AccountIdAck{account_id: parsed_data.aid}

    with {:ok, updated_session} <-
           CharacterSession.validate_character_session(
             parsed_data.aid,
             parsed_data.login_id1,
             parsed_data.login_id2,
             parsed_data.sex
           ),
         {:ok, characters} <- Characters.list_characters(parsed_data.aid, updated_session) do
      slot_config = %HcCharacterList{
        normal_slots: 9,
        premium_slots: 0,
        billing_slots: 0,
        producible_slots: 9,
        valid_slots: 15
      }

      char_list = %HcAcceptEnter{characters: characters}

      blocked_chars = %HcBlockCharacter{
        blocked_chars: []
      }

      pincode = %HcSecondPasswdLogin{
        seed: :rand.uniform(0xFFFF),
        account_id: parsed_data.aid,
        state: 0
      }

      {:ok, updated_session, [account_id_ack, slot_config, char_list, blocked_chars, pincode]}
    else
      {:error, reason}
      when reason in [
             :session_validation_failed,
             :session_account_mismatch,
             :session_not_authenticated,
             :invalid_session
           ] ->
        Logger.warning("Session validation failed for account #{parsed_data.aid}: #{reason}")
        response = %HcRefuseEnter{reason: 0}
        {:ok, session_data, [response]}

      {:error, reason} ->
        Logger.error(
          "Failed to get characters for account #{parsed_data.aid}: #{inspect(reason)}"
        )

        response = %HcRefuseEnter{reason: 0}
        {:ok, session_data, [response]}
    end
  end

  def handle_packet(0x0066, parsed_data, session_data) do
    account_id = session_data[:account_id]

    with {:ok, character} <- Characters.select_character(account_id, parsed_data.slot),
         {:ok, updated_session} <-
           CharacterSession.update_session_for_character_selection(
             session_data,
             character
           ),
         {:ok, zone_server} <- get_available_zone_server(character.last_map) do
      response = %HcNotifyZonesvr{
        char_id: character.id,
        map_name: character.last_map,
        ip: zone_server.ip,
        port: zone_server.port
      }

      {:ok, updated_session, [response]}
    else
      {:error, :no_zone_servers} ->
        Logger.error("No zone servers available for character selection")
        # TODO: Send proper error packet
        {:ok, session_data}

      {:error, reason} ->
        Logger.error("Character selection failed for slot #{parsed_data.slot}: #{reason}")
        {:ok, session_data}
    end
  end

  def handle_packet(0x0A39, parsed_data, session_data) do
    Logger.info("Character creation requested (modern): #{parsed_data.name}")

    account_id = session_data[:account_id]

    char_data = %{
      name: parsed_data.name,
      slot: parsed_data.slot,
      stats: %{
        str: 1,
        agi: 1,
        vit: 1,
        int: 1,
        dex: 1,
        luk: 1
      },
      hair: parsed_data.hair_style,
      hair_color: parsed_data.hair_color,
      starting_job: parsed_data.starting_job,
      sex: parsed_data.sex
    }

    case Characters.create_character(account_id, char_data) do
      {:ok, character} ->
        response = %HcAcceptMakechar{character_data: character}
        {:ok, session_data, [response]}

      {:error, reason} ->
        response = creation_error(reason)
        {:ok, session_data, [response]}
    end
  end

  def handle_packet(0x0068, parsed_data, session_data) do
    Logger.info("Character deletion requested: #{parsed_data.char_id}")

    account_id = session_data[:account_id]

    case Characters.delete_character(account_id, parsed_data.char_id) do
      :ok ->
        response = %HcDeleteChar{result: 0}
        {:ok, session_data, [response]}

      {:error, _reason} ->
        response = %HcDeleteChar{result: 1}
        {:ok, session_data, [response]}
    end
  end

  def handle_packet(0x09A1, _parsed_data, session_data) do
    Logger.info("Character list refresh requested")

    account_id = session_data[:account_id]

    with {:ok, characters} <- Characters.list_characters(account_id, session_data) do
      response = %HcAckCharinfoPerPage{characters: characters}
      {:ok, session_data, [response]}
    else
      {:error, reason} ->
        Logger.error("Failed to refresh character list: #{inspect(reason)}")
        # Send empty character list on error
        response = %HcAckCharinfoPerPage{characters: []}
        {:ok, session_data, [response]}
    end
  end

  def handle_packet(0x0187, parsed_data, session_data) do
    Logger.debug("Keepalive received from account: #{parsed_data.account_id}")
    {:ok, session_data}
  end

  def handle_packet(0x0827, %ChReqCharDelete2{char_id: char_id}, session_data) do
    Logger.info("Character deletion requested for ID: #{char_id}")

    case Characters.request_character_deletion(char_id, session_data.account_id) do
      {:ok, delete_date} ->
        response = HcCharDelete2Ack.success_result(char_id, delete_date)
        {:ok, session_data, [response]}

      {:error, err} ->
        response = HcCharDelete2Ack.error_result(char_id, err)
        {:ok, session_data, [response]}
    end
  end

  def handle_packet(packet_id, _parsed_data, session_data) do
    Logger.warning("Unhandled packet in CharServer: 0x#{Integer.to_string(packet_id, 16)}")
    {:ok, session_data}
  end

  defp creation_error(error_reason) do
    error_code =
      case error_reason do
        # Name-related errors
        :name_taken -> 0
        :name_too_short -> 1
        :name_too_long -> 1
        :name_invalid_chars -> 1
        :name_forbidden -> 1
        :name_required -> 1
        # Stats-related errors  
        :stats_invalid_total -> 2
        :stats_out_of_range -> 2
        # Slot-related errors
        :slot_taken -> 3
        :invalid_slot -> 3
        :character_slots_full -> 3
        # Permission errors
        :account_banned -> 4
        :account_not_confirmed -> 4
        :account_suspended -> 4
        # Generic failures
        _ -> 4
      end

    %HcRefuseMakechar{reason: error_code}
  end

  defp get_available_zone_server(_map_name) do
    # Get all zone servers from SessionManager
    case SessionManager.get_servers(:zone_server) do
      [] ->
        {:error, :no_zone_servers}

      servers ->
        # Find online zone servers
        online_servers =
          servers
          |> Enum.filter(fn server -> server.status == :online end)
          |> Enum.sort_by(fn server -> server.player_count end)

        case online_servers do
          [] ->
            {:error, :no_zone_servers}

          [zone_server | _] ->
            # For now, return the zone server with the least players
            # Later we can check if the server has the specific map
            {:ok, zone_server}
        end
    end
  end
end
