defmodule Aesir.ZoneServer do
  @moduledoc """
  Connection handler for the Zone Server (Map Server).
  Processes zone/map packets and manages player sessions in the game world.
  """
  use Aesir.Commons.Network.Connection

  require Logger

  alias Aesir.Commons.SessionManager
  alias Aesir.ZoneServer.CharacterLoader
  alias Aesir.ZoneServer.Packets.ZcAcceptEnter
  alias Aesir.ZoneServer.Packets.ZcAid
  alias Aesir.ZoneServer.Unit.Player.PlayerSupervisor

  @impl Aesir.Commons.Network.Connection
  def handle_packet(0x0B1C, _parsed_data, session_data) do
    {:ok, session_data}
  end

  def handle_packet(0x08C9, _parsed_data, session_data) do
    Logger.debug("Cash shop list requested by account #{session_data.account_id}")

    # TODO: Implement cash shop
    # For now, just acknowledge the request without sending items
    # The client should handle an empty cash shop gracefully

    {:ok, session_data}
  end

  def handle_packet(0x0436, parsed_data, session_data) do
    Logger.debug(
      "Auth data: Account ID: #{parsed_data.account_id}, Char ID: #{parsed_data.char_id}"
    )

    with {:ok, session} <- SessionManager.get_session(parsed_data.account_id),
         :ok <- validate_auth_code(session, parsed_data),
         updated_session <- build_session_data(session_data, parsed_data),
         {:ok, character} <-
           CharacterLoader.load_character(parsed_data.char_id, parsed_data.account_id),
         :ok <-
           SessionManager.set_user_online(
             parsed_data.account_id,
             :zone_server,
             parsed_data.char_id,
             "#{character.last_map}"
           ),
         {:ok, player_pid} <-
           PlayerSupervisor.start_player(%{character: character, connection_pid: self()}),
         final_session <- Map.put(updated_session, :player_session_pid, player_pid),
         packets <- build_initial_packets(parsed_data.account_id, character) do
      Logger.info("Started PlayerSession #{inspect(player_pid)} for char #{parsed_data.char_id}")
      Logger.info("Sending initial zone packets to account #{parsed_data.account_id}")

      {:ok, final_session, packets}
    else
      {:error, :session_not_found} = error ->
        Logger.warning("Session not found for account #{parsed_data.account_id}")
        error

      {:error, :invalid_auth} = error ->
        Logger.warning("Auth code mismatch for account #{parsed_data.account_id}")
        error

      {:error, :character_load_failed} = error ->
        Logger.error("Failed to load character #{parsed_data.char_id}")
        error

      {:error, reason} = error ->
        Logger.error("Failed to handle CZ_ENTER2: #{inspect(reason)}")
        error
    end
  end

  def handle_packet(packet_id, parsed_data, session_data) do
    case get_player_session_pid(session_data) do
      {:ok, pid} ->
        send(pid, {:packet, packet_id, parsed_data})
        {:ok, session_data}

      :no_session ->
        Logger.warning(
          "Unhandled packet in ZoneServer: 0x#{Integer.to_string(packet_id, 16)} (no player session) - killing connection"
        )

        {:error, {:unhandled_packet, packet_id}}
    end
  end

  def handle_info({:send_packet, packet}, state) do
    Logger.debug("ZoneServer.handle_info: Sending packet #{inspect(packet.__struct__)}")

    # Build the packet data and add to write buffer
    module = packet.__struct__
    packet_data = module.build(packet)

    # Send the packet data directly using the transport
    case state.transport.send(state.socket, packet_data) do
      :ok ->
        {:noreply, state}

      {:error, reason} ->
        Logger.error("Failed to send packet: #{inspect(reason)}")
        {:stop, {:error, reason}, state}
    end
  end

  def handle_info(:player_session_terminated, state) do
    {:stop, :normal, state}
  end

  def handle_info(msg, state) do
    Logger.error("ZoneServer received unhandled message: #{inspect(msg)}")

    {:noreply, state}
  end

  def terminate(_reason, state) do
    with {:ok, pid} <- get_player_session_pid(state.session_data) do
      send(pid, :connection_closed)
    end

    :ok
  end

  defp validate_auth_code(session, parsed_data) do
    if session.login_id1 == parsed_data.auth_code do
      Logger.debug("Session validated for account #{parsed_data.account_id}")
      :ok
    else
      {:error, :invalid_auth}
    end
  end

  defp build_session_data(session_data, parsed_data) do
    Map.merge(session_data, %{
      account_id: parsed_data.account_id,
      char_id: parsed_data.char_id,
      auth_code: parsed_data.auth_code,
      client_time: parsed_data.client_time,
      sex: parsed_data.sex
    })
  end

  defp build_initial_packets(account_id, character) do
    current_time = System.system_time(:millisecond)

    [
      %ZcAcceptEnter{
        start_time: current_time,
        x: character.last_x,
        y: character.last_y,
        dir: 4,
        font: 0
      },
      %ZcAid{
        account_id: account_id
      }
    ]
  end

  defp get_player_session_pid(session_data) do
    case Map.get(session_data, :player_session_pid) do
      pid when is_pid(pid) -> {:ok, pid}
      _ -> :no_session
    end
  end
end
