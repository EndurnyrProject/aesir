defmodule Aesir.ZoneServer do
  @moduledoc """
  Connection handler for the Zone Server (Map Server).
  Processes zone/map packets and manages player sessions in the game world.
  """
  use Aesir.Commons.Network.Connection

  require Logger

  alias Aesir.Commons.SessionManager
  alias Aesir.ZoneServer.Packets.ZcAcceptEnter
  alias Aesir.ZoneServer.Packets.ZcAid
  alias Aesir.ZoneServer.Packets.ZcNotifyTime

  @impl Aesir.Commons.Network.Connection
  def handle_packet(0x0436, parsed_data, session_data) do
    Logger.info("CZ_ENTER2 received - Player entering zone server")

    Logger.debug(
      "Auth data: Account ID: #{parsed_data.account_id}, Char ID: #{parsed_data.char_id}"
    )

    case SessionManager.get_session(parsed_data.account_id) do
      {:ok, session} ->
        if session.login_id1 == parsed_data.auth_code do
          Logger.info("Session validated for account #{parsed_data.account_id}")

          updated_session =
            Map.merge(session_data, %{
              account_id: parsed_data.account_id,
              char_id: parsed_data.char_id,
              auth_code: parsed_data.auth_code,
              client_time: parsed_data.client_time,
              sex: parsed_data.sex
            })

          SessionManager.set_user_online(
            parsed_data.account_id,
            :zone_server,
            parsed_data.char_id,
            "prontera.gat"
          )

          current_time = System.system_time(:millisecond)

          accept_enter = %ZcAcceptEnter{
            start_time: current_time,
            x: 50,
            y: 50,
            dir: 4,
            font: 0
          }

          aid = %ZcAid{
            account_id: parsed_data.account_id
          }

          notify_time = %ZcNotifyTime{
            time: current_time
          }

          Logger.info("Sending initial zone packets to account #{parsed_data.account_id}")

          {:ok, updated_session, [accept_enter, aid, notify_time]}
        else
          Logger.warning("Auth code mismatch for account #{parsed_data.account_id}")
          {:error, :invalid_auth}
        end

      {:error, reason} ->
        Logger.warning("Session not found for account #{parsed_data.account_id}: #{reason}")
        # TODO: Send disconnect packet
        {:error, :invalid_session}
    end
  end

  def handle_packet(packet_id, _parsed_data, session_data) do
    Logger.warning("Unhandled packet in ZoneServer: 0x#{Integer.to_string(packet_id, 16)}")
    {:ok, session_data}
  end
end
