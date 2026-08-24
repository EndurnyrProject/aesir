defmodule Aesir.CharServerTest do
  use ExUnit.Case, async: true
  use Mimic

  import ExUnit.CaptureLog

  alias Aesir.CharServer
  alias Aesir.CharServer.Characters
  alias Aesir.CharServer.CharacterSession
  alias Aesir.CharServer.Config.ServerInfo
  alias Aesir.Commons.GameMode
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.SessionManager
  alias Aesir.Net.Character, as: NetCharacter
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

  setup :set_mimic_private
  setup :verify_on_exit!

  describe "handshake" do
    test "reports renewal mode" do
      stub(GameMode, :mode, fn -> :renewal end)

      assert {:ok, %{},
              [{:hello_ack, hello_ack = %HelloAck{accepted: true, protocol_version: 1}}]} =
               CharServer.handle_message(
                 %Hello{protocol_version: 1, build: "dev"},
                 :control,
                 %{}
               )

      assert Map.fetch!(hello_ack, :mode) == :GAME_MODE_RENEWAL
      assert Aesir.Net.GameMode.encode(hello_ack.mode) == 0
    end

    test "reports pre-renewal mode" do
      stub(GameMode, :mode, fn -> :pre_renewal end)

      assert {:ok, %{},
              [{:hello_ack, hello_ack = %HelloAck{accepted: true, protocol_version: 1}}]} =
               CharServer.handle_message(
                 %Hello{protocol_version: 1, build: "dev"},
                 :control,
                 %{}
               )

      assert Map.fetch!(hello_ack, :mode) == :GAME_MODE_PRE_RENEWAL
      assert Aesir.Net.GameMode.encode(hello_ack.mode) == 1
    end

    test "rejects a Hello with an unsupported protocol version" do
      log =
        capture_log(fn ->
          assert {:ok, %{}, [{:hello_ack, %HelloAck{accepted: false}}]} =
                   CharServer.handle_message(
                     %Hello{protocol_version: 99, build: "dev"},
                     :control,
                     %{}
                   )
        end)

      assert log =~ "does not match"
    end
  end

  describe "session authentication" do
    test "returns the mapped character list on a valid session" do
      updated_session = %{account_id: 1001, authenticated: true, username: "testuser"}

      character = character_fixture(last_map: "prontera.gat")

      CharacterSession
      |> stub(:validate_character_session, fn 1001, 123, 456, 0 ->
        {:ok, updated_session}
      end)

      Characters
      |> stub(:list_characters, fn 1001, ^updated_session ->
        {:ok, [character]}
      end)

      assert {:ok, ^updated_session, [{:char_list, char_list}]} =
               CharServer.handle_message(
                 %SessionAuth{account_id: 1001, login_id1: 123, login_id2: 456, sex: 0},
                 :control,
                 %{}
               )

      assert %CharList{
               account_id: 1001,
               normal_slots: 15,
               premium_slots: 0,
               billing_slots: 0,
               producible_slots: 15,
               valid_slots: 15,
               page_count: 5,
               pincode_enabled: false,
               characters: [%NetCharacter{gid: 5, name: "TestChar", sex: 1}]
             } = char_list
    end

    test "returns CharAuthFailed when session validation fails" do
      CharacterSession
      |> stub(:validate_character_session, fn 1001, 123, 456, 0 ->
        {:error, :invalid_credentials}
      end)

      log =
        capture_log(fn ->
          assert {:ok, %{}, [{:char_auth_failed, %CharAuthFailed{reason: 0}}]} =
                   CharServer.handle_message(
                     %SessionAuth{account_id: 1001, login_id1: 123, login_id2: 456, sex: 0},
                     :control,
                     %{}
                   )
        end)

      assert log =~ "Session validation failed for account 1001: invalid_credentials"
    end

    test "returns CharAuthFailed when the character list cannot be retrieved" do
      updated_session = %{account_id: 1001, authenticated: true}

      CharacterSession
      |> stub(:validate_character_session, fn 1001, 123, 456, 0 ->
        {:ok, updated_session}
      end)

      Characters
      |> stub(:list_characters, fn 1001, ^updated_session ->
        {:error, :database_error}
      end)

      log =
        capture_log(fn ->
          assert {:ok, %{}, [{:char_auth_failed, %CharAuthFailed{reason: 0}}]} =
                   CharServer.handle_message(
                     %SessionAuth{account_id: 1001, login_id1: 123, login_id2: 456, sex: 0},
                     :control,
                     %{}
                   )
        end)

      assert log =~ "Failed to get characters for account 1001"
    end
  end

  describe "character selection" do
    test "returns zone server info for a valid character slot" do
      session_data = %{account_id: 1001, authenticated: true, username: "testuser"}

      character = character_fixture(last_map: "prontera", last_x: 150, last_y: 180)

      cluster_id = ServerInfo.cluster_id()

      zone_entry = %{
        status: :online,
        player_count: 5,
        ip: {127, 0, 0, 1},
        port: 5121,
        metadata: %{cluster_id: cluster_id}
      }

      Characters
      |> stub(:select_character, fn 1001, 0 -> {:ok, character} end)

      SessionManager
      |> stub(:get_servers, fn :zone_server -> [zone_entry] end)
      |> stub(:issue_zone_token, fn 1001, 5 -> {:ok, <<1, 2, 3, 4>>} end)

      assert {:ok, updated_session, [{:zone_server_info, zone_info}]} =
               CharServer.handle_message(%SelectChar{slot: 0}, :control, session_data)

      assert %ZoneServerInfo{
               char_id: 5,
               map_name: "prontera",
               ip: "127.0.0.1",
               port: 5121,
               auth_token: <<1, 2, 3, 4>>
             } = zone_info

      assert updated_session[:selected_character_id] == 5
      assert updated_session[:last_map] == "prontera"
    end

    test "logs error and returns session unchanged when no zone servers are available" do
      session_data = %{account_id: 1001, authenticated: true, username: "testuser"}

      character = character_fixture(last_map: "prontera", last_x: 150, last_y: 180)

      Characters
      |> stub(:select_character, fn 1001, 0 -> {:ok, character} end)

      SessionManager
      |> stub(:get_servers, fn :zone_server -> [] end)

      log =
        capture_log(fn ->
          assert {:ok, ^session_data} =
                   CharServer.handle_message(%SelectChar{slot: 0}, :control, session_data)
        end)

      assert log =~ "no zone servers available"
    end
  end

  describe "character creation" do
    test "returns CharCreated with mapped character on success" do
      session_data = %{account_id: 1001}
      character = character_fixture(id: 7, name: "Newbie")

      Characters
      |> stub(:create_character, fn 1001, _char_data -> {:ok, character} end)

      assert {:ok, ^session_data, [{:char_created, %CharCreated{character: net_char}}]} =
               CharServer.handle_message(
                 %CreateChar{
                   name: "Newbie",
                   slot: 1,
                   hair_color: 2,
                   hair_style: 3,
                   starting_job: 0,
                   sex: 0
                 },
                 :control,
                 session_data
               )

      assert %NetCharacter{gid: 7, name: "Newbie"} = net_char
    end

    test "passes the correct char_data map to create_character" do
      session_data = %{account_id: 1001}
      character = character_fixture(id: 7, name: "Newbie")

      Characters
      |> stub(:create_character, fn 1001, char_data ->
        assert char_data == %{
                 name: "Newbie",
                 slot: 1,
                 stats: %{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
                 hair: 3,
                 hair_color: 2,
                 starting_job: 0,
                 sex: 0
               }

        {:ok, character}
      end)

      assert {:ok, ^session_data, [{:char_created, %CharCreated{}}]} =
               CharServer.handle_message(
                 %CreateChar{
                   name: "Newbie",
                   slot: 1,
                   hair_color: 2,
                   hair_style: 3,
                   starting_job: 0,
                   sex: 0
                 },
                 :control,
                 session_data
               )
    end

    test "returns CharCreateFailed with reason_code 0 on :name_taken" do
      session_data = %{account_id: 1001}

      Characters
      |> stub(:create_character, fn 1001, _char_data -> {:error, :name_taken} end)

      assert {:ok, ^session_data, [{:char_create_failed, %CharCreateFailed{reason_code: 0}}]} =
               CharServer.handle_message(
                 %CreateChar{
                   name: "Taken",
                   slot: 0,
                   hair_color: 0,
                   hair_style: 0,
                   starting_job: 0,
                   sex: 0
                 },
                 :control,
                 session_data
               )
    end

    test "returns CharCreateFailed with reason_code 3 on :slot_taken" do
      session_data = %{account_id: 1001}

      Characters
      |> stub(:create_character, fn 1001, _char_data -> {:error, :slot_taken} end)

      assert {:ok, ^session_data, [{:char_create_failed, %CharCreateFailed{reason_code: 3}}]} =
               CharServer.handle_message(
                 %CreateChar{
                   name: "Any",
                   slot: 1,
                   hair_color: 0,
                   hair_style: 0,
                   starting_job: 0,
                   sex: 0
                 },
                 :control,
                 session_data
               )
    end

    test "returns CharCreateFailed with reason_code 4 on :account_banned" do
      session_data = %{account_id: 1001}

      Characters
      |> stub(:create_character, fn 1001, _char_data -> {:error, :account_banned} end)

      assert {:ok, ^session_data, [{:char_create_failed, %CharCreateFailed{reason_code: 4}}]} =
               CharServer.handle_message(
                 %CreateChar{
                   name: "Any",
                   slot: 0,
                   hair_color: 0,
                   hair_style: 0,
                   starting_job: 0,
                   sex: 0
                 },
                 :control,
                 session_data
               )
    end
  end

  describe "character deletion" do
    test "returns DeleteCharAck with result 0 and non-zero delete_date on success" do
      session_data = %{account_id: 1001}
      delete_unix = DateTime.to_unix(~U[2026-07-20 12:00:00Z])

      Characters
      |> stub(:request_character_deletion, fn 42, 1001 -> {:ok, delete_unix} end)

      assert {:ok, ^session_data, [{:delete_char_ack, ack}]} =
               CharServer.handle_message(
                 %DeleteCharRequest{char_id: 42},
                 :control,
                 session_data
               )

      assert %DeleteCharAck{char_id: 42, result: 0, delete_date: ^delete_unix} = ack
      assert ack.delete_date > 0
    end

    test "returns DeleteCharAck with result 1 and delete_date 0 on :database_error" do
      session_data = %{account_id: 1001}

      Characters
      |> stub(:request_character_deletion, fn 42, 1001 -> {:error, :database_error} end)

      assert {:ok, ^session_data,
              [{:delete_char_ack, %DeleteCharAck{char_id: 42, result: 1, delete_date: 0}}]} =
               CharServer.handle_message(
                 %DeleteCharRequest{char_id: 42},
                 :control,
                 session_data
               )
    end

    test "returns DeleteCharAck with result 2 and delete_date 0 on :not_found" do
      session_data = %{account_id: 1001}

      Characters
      |> stub(:request_character_deletion, fn 42, 1001 -> {:error, :not_found} end)

      assert {:ok, ^session_data,
              [{:delete_char_ack, %DeleteCharAck{char_id: 42, result: 2, delete_date: 0}}]} =
               CharServer.handle_message(
                 %DeleteCharRequest{char_id: 42},
                 :control,
                 session_data
               )
    end

    test "returns DeleteCharAck with result 3 and delete_date 0 on :already_deleting" do
      session_data = %{account_id: 1001}

      Characters
      |> stub(:request_character_deletion, fn 42, 1001 -> {:error, :already_deleting} end)

      assert {:ok, ^session_data,
              [{:delete_char_ack, %DeleteCharAck{char_id: 42, result: 3, delete_date: 0}}]} =
               CharServer.handle_message(
                 %DeleteCharRequest{char_id: 42},
                 :control,
                 session_data
               )
    end

    test "returns DeleteCharAck with result 4 and delete_date 0 on :cannot_delete" do
      session_data = %{account_id: 1001}

      Characters
      |> stub(:request_character_deletion, fn 42, 1001 -> {:error, :cannot_delete} end)

      assert {:ok, ^session_data,
              [{:delete_char_ack, %DeleteCharAck{char_id: 42, result: 4, delete_date: 0}}]} =
               CharServer.handle_message(
                 %DeleteCharRequest{char_id: 42},
                 :control,
                 session_data
               )
    end
  end

  describe "character list refresh" do
    test "returns CharList with characters on success" do
      session_data = %{account_id: 1001, authenticated: true}
      character = character_fixture([])

      Characters
      |> stub(:list_characters, fn 1001, ^session_data -> {:ok, [character]} end)

      assert {:ok, ^session_data, [{:char_list, char_list}]} =
               CharServer.handle_message(%CharListRefresh{}, :control, session_data)

      assert %CharList{characters: [%NetCharacter{}]} = char_list
    end

    test "returns CharList with empty characters and logs error on failure" do
      session_data = %{account_id: 1001, authenticated: true}

      Characters
      |> stub(:list_characters, fn 1001, ^session_data -> {:error, :database_error} end)

      log =
        capture_log(fn ->
          assert {:ok, ^session_data, [{:char_list, char_list}]} =
                   CharServer.handle_message(%CharListRefresh{}, :control, session_data)

          assert %CharList{characters: []} = char_list
        end)

      assert log =~ "Failed to refresh character list"
    end
  end

  describe "authentication gating" do
    test "rejects an unauthenticated DeleteCharRequest without crashing" do
      log =
        capture_log(fn ->
          assert {:ok, %{}, [{:char_auth_failed, %CharAuthFailed{reason: 0}}]} =
                   CharServer.handle_message(%DeleteCharRequest{char_id: 42}, :control, %{})
        end)

      assert log =~ "Rejected unauthenticated DeleteCharRequest"
    end

    test "rejects an unauthenticated SelectChar" do
      log =
        capture_log(fn ->
          assert {:ok, %{}, [{:char_auth_failed, %CharAuthFailed{reason: 0}}]} =
                   CharServer.handle_message(%SelectChar{slot: 0}, :control, %{})
        end)

      assert log =~ "Rejected unauthenticated SelectChar"
    end

    test "closes the connection after repeated SessionAuth failures" do
      CharacterSession
      |> stub(:validate_character_session, fn 1001, 123, 456, 0 ->
        {:error, :invalid_credentials}
      end)

      auth = %SessionAuth{account_id: 1001, login_id1: 123, login_id2: 456, sex: 0}

      capture_log(fn ->
        session =
          Enum.reduce(1..4, %{}, fn _i, session_data ->
            assert {:ok, new_session, [{:char_auth_failed, _}]} =
                     CharServer.handle_message(auth, :control, session_data)

            new_session
          end)

        assert {:error, :too_many_auth_failures} =
                 CharServer.handle_message(auth, :control, session)
      end)
    end
  end

  describe "catch-all" do
    test "logs and ignores an unhandled message" do
      session_data = %{account_id: 1001}

      log =
        capture_log(fn ->
          assert {:ok, ^session_data} =
                   CharServer.handle_message(%CharList{}, :control, session_data)
        end)

      assert log =~ "Unhandled"
    end
  end

  defp character_fixture(overrides) do
    base = %Character{
      id: 5,
      name: "TestChar",
      class: 0,
      base_level: 1,
      job_level: 1,
      base_exp: 0,
      job_exp: 0,
      zeny: 0,
      hp: 40,
      max_hp: 40,
      sp: 11,
      max_sp: 11,
      str: 1,
      agi: 1,
      vit: 1,
      int: 1,
      dex: 1,
      luk: 1,
      status_point: 0,
      skill_point: 0,
      hair: 1,
      hair_color: 0,
      clothes_color: 0,
      weapon: 0,
      shield: 0,
      head_top: 0,
      head_mid: 0,
      head_bottom: 0,
      robe: 0,
      char_num: 0,
      last_map: "prontera",
      sex: "M",
      option: 0,
      karma: 0,
      manner: 0,
      rename: 0,
      delete_date: nil
    }

    struct(base, overrides)
  end
end
