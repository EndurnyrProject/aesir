defmodule Aesir.CharServer do
  @moduledoc """
  QUIC connection handler for the Character server.

  Implements the `Aesir.Commons.Network.QuicConnection` behaviour: handles the
  Control-channel handshake (`Hello`/`HelloAck`) and the entry flow
  (`SessionAuth` -> `CharList`/`CharAuthFailed`), reusing the existing character
  and distributed-session machinery. This replaces the legacy RO binary packet
  path that ran over Ranch/TCP.
  """
  @behaviour Aesir.Commons.Network.QuicConnection

  require Logger

  alias Aesir.CharServer.CharacterMapper
  alias Aesir.CharServer.Characters
  alias Aesir.CharServer.CharacterSession
  alias Aesir.CharServer.Config.ServerInfo
  alias Aesir.Commons.SessionManager
  alias Aesir.Net.CharAuthFailed
  alias Aesir.Net.CharCreated
  alias Aesir.Net.CharCreateFailed
  alias Aesir.Net.CharList
  alias Aesir.Net.CharListRefresh
  alias Aesir.Net.CreateChar
  alias Aesir.Net.DeleteCharAck
  alias Aesir.Net.DeleteCharRequest
  alias Aesir.Net.Hello
  alias Aesir.Net.HelloAck
  alias Aesir.Net.SelectChar
  alias Aesir.Net.SessionAuth
  alias Aesir.Net.ZoneServerInfo

  # Character slots exposed to the client. Aesir has no VIP/billing tiers, so
  # normal/producible/valid all equal this. The client renders max(@max_chars/3, 1)
  # pages of 3 slots; matches rAthena MAX_CHARS for the latest packetver.
  @max_chars 15
  @protocol_version 1

  @impl true
  def handle_message(%Hello{protocol_version: version}, :control, session_data) do
    if version != @protocol_version do
      Logger.warning("Client protocol version #{version} does not match #{@protocol_version}")
    end

    response = %HelloAck{
      protocol_version: @protocol_version,
      accepted: version == @protocol_version
    }

    {:ok, session_data, [{:hello_ack, response}]}
  end

  def handle_message(
        %SessionAuth{
          account_id: account_id,
          login_id1: login_id1,
          login_id2: login_id2,
          sex: sex
        },
        :control,
        session_data
      ) do
    Logger.debug("Character list requested for account: #{account_id}")

    with {:ok, updated_session} <-
           CharacterSession.validate_character_session(account_id, login_id1, login_id2, sex),
         {:ok, characters} <- Characters.list_characters(account_id, updated_session) do
      {:ok, updated_session, [{:char_list, build_char_list(account_id, characters)}]}
    else
      {:error, reason}
      when reason in [
             :session_validation_failed,
             :session_account_mismatch,
             :session_not_authenticated,
             :invalid_session
           ] ->
        Logger.warning("Session validation failed for account #{account_id}: #{reason}")
        {:ok, session_data, [{:char_auth_failed, %CharAuthFailed{reason: 0}}]}

      {:error, reason} ->
        Logger.error("Failed to get characters for account #{account_id}: #{inspect(reason)}")
        {:ok, session_data, [{:char_auth_failed, %CharAuthFailed{reason: 0}}]}
    end
  end

  def handle_message(%SelectChar{slot: slot}, :control, session_data) do
    with {:ok, character} <- Characters.select_character(session_data[:account_id], slot),
         {:ok, updated_session} <-
           CharacterSession.update_session_for_character_selection(session_data, character),
         {:ok, zone_server} <- get_available_zone_server(character.last_map) do
      response = %ZoneServerInfo{
        char_id: character.id,
        map_name: character.last_map,
        ip: ip_to_string(zone_server.ip),
        port: zone_server.port
      }

      {:ok, updated_session, [{:zone_server_info, response}]}
    else
      {:error, :no_zone_servers} ->
        Logger.error("Character selection failed: no zone servers available")
        {:ok, session_data}

      {:error, :no_compatible_servers} ->
        Logger.error("Character selection failed: no compatible zone servers available")
        {:ok, session_data}

      {:error, reason} ->
        Logger.error("Character selection failed: #{inspect(reason)}")
        {:ok, session_data}
    end
  end

  def handle_message(
        %CreateChar{
          name: name,
          slot: slot,
          hair_color: hair_color,
          hair_style: hair_style,
          starting_job: starting_job,
          sex: sex
        },
        :control,
        session_data
      ) do
    char_data = %{
      name: name,
      slot: slot,
      stats: %{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
      hair: hair_style,
      hair_color: hair_color,
      starting_job: starting_job,
      sex: sex
    }

    case Characters.create_character(session_data[:account_id], char_data) do
      {:ok, character} ->
        {:ok, session_data,
         [{:char_created, %CharCreated{character: CharacterMapper.to_proto(character)}}]}

      {:error, reason} ->
        {:ok, session_data,
         [{:char_create_failed, %CharCreateFailed{reason_code: creation_error_code(reason)}}]}
    end
  end

  def handle_message(%DeleteCharRequest{char_id: char_id}, :control, session_data) do
    Logger.debug("Character deletion requested for ID: #{char_id}")

    case Characters.request_character_deletion(char_id, session_data.account_id) do
      {:ok, delete_unix} ->
        ack = %DeleteCharAck{char_id: char_id, result: 0, delete_date: delete_unix}
        {:ok, session_data, [{:delete_char_ack, ack}]}

      {:error, err} ->
        ack = %DeleteCharAck{char_id: char_id, result: delete_error_code(err), delete_date: 0}
        {:ok, session_data, [{:delete_char_ack, ack}]}
    end
  end

  def handle_message(%CharListRefresh{}, :control, session_data) do
    account_id = session_data[:account_id]

    case Characters.list_characters(account_id, session_data) do
      {:ok, characters} ->
        {:ok, session_data, [{:char_list, build_char_list(account_id, characters)}]}

      {:error, reason} ->
        Logger.error(
          "Failed to refresh character list for account #{account_id}: #{inspect(reason)}"
        )

        {:ok, session_data, [{:char_list, build_char_list(account_id, [])}]}
    end
  end

  def handle_message(message, channel, session_data) do
    Logger.warning("Unhandled #{inspect(message.__struct__)} on #{channel} channel")
    {:ok, session_data}
  end

  @spec build_char_list(non_neg_integer(), [Aesir.Commons.Models.Character.t()]) :: CharList.t()
  defp build_char_list(account_id, characters) do
    %CharList{
      account_id: account_id,
      normal_slots: @max_chars,
      premium_slots: 0,
      billing_slots: 0,
      producible_slots: @max_chars,
      valid_slots: @max_chars,
      page_count: max(div(@max_chars, 3), 1),
      pincode_enabled: false,
      characters: Enum.map(characters, &CharacterMapper.to_proto/1)
    }
  end

  defp ip_to_string(ip) when is_tuple(ip), do: ip |> :inet.ntoa() |> List.to_string()
  defp ip_to_string(ip) when is_binary(ip), do: ip

  defp get_available_zone_server(_map_name) do
    case get_available_servers() do
      {:ok, servers} -> select_server(servers)
      err -> err
    end
  end

  defp get_available_servers() do
    case SessionManager.get_servers(:zone_server) do
      [] ->
        {:error, :no_zone_servers}

      servers ->
        {:ok, servers}
    end
  end

  defp select_server(servers) do
    case servers
         |> Enum.filter(&compatible_server/1)
         |> Enum.sort_by(fn server -> server.player_count end) do
      [] -> {:error, :no_compatible_servers}
      [best_server | _] -> {:ok, best_server}
    end
  end

  defp compatible_server(server) do
    cluster_id = ServerInfo.cluster_id()
    server.status == :online && server.metadata[:cluster_id] == cluster_id
  end

  defp delete_error_code(:database_error), do: 1
  defp delete_error_code(:not_found), do: 2
  defp delete_error_code(:already_deleting), do: 3
  defp delete_error_code(:cannot_delete), do: 4
  defp delete_error_code(_), do: 1

  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp creation_error_code(reason) do
    case reason do
      :name_taken -> 0
      :name_too_short -> 1
      :name_too_long -> 1
      :name_invalid_chars -> 1
      :name_forbidden -> 1
      :name_required -> 1
      :stats_invalid_total -> 2
      :stats_out_of_range -> 2
      :slot_taken -> 3
      :invalid_slot -> 3
      :character_slots_full -> 3
      :account_banned -> 4
      :account_not_confirmed -> 4
      :account_suspended -> 4
      _ -> 4
    end
  end
end
