defmodule Aesir.Commons.SessionManagerTest do
  use ExUnit.Case, async: false

  alias Aesir.Commons.ClusterTestHelper
  alias Aesir.Commons.SessionManager

  setup do
    on_exit(&ClusterTestHelper.clear_all/0)
    :ok
  end

  defp session_data(username \\ "alice") do
    %{login_id1: 111, login_id2: 222, auth_code: 333, username: username}
  end

  test "create_session then get_session round-trips" do
    assert :ok = SessionManager.create_session(1, session_data())
    assert {:ok, session} = SessionManager.get_session(1)
    assert session.username == "alice"
    assert session.state == :authenticating
  end

  test "validate_session succeeds with matching login ids and fails otherwise" do
    :ok = SessionManager.create_session(2, session_data())
    assert {:ok, _} = SessionManager.validate_session(2, 111, 222)
    assert {:error, :invalid_credentials} = SessionManager.validate_session(2, 0, 0)
    assert {:error, :session_not_found} = SessionManager.validate_session(999, 1, 2)
  end

  test "issue_zone_token then consume_zone_token succeeds exactly once" do
    :ok = SessionManager.create_session(20, session_data())
    assert {:ok, token} = SessionManager.issue_zone_token(20, 50)
    assert byte_size(token) == 32

    assert :ok = SessionManager.consume_zone_token(20, 50, token)
    assert {:error, :invalid_zone_token} = SessionManager.consume_zone_token(20, 50, token)
  end

  test "consume_zone_token rejects a wrong token or wrong char_id" do
    :ok = SessionManager.create_session(21, session_data())
    {:ok, token} = SessionManager.issue_zone_token(21, 50)

    assert {:error, :invalid_zone_token} = SessionManager.consume_zone_token(21, 50, <<0, 0, 0>>)
    assert {:error, :invalid_zone_token} = SessionManager.consume_zone_token(21, 99, token)
  end

  test "zone token functions report a missing session" do
    assert {:error, :session_not_found} = SessionManager.issue_zone_token(404, 1)
    assert {:error, :session_not_found} = SessionManager.consume_zone_token(404, 1, <<1>>)
  end

  test "set_user_online records presence and feeds the duplicate-login check" do
    :ok = SessionManager.create_session(3, session_data("bob"))
    assert :ok = SessionManager.set_user_online(3, :char_server)
    assert {:ok, online} = SessionManager.get_online_user(3)
    assert online.server_type == :char_server
    assert SessionManager.get_online_count(:char_server) == 1
  end

  test "set_user_online on a missing session is rejected" do
    assert {:error, :session_not_found} = SessionManager.set_user_online(404, :char_server)
  end

  test "end_session removes session and presence" do
    :ok = SessionManager.create_session(4, session_data())
    :ok = SessionManager.set_user_online(4, :char_server)
    :ok = SessionManager.end_session(4)
    assert {:error, :not_found} = SessionManager.get_session(4)
    assert {:error, :not_found} = SessionManager.get_online_user(4)
  end

  test "server registry register / list / heartbeat / unregister" do
    :ok = SessionManager.register_server("char-1", :char_server, {127, 0, 0, 1}, 6121)
    assert [%{server_id: "char-1"}] = SessionManager.get_servers(:char_server)
    assert :ok = SessionManager.update_server_heartbeat("char-1", 7)
    assert [%{player_count: 7}] = SessionManager.get_servers(:char_server)
    assert :ok = SessionManager.unregister_server("char-1")
    assert [] = SessionManager.get_servers(:char_server)
  end

  test "update_character_location updates the online map field" do
    :ok = SessionManager.create_session(5, session_data())
    :ok = SessionManager.set_user_online(5, :zone_server, 50, "prontera")
    :ok = SessionManager.update_character_location(50, 5, "geffen", {10, 20})
    assert {:ok, %{map_name: "geffen"}} = SessionManager.get_online_user(5)
  end

  test "presence is removed when the owning process dies" do
    parent = self()
    :ok = SessionManager.create_session(6, session_data())

    owner =
      spawn(fn ->
        SessionManager.set_user_online(6, :zone_server, 60, "prontera")
        send(parent, :online)
        Process.sleep(:infinity)
      end)

    assert_receive :online, 1_000
    assert {:ok, %{server_type: :zone_server}} = SessionManager.get_online_user(6)

    Process.exit(owner, :kill)

    assert until_true(fn -> SessionManager.get_online_user(6) == {:error, :not_found} end)
  end

  test "set_user_online takes over presence ownership from a prior owner" do
    parent = self()
    :ok = SessionManager.create_session(7, session_data())

    prior =
      spawn(fn ->
        SessionManager.set_user_online(7, :char_server)
        send(parent, :prior_online)
        Process.sleep(:infinity)
      end)

    assert_receive :prior_online, 1_000
    assert {:ok, %{server_type: :char_server}} = SessionManager.get_online_user(7)

    # the current (test) process takes over ownership for zone
    :ok = SessionManager.set_user_online(7, :zone_server, 70, "prontera")
    assert {:ok, %{server_type: :zone_server}} = SessionManager.get_online_user(7)

    # killing the PRIOR owner must NOT remove presence (it is now owned by us)
    Process.exit(prior, :kill)
    Process.sleep(200)
    assert {:ok, %{server_type: :zone_server}} = SessionManager.get_online_user(7)
  end

  defp until_true(fun, retries \\ 20) do
    cond do
      fun.() ->
        true

      retries > 0 ->
        Process.sleep(25)
        until_true(fun, retries - 1)

      true ->
        false
    end
  end
end
