defmodule Aesir.AccountServer.LoginTest do
  use ExUnit.Case, async: true
  use Mimic

  import ExUnit.CaptureLog

  alias Aesir.AccountServer
  alias Aesir.Commons.Auth
  alias Aesir.Commons.GameMode
  alias Aesir.Commons.SessionManager
  alias Aesir.Net.CharServerHero
  alias Aesir.Net.CharServerInfo
  alias Aesir.Net.Hello
  alias Aesir.Net.HelloAck
  alias Aesir.Net.LoginFailed
  alias Aesir.Net.LoginRequest
  alias Aesir.Net.LoginResponse

  setup :set_mimic_private
  setup :verify_on_exit!

  describe "handshake" do
    test "reports renewal mode" do
      stub(GameMode, :mode, fn -> :renewal end)

      assert {:ok, %{},
              [{:hello_ack, hello_ack = %HelloAck{accepted: true, protocol_version: 1}}]} =
               AccountServer.handle_message(
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
               AccountServer.handle_message(
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
                   AccountServer.handle_message(
                     %Hello{protocol_version: 99, build: "dev"},
                     :control,
                     %{}
                   )
        end)

      assert log =~ "does not match"
    end
  end

  describe "login failure" do
    test "returns LoginFailed with reason code on invalid credentials" do
      stub(Auth, :authenticate_user, fn _username, _password -> {:error, :invalid_credentials} end)

      capture_log(fn ->
        assert {:ok, %{}, [{:login_failed, %LoginFailed{reason_code: 1}}]} =
                 AccountServer.handle_message(
                   %LoginRequest{username: "x", password: "y"},
                   :control,
                   %{}
                 )
      end)
    end
  end

  describe "login success" do
    test "lists each char server with its details, rates and heroes, and the server time" do
      account = %{id: 9_100, userid: "hero_owner", sex: "M"}

      stub(Auth, :authenticate_user, fn "hero_owner", _password -> {:ok, account} end)

      stub(Auth, :list_character_summaries, fn 9_100 ->
        [
          %{name: "Ygor", class: 4008, base_level: 99, last_login: ~N[2026-11-11 20:58:00]},
          %{name: "Sigyn", class: 4, base_level: 1, last_login: nil}
        ]
      end)

      stub(SessionManager, :get_servers, fn
        :char_server ->
          [
            %{
              status: :online,
              ip: {127, 0, 0, 1},
              port: 6121,
              player_count: 12,
              max_players: 1000,
              metadata: %{
                name: "Valhalla",
                cluster_id: "default",
                region: "EU West",
                description: "The main world."
              }
            }
          ]

        :zone_server ->
          [
            %{
              status: :online,
              metadata: %{
                cluster_id: "default",
                rates: %{base_exp: 300, job_exp: 300, drop: 200}
              }
            },
            %{status: :online, metadata: %{cluster_id: "other", rates: %{base_exp: 100}}}
          ]
      end)

      before_login = System.os_time(:second)

      capture_log(fn ->
        assert {:ok, _session,
                [{:login_response, %LoginResponse{char_servers: [server]} = response}]} =
                 AccountServer.handle_message(
                   %LoginRequest{username: "hero_owner", password: "pw"},
                   :control,
                   %{}
                 )

        assert response.server_time in before_login..System.os_time(:second)

        assert server == %CharServerInfo{
                 name: "Valhalla",
                 ip: "127.0.0.1",
                 port: 6121,
                 user_count: 12,
                 server_type: 0,
                 is_new: false,
                 max_users: 1000,
                 region: "EU West",
                 description: "The main world.",
                 base_exp_rate: 300,
                 job_exp_rate: 300,
                 drop_rate: 200,
                 heroes: [
                   %CharServerHero{
                     name: "Ygor",
                     job: 4008,
                     base_level: 99,
                     last_login: 1_794_430_680
                   },
                   %CharServerHero{name: "Sigyn", job: 4, base_level: 1, last_login: 0}
                 ]
               }
      end)
    end
  end
end
