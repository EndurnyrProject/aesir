defmodule Aesir.AccountServer.LoginTest do
  use ExUnit.Case, async: true
  use Mimic

  import ExUnit.CaptureLog

  alias Aesir.AccountServer
  alias Aesir.Commons.Auth
  alias Aesir.Net.Hello
  alias Aesir.Net.HelloAck
  alias Aesir.Net.LoginFailed
  alias Aesir.Net.LoginRequest

  setup :verify_on_exit!

  describe "handshake" do
    test "accepts a Hello with the supported protocol version" do
      assert {:ok, %{}, [{:hello_ack, %HelloAck{accepted: true, protocol_version: 1}}]} =
               AccountServer.handle_message(
                 %Hello{protocol_version: 1, build: "dev"},
                 :control,
                 %{}
               )
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
