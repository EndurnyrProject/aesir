defmodule Aesir.CharServer do
  @moduledoc """
  Connection handler for the Character Server.
  Processes character-related packets and manages character operations.
  """
  use Aesir.Commons.Network.Connection

  require Logger

  alias Aesir.CharServer.Auth
  alias Aesir.CharServer.CharacterManager
  alias Aesir.CharServer.Packets.HcAcceptEnter
  alias Aesir.CharServer.Packets.HcAcceptMakechar
  alias Aesir.CharServer.Packets.HcDeleteChar
  alias Aesir.CharServer.Packets.HcNotifyZonesvr
  alias Aesir.CharServer.Packets.HcRefuseEnter
  alias Aesir.CharServer.Packets.HcRefuseMakechar
  alias Aesir.Commons.InterServer.PubSub
  alias Aesir.Commons.SessionManager

  @impl Aesir.Commons.Network.Connection
  def handle_packet(0x0065, parsed_data, session_data) do
    Logger.info("Character list requested for account: #{parsed_data.aid}")

    case SessionManager.validate_session(
           parsed_data.aid,
           parsed_data.login_id1,
           parsed_data.login_id2
         ) do
      {:ok, session} ->
        updated_session =
          Map.merge(session_data, %{
            account_id: parsed_data.aid,
            login_id1: parsed_data.login_id1,
            login_id2: parsed_data.login_id2,
            sex: parsed_data.sex,
            authenticated: true,
            username: session.username
          })

        SessionManager.set_user_online(parsed_data.aid, :char_server)

        try do
          {:ok, characters} = CharacterManager.get_characters_by_account(parsed_data.aid)
          response = %HcAcceptEnter{characters: characters}
          {:ok, updated_session, [response]}
        rescue
          e ->
            Logger.error("Failed to get characters for account #{parsed_data.aid}: #{inspect(e)}")
            response = %HcRefuseEnter{reason: 0}
            {:ok, updated_session, [response]}
        end

      {:error, reason} ->
        Logger.warning("Session validation failed for account #{parsed_data.aid}: #{reason}")
        response = %HcRefuseEnter{reason: 0}
        {:ok, session_data, [response]}
    end
  end

  def handle_packet(0x0066, parsed_data, session_data) do
    account_id = session_data[:account_id]

    case CharacterManager.get_character_by_slot(account_id, parsed_data.slot) do
      {:ok, character} ->
        updated_session = Map.put(session_data, :selected_character, character)

        SessionManager.update_character_location(
          character.id,
          account_id,
          character.last_map,
          {character.last_x || 0, character.last_y || 0}
        )

        PubSub.broadcast_character_selected(account_id, character.id, character.name)

        zone_port = Application.get_env(:zone_server, :port, 5121)

        response = %HcNotifyZonesvr{
          char_id: character.id,
          map_name: character.last_map,

          # TODO: Get from zone server registry
          ip: {127, 0, 0, 1},
          port: zone_port
        }

        {:ok, updated_session, [response]}

      {:error, reason} ->
        Logger.error("Character selection failed for slot #{parsed_data.slot}: #{reason}")
        {:ok, session_data}
    end
  end

  def handle_packet(0x0067, parsed_data, session_data) do
    Logger.info("Character creation requested: #{parsed_data.name}")

    account_id = session_data[:account_id]

    case Auth.validate_account_permissions(account_id) do
      {:ok, _account_info} ->
        {:ok, current_characters} = CharacterManager.get_characters_by_account(account_id)

        case Auth.can_create_character?(account_id, length(current_characters)) do
          {:ok, _account_info} ->
            char_data = %{
              name: parsed_data.name,
              slot: parsed_data.slot,
              stats: %{
                str: parsed_data.str,
                agi: parsed_data.agi,
                vit: parsed_data.vit,
                int: parsed_data.int,
                dex: parsed_data.dex,
                luk: parsed_data.luk
              },
              hair: parsed_data.hair_style,
              hair_color: parsed_data.hair_color
            }

            case CharacterManager.create_character(account_id, char_data) do
              {:ok, character} ->
                PubSub.broadcast_character_created(account_id, character.id, character.name)

                response = %HcAcceptMakechar{character_data: character}
                {:ok, session_data, [response]}

              {:error, reason} ->
                Logger.error("Character creation failed: #{reason}")

                reason_code =
                  case reason do
                    :name_taken -> 0
                    :name_too_short -> 1
                    :name_too_long -> 1
                    :name_invalid_chars -> 1
                    :name_forbidden -> 1
                    :name_required -> 1
                    :stats_invalid_total -> 2
                    :stats_out_of_range -> 2
                    :invalid_slot -> 3
                    _ -> 4
                  end

                response = %HcRefuseMakechar{reason: reason_code}
                {:ok, session_data, [response]}
            end

          {:error, :character_slots_full} ->
            Logger.error("Character creation failed: character slots full")
            response = %HcRefuseMakechar{reason: 3}
            {:ok, session_data, [response]}

          {:error, reason} ->
            Logger.error("Character creation failed: #{reason}")
            response = %HcRefuseMakechar{reason: 4}
            {:ok, session_data, [response]}
        end

      {:error, reason} ->
        Logger.error("Character creation failed: account permission error #{reason}")
        response = %HcRefuseMakechar{reason: 4}
        {:ok, session_data, [response]}
    end
  end

  def handle_packet(0x0068, parsed_data, session_data) do
    Logger.info("Character deletion requested: #{parsed_data.char_id}")

    account_id = session_data[:account_id]

    case CharacterManager.get_character(parsed_data.char_id) do
      {:ok, character} ->
        case Auth.verify_character_ownership(account_id, character.account_id) do
          :ok ->
            # TODO: Add additional validation (guild membership, party, etc.)
            # TODO: Verify email if deletion protection is enabled

            case CharacterManager.delete_character(parsed_data.char_id) do
              # Success
              :ok ->
                response = %HcDeleteChar{result: 0}
                {:ok, session_data, [response]}

              {:error, reason} ->
                # Failure
                Logger.error("Character deletion failed: #{reason}")
                response = %HcDeleteChar{result: 1}
                {:ok, session_data, [response]}
            end

          {:error, :not_owner} ->
            # Failure
            Logger.warning(
              "Character deletion denied: character #{parsed_data.char_id} does not belong to account #{account_id}"
            )

            response = %HcDeleteChar{result: 1}
            {:ok, session_data, [response]}
        end

      {:error, :character_not_found} ->
        Logger.warning("Character deletion failed: character #{parsed_data.char_id} not found")
        response = %HcDeleteChar{result: 1}
        {:ok, session_data, [response]}
    end
  end

  def handle_packet(packet_id, _parsed_data, session_data) do
    Logger.warning("Unhandled packet in CharServer: 0x#{Integer.to_string(packet_id, 16)}")
    {:ok, session_data}
  end
end
