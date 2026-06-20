defmodule Aesir.Commons.Network.ProtoTest do
  use ExUnit.Case, async: true

  alias Aesir.Net.Character
  alias Aesir.Net.CharAuthFailed
  alias Aesir.Net.CharCreated
  alias Aesir.Net.CharCreateFailed
  alias Aesir.Net.CharList
  alias Aesir.Net.CharListRefresh
  alias Aesir.Net.CharServerInfo
  alias Aesir.Net.CreateChar
  alias Aesir.Net.DeleteCharAck
  alias Aesir.Net.DeleteCharRequest
  alias Aesir.Net.Envelope
  alias Aesir.Net.LoginRequest
  alias Aesir.Net.LoginResponse
  alias Aesir.Net.SelectChar
  alias Aesir.Net.SessionAuth
  alias Aesir.Net.ZoneServerInfo

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

  test "session_auth round-trips through envelope oneof" do
    env = %Envelope{
      seq: 1,
      body:
        {:session_auth,
         %SessionAuth{account_id: 1_001, login_id1: 42, login_id2: 99, sex: 1, char_id: 7}}
    }

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{
              seq: 1,
              body:
                {:session_auth,
                 %SessionAuth{account_id: 1_001, login_id1: 42, login_id2: 99, sex: 1, char_id: 7}}
            }} =
             Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "char_list with nested characters round-trips through envelope oneof" do
    env = %Envelope{
      seq: 2,
      body:
        {:char_list,
         %CharList{
           account_id: 1_001,
           normal_slots: 15,
           premium_slots: 0,
           billing_slots: 0,
           producible_slots: 15,
           valid_slots: 15,
           page_count: 5,
           pincode_enabled: false,
           characters: [
             %Character{
               gid: 10_001,
               name: "Sigrid",
               class: 1,
               base_level: 99,
               job_level: 50,
               base_exp: 1_000_000,
               job_exp: 500_000,
               zeny: 99_999,
               hp: 5_000,
               max_hp: 5_000,
               sp: 1_000,
               max_sp: 1_000,
               str: 80,
               agi: 70,
               vit: 60,
               int: 40,
               dex: 90,
               luk: 30,
               status_point: 0,
               skill_point: 0,
               hair: 3,
               hair_color: 4,
               clothes_color: 0,
               weapon: 0,
               shield: 0,
               head_top: 0,
               head_mid: 0,
               head_bottom: 0,
               robe: 0,
               char_num: 0,
               last_map: "prontera",
               sex: 1,
               option: 0,
               karma: 0,
               manner: 0,
               rename: 0,
               delete_date: 0
             }
           ]
         }}
    }

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{
              seq: 2,
              body:
                {:char_list,
                 %CharList{
                   account_id: 1_001,
                   normal_slots: 15,
                   characters: [%Character{gid: 10_001, name: "Sigrid", base_level: 99}]
                 }}
            }} = Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "char_auth_failed round-trips through envelope oneof" do
    env = %Envelope{body: {:char_auth_failed, %CharAuthFailed{reason: 3}}}

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok, %Envelope{body: {:char_auth_failed, %CharAuthFailed{reason: 3}}}} =
             Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "select_char round-trips through envelope oneof" do
    env = %Envelope{body: {:select_char, %SelectChar{slot: 2}}}

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok, %Envelope{body: {:select_char, %SelectChar{slot: 2}}}} =
             Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "zone_server_info round-trips through envelope oneof" do
    env = %Envelope{
      body:
        {:zone_server_info,
         %ZoneServerInfo{char_id: 10_001, map_name: "prontera", ip: "127.0.0.1", port: 5121}}
    }

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{
              body:
                {:zone_server_info,
                 %ZoneServerInfo{
                   char_id: 10_001,
                   map_name: "prontera",
                   ip: "127.0.0.1",
                   port: 5121
                 }}
            }} = Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "create_char round-trips through envelope oneof" do
    env = %Envelope{
      body:
        {:create_char,
         %CreateChar{
           name: "Freya",
           slot: 1,
           hair_color: 2,
           hair_style: 3,
           starting_job: 0,
           sex: 1
         }}
    }

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{
              body:
                {:create_char,
                 %CreateChar{name: "Freya", slot: 1, hair_color: 2, hair_style: 3, sex: 1}}
            }} = Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "char_created round-trips through envelope oneof" do
    env = %Envelope{
      body: {:char_created, %CharCreated{character: %Character{gid: 20_001, name: "Freya"}}}
    }

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{
              body:
                {:char_created, %CharCreated{character: %Character{gid: 20_001, name: "Freya"}}}
            }} = Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "char_create_failed round-trips through envelope oneof" do
    env = %Envelope{body: {:char_create_failed, %CharCreateFailed{reason_code: 3}}}

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok, %Envelope{body: {:char_create_failed, %CharCreateFailed{reason_code: 3}}}} =
             Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "delete_char_request round-trips through envelope oneof" do
    env = %Envelope{body: {:delete_char_request, %DeleteCharRequest{char_id: 10_001}}}

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok, %Envelope{body: {:delete_char_request, %DeleteCharRequest{char_id: 10_001}}}} =
             Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "delete_char_ack round-trips through envelope oneof" do
    env = %Envelope{
      body:
        {:delete_char_ack, %DeleteCharAck{char_id: 10_001, result: 0, delete_date: 1_750_000_000}}
    }

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{
              body:
                {:delete_char_ack,
                 %DeleteCharAck{char_id: 10_001, result: 0, delete_date: 1_750_000_000}}
            }} = Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "char_list_refresh round-trips through envelope oneof" do
    env = %Envelope{body: {:char_list_refresh, %CharListRefresh{}}}

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok, %Envelope{body: {:char_list_refresh, %CharListRefresh{}}}} =
             Envelope.decode(IO.iodata_to_binary(iodata))
  end
end
