defmodule Aesir.AccountServer.LoginTest do
  use ExUnit.Case, async: true
  use Mimic

  import ExUnit.CaptureLog

  alias Aesir.AccountServer
  alias Aesir.Commons.Auth
  alias Aesir.Commons.GameMode
  alias Aesir.Net.Hello
  alias Aesir.Net.HelloAck
  alias Aesir.Net.LoginFailed
  alias Aesir.Net.LoginRequest

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
end
