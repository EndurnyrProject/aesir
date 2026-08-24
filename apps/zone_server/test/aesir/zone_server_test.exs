defmodule Aesir.ZoneServerTest do
  use ExUnit.Case, async: true
  use Mimic

  @moduletag :capture_log

  import ExUnit.CaptureLog

  alias Aesir.Commons.GameMode
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.SessionManager
  alias Aesir.Net.DamageDealt
  alias Aesir.Net.EnterAck
  alias Aesir.Net.Hello
  alias Aesir.Net.HelloAck
  alias Aesir.Net.HomunculusInspectCommand
  alias Aesir.Net.HomunculusRequest
  alias Aesir.Net.HomunculusResult
  alias Aesir.Net.MapLoaded
  alias Aesir.Net.SessionAuth
  alias Aesir.Net.TimeSync
  alias Aesir.Net.TimeSyncAck
  alias Aesir.ZoneServer
  alias Aesir.ZoneServer.CharacterLoader
  alias Aesir.ZoneServer.Unit.Player.PlayerSupervisor

  setup :set_mimic_private
  setup :verify_on_exit!

  describe "handshake" do
    test "reports renewal mode" do
      stub(GameMode, :mode, fn -> :renewal end)

      assert {:ok, %{client_capabilities: []},
              [
                {:hello_ack,
                 hello_ack = %HelloAck{accepted: true, protocol_version: 1, capabilities: []}}
              ]} =
               ZoneServer.handle_message(
                 %Hello{protocol_version: 1, build: "dev"},
                 :control,
                 %{}
               )

      assert Map.fetch!(hello_ack, :mode) == :GAME_MODE_RENEWAL
      assert Aesir.Net.GameMode.encode(hello_ack.mode) == 0
    end

    test "reports pre-renewal mode" do
      stub(GameMode, :mode, fn -> :pre_renewal end)

      assert {:ok, %{client_capabilities: []},
              [
                {:hello_ack,
                 hello_ack = %HelloAck{accepted: true, protocol_version: 1, capabilities: []}}
              ]} =
               ZoneServer.handle_message(
                 %Hello{protocol_version: 1, build: "dev"},
                 :control,
                 %{}
               )

      assert Map.fetch!(hello_ack, :mode) == :GAME_MODE_PRE_RENEWAL
      assert Aesir.Net.GameMode.encode(hello_ack.mode) == 1
    end

    test "ignores unknown capabilities" do
      assert {:ok, %{client_capabilities: []}, [{:hello_ack, %HelloAck{capabilities: []}}]} =
               ZoneServer.handle_message(
                 %Hello{protocol_version: 1, capabilities: [:FEATURE_CAPABILITY_FUTURE]},
                 :control,
                 %{}
               )
    end

    test "negotiates supported capabilities into connection session data" do
      hello = %Hello{
        protocol_version: 1,
        capabilities: [
          :FEATURE_CAPABILITY_SKILL_TEXT_INPUT,
          :FEATURE_CAPABILITY_FUTURE
        ]
      }

      assert {:ok, %{client_capabilities: [:FEATURE_CAPABILITY_SKILL_TEXT_INPUT]},
              [
                {:hello_ack,
                 %HelloAck{
                   accepted: true,
                   protocol_version: 1,
                   capabilities: [:FEATURE_CAPABILITY_SKILL_TEXT_INPUT]
                 }}
              ]} = ZoneServer.handle_message(hello, :control, %{})
    end

    test "rejects a Hello with an unsupported protocol version" do
      assert {:ok, %{client_capabilities: []},
              [{:hello_ack, %HelloAck{accepted: false, protocol_version: 1, capabilities: []}}]} =
               ZoneServer.handle_message(
                 %Hello{protocol_version: 99, build: "dev"},
                 :control,
                 %{}
               )
    end
  end

  describe "session auth / zone entry" do
    test "valid SessionAuth starts the player and returns an EnterAck" do
      Mimic.copy(SessionManager)
      Mimic.copy(CharacterLoader)
      Mimic.copy(PlayerSupervisor)

      character = %Character{
        id: 50,
        account_id: 100,
        last_map: "prontera",
        last_x: 155,
        last_y: 180
      }

      stub(SessionManager, :validate_session, fn 100, 1234, 5678 ->
        {:ok, %{login_id1: 1234, login_id2: 5678}}
      end)

      stub(SessionManager, :consume_zone_token, fn 100, 50, _token -> :ok end)
      stub(CharacterLoader, :load_character, fn 50, 100 -> {:ok, character} end)
      stub(SessionManager, :set_user_online, fn 100, :zone_server, 50, "prontera" -> :ok end)
      player_pid = spawn(fn -> Process.sleep(:infinity) end)

      stub(PlayerSupervisor, :start_player, fn args ->
        assert args.client_capabilities == []
        {:ok, player_pid}
      end)

      auth = %SessionAuth{
        account_id: 100,
        login_id1: 1234,
        login_id2: 5678,
        sex: 0,
        char_id: 50,
        zone_auth_token: <<9, 9, 9>>
      }

      assert {:ok, session, [{:enter_ack, %EnterAck{account_id: 100, x: 155, y: 180}}]} =
               ZoneServer.handle_message(auth, :control, %{})

      assert session.player_session_pid == player_pid
    end

    test "passes only negotiated capabilities to the player session" do
      Mimic.copy(SessionManager)
      Mimic.copy(CharacterLoader)
      Mimic.copy(PlayerSupervisor)

      character = %Character{id: 50, account_id: 100, last_map: "prontera"}
      stub(SessionManager, :validate_session, fn 100, 1234, 5678 -> {:ok, %{}} end)
      stub(SessionManager, :consume_zone_token, fn 100, 50, _token -> :ok end)
      stub(CharacterLoader, :load_character, fn 50, 100 -> {:ok, character} end)
      stub(SessionManager, :set_user_online, fn 100, :zone_server, 50, "prontera" -> :ok end)
      player_pid = spawn(fn -> Process.sleep(:infinity) end)

      expect(PlayerSupervisor, :start_player, fn args ->
        assert args.client_capabilities == [:FEATURE_CAPABILITY_SKILL_TEXT_INPUT]
        {:ok, player_pid}
      end)

      {:ok, hello_session, _responses} =
        ZoneServer.handle_message(
          %Hello{protocol_version: 1, capabilities: [:FEATURE_CAPABILITY_SKILL_TEXT_INPUT]},
          :control,
          %{}
        )

      auth = %SessionAuth{
        account_id: 100,
        login_id1: 1234,
        login_id2: 5678,
        char_id: 50,
        zone_auth_token: <<9, 9, 9>>
      }

      assert {:ok, %{player_session_pid: ^player_pid}, [_]} =
               ZoneServer.handle_message(auth, :control, hello_session)
    end

    test "invalid credentials return an error" do
      Mimic.copy(SessionManager)

      stub(SessionManager, :validate_session, fn 100, 1234, 5678 ->
        {:error, :invalid_credentials}
      end)

      auth = %SessionAuth{account_id: 100, login_id1: 1234, login_id2: 5678, sex: 0, char_id: 50}

      capture_log(fn ->
        assert {:error, :invalid_credentials} = ZoneServer.handle_message(auth, :control, %{})
      end)
    end

    test "rejects SessionAuth with an invalid zone token when enforcement is on" do
      Mimic.copy(SessionManager)

      stub(SessionManager, :validate_session, fn 100, 1234, 5678 ->
        {:ok, %{login_id1: 1234, login_id2: 5678}}
      end)

      stub(SessionManager, :consume_zone_token, fn 100, 50, _token ->
        {:error, :invalid_zone_token}
      end)

      auth = %SessionAuth{
        account_id: 100,
        login_id1: 1234,
        login_id2: 5678,
        sex: 0,
        char_id: 50,
        zone_auth_token: <<>>
      }

      capture_log(fn ->
        assert {:error, :invalid_zone_token} = ZoneServer.handle_message(auth, :control, %{})
      end)
    end
  end

  describe "time sync" do
    test "replies with the current server tick" do
      assert {:ok, %{}, [{:time_sync_ack, %TimeSyncAck{server_tick: tick}}]} =
               ZoneServer.handle_message(%TimeSync{client_tick: 42}, :control, %{})

      assert is_integer(tick)
    end
  end

  describe "Homunculus channel gate" do
    test "rejects every wrong channel before PlayerSession with a correlated gameplay result" do
      test_pid = self()
      player_pid = spawn(fn -> route_loop(test_pid) end)
      session = %{player_session_pid: player_pid}

      request = %HomunculusRequest{
        request_id: 987,
        command: {:inspect, %HomunculusInspectCommand{}}
      }

      for channel <- [:control, :world, :bulk, :snapshots] do
        assert {:ok, ^session} = ZoneServer.handle_message(request, channel, session)

        assert_receive {:send, :gameplay,
                        {:homunculus_result,
                         %HomunculusResult{
                           request_id: 987,
                           success: false,
                           error: :HOMUNCULUS_ERROR_WRONG_CHANNEL,
                           state: nil
                         }}}

        refute_receive {:message, ^request}
      end
    end

    test "leaves reliable-gameplay requests on the existing session path for Task 31" do
      test_pid = self()
      player_pid = spawn(fn -> route_loop(test_pid) end)
      session = %{player_session_pid: player_pid}

      request = %HomunculusRequest{
        request_id: 988,
        command: {:inspect, %HomunculusInspectCommand{}}
      }

      assert {:ok, ^session} = ZoneServer.handle_message(request, :gameplay, session)
      assert_receive {:message, ^request}
      refute_receive {:send, _channel, _payload}
    end
  end

  describe "gameplay routing" do
    test "forwards a gameplay message to the player session" do
      test_pid = self()
      player_pid = spawn(fn -> route_loop(test_pid) end)
      session = %{player_session_pid: player_pid}

      msg = %MapLoaded{}
      assert {:ok, ^session} = ZoneServer.handle_message(msg, :gameplay, session)

      assert_receive {:message, ^msg}
    end

    test "logs and continues when no player session is present" do
      msg = %MapLoaded{}

      capture_log(fn ->
        assert {:ok, %{}} = ZoneServer.handle_message(msg, :gameplay, %{})
      end)
    end

    test "forwards any message to the player session, which is the security boundary" do
      test_pid = self()
      player_pid = spawn(fn -> route_loop(test_pid) end)
      session = %{player_session_pid: player_pid}

      msg = %DamageDealt{src_id: 1, target_id: 2, damage: 9_999_999}

      assert {:ok, ^session} = ZoneServer.handle_message(msg, :gameplay, session)

      assert_receive {:message, ^msg}
    end
  end

  defp route_loop(test_pid) do
    receive do
      {:message, _msg} = m ->
        send(test_pid, m)
        route_loop(test_pid)
    end
  end
end
