defmodule Aesir.ZoneServerTest do
  use ExUnit.Case, async: true
  use Mimic

  import ExUnit.CaptureLog

  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.SessionManager
  alias Aesir.Net.EnterAck
  alias Aesir.Net.Hello
  alias Aesir.Net.HelloAck
  alias Aesir.Net.MapLoaded
  alias Aesir.Net.SessionAuth
  alias Aesir.Net.TimeSync
  alias Aesir.Net.TimeSyncAck
  alias Aesir.ZoneServer
  alias Aesir.ZoneServer.CharacterLoader
  alias Aesir.ZoneServer.Unit.Player.PlayerSupervisor

  setup :verify_on_exit!

  describe "handshake" do
    test "accepts a Hello with the supported protocol version" do
      assert {:ok, %{}, [{:hello_ack, %HelloAck{accepted: true, protocol_version: 1}}]} =
               ZoneServer.handle_message(
                 %Hello{protocol_version: 1, build: "dev"},
                 :control,
                 %{}
               )
    end

    test "rejects a Hello with an unsupported protocol version" do
      assert {:ok, %{}, [{:hello_ack, %HelloAck{accepted: false}}]} =
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

      stub(SessionManager, :get_session, fn 100 -> {:ok, %{login_id1: 1234}} end)
      stub(CharacterLoader, :load_character, fn 50, 100 -> {:ok, character} end)
      stub(SessionManager, :set_user_online, fn 100, :zone_server, 50, "prontera" -> :ok end)
      player_pid = spawn(fn -> Process.sleep(:infinity) end)
      stub(PlayerSupervisor, :start_player, fn _args -> {:ok, player_pid} end)

      auth = %SessionAuth{account_id: 100, login_id1: 1234, login_id2: 5678, sex: 0, char_id: 50}

      assert {:ok, session, [{:enter_ack, %EnterAck{account_id: 100, x: 155, y: 180}}]} =
               ZoneServer.handle_message(auth, :control, %{})

      assert session.player_session_pid == player_pid
    end

    test "invalid auth code returns an error" do
      Mimic.copy(SessionManager)

      stub(SessionManager, :get_session, fn 100 -> {:ok, %{login_id1: 9999}} end)

      auth = %SessionAuth{account_id: 100, login_id1: 1234, login_id2: 5678, sex: 0, char_id: 50}

      capture_log(fn ->
        assert {:error, :invalid_auth} = ZoneServer.handle_message(auth, :control, %{})
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
  end

  defp route_loop(test_pid) do
    receive do
      {:message, _msg} = m ->
        send(test_pid, m)
        route_loop(test_pid)
    end
  end
end
