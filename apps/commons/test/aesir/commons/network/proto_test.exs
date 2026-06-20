defmodule Aesir.Commons.Network.ProtoTest do
  use ExUnit.Case, async: true

  alias Aesir.Net.CharServerInfo
  alias Aesir.Net.Envelope
  alias Aesir.Net.LoginRequest
  alias Aesir.Net.LoginResponse

  test "envelope round-trips a login_request through the oneof body" do
    env = %Envelope{
      seq: 7,
      body:
        {:login_request,
         %LoginRequest{username: "neo", password: "pw", client_version: 20_211_103}}
    }

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{
              seq: 7,
              body:
                {:login_request,
                 %LoginRequest{username: "neo", password: "pw", client_version: 20_211_103}}
            }} = Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "login_response carries repeated char servers" do
    env = %Envelope{
      body:
        {:login_response,
         %LoginResponse{
           account_id: 2_000_000,
           login_id1: 111,
           login_id2: 222,
           sex: 0,
           auth_token: "deadbeef",
           char_servers: [
             %CharServerInfo{name: "Aesir", ip: "127.0.0.1", port: 6121, user_count: 3}
           ]
         }}
    }

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{
              body:
                {:login_response,
                 %LoginResponse{
                   account_id: 2_000_000,
                   auth_token: "deadbeef",
                   char_servers: [%CharServerInfo{name: "Aesir", port: 6121, user_count: 3}]
                 }}
            }} = Envelope.decode(IO.iodata_to_binary(iodata))
  end
end
