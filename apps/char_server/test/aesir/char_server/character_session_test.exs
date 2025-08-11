defmodule Aesir.CharServer.CharacterSessionTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog
  import Mimic

  alias Aesir.CharServer.CharacterSession
  alias Aesir.Commons.SessionManager

  setup :verify_on_exit!

  describe "validate_character_session/4" do
    test "returns {:ok, session_data} on successful validation" do
      aid = 123
      login_id1 = 456
      login_id2 = 789
      sex = 0
      session = %{username: "testuser"}

      stub(SessionManager, :validate_session, fn ^aid, ^login_id1, ^login_id2 ->
        {:ok, session}
      end)

      expect(SessionManager, :set_user_online, fn ^aid, :char_server -> :ok end)

      assert {:ok,
              %{
                account_id: ^aid,
                login_id1: ^login_id1,
                login_id2: ^login_id2,
                sex: ^sex,
                authenticated: true,
                username: "testuser"
              }} = CharacterSession.validate_character_session(aid, login_id1, login_id2, sex)
    end

    test "returns {:error, reason} when session validation fails with invalid_credentials" do
      aid = 123
      login_id1 = 456
      login_id2 = 789
      sex = 0

      stub(SessionManager, :validate_session, fn _, _, _ -> {:error, :invalid_credentials} end)

      capture_log(fn ->
        assert {:error, :invalid_credentials} ==
                 CharacterSession.validate_character_session(aid, login_id1, login_id2, sex)
      end)
    end

    test "returns {:error, reason} when session validation fails with session_not_found" do
      aid = 123
      login_id1 = 456
      login_id2 = 789
      sex = 1

      stub(SessionManager, :validate_session, fn _, _, _ -> {:error, :session_not_found} end)

      capture_log(fn ->
        assert {:error, :session_not_found} ==
                 CharacterSession.validate_character_session(aid, login_id1, login_id2, sex)
      end)
    end

    test "handles transaction errors from SessionManager" do
      aid = 123
      login_id1 = 456
      login_id2 = 789
      sex = 0

      stub(SessionManager, :validate_session, fn _, _, _ -> {:error, :database_error} end)

      capture_log(fn ->
        assert {:error, :database_error} ==
                 CharacterSession.validate_character_session(aid, login_id1, login_id2, sex)
      end)
    end
  end

  describe "update_session_for_character_selection/2" do
    test "correctly updates session data with character information" do
      session_data = %{account_id: 123}
      character = %{id: 1, name: "TestChar", last_map: "prontera", last_x: 150, last_y: 150}

      assert {:ok, updated_session} =
               CharacterSession.update_session_for_character_selection(session_data, character)

      assert updated_session.selected_character == character
      assert updated_session.selected_character_id == 1
      assert updated_session.last_map == "prontera"
      assert updated_session.last_position == {150, 150}
      assert updated_session.account_id == 123
    end

    test "defaults last_position to {0, 0} when character coordinates are nil" do
      session_data = %{account_id: 123}
      character = %{id: 1, name: "NewChar", last_map: "izlude", last_x: nil, last_y: nil}

      assert {:ok, updated_session} =
               CharacterSession.update_session_for_character_selection(session_data, character)

      assert updated_session.last_position == {0, 0}
    end

    test "handles mixed nil coordinates correctly" do
      session_data = %{account_id: 123}
      character = %{id: 2, name: "MixedChar", last_map: "geffen", last_x: 100, last_y: nil}

      {:ok, updated_session} =
        CharacterSession.update_session_for_character_selection(session_data, character)

      assert updated_session.last_position == {100, 0}
    end

    test "preserves existing session data when updating" do
      session_data = %{account_id: 123, username: "testuser", other_data: "preserve"}
      character = %{id: 3, name: "PreserveChar", last_map: "payon", last_x: 50, last_y: 75}

      capture_log(fn ->
        {:ok, updated_session} =
          CharacterSession.update_session_for_character_selection(session_data, character)

        assert updated_session.account_id == 123
        assert updated_session.username == "testuser"
        assert updated_session.other_data == "preserve"
        assert updated_session.selected_character == character
      end)
    end
  end

  describe "validate_session_ownership/2" do
    test "returns {:ok, session_data} for a valid, authenticated session" do
      session_data = %{account_id: 123, authenticated: true}
      expected_account_id = 123

      assert {:ok, session_data} ==
               CharacterSession.validate_session_ownership(session_data, expected_account_id)
    end

    test "returns {:error, :session_account_mismatch} for a mismatched account ID" do
      session_data = %{account_id: 456, authenticated: true}
      expected_account_id = 123

      capture_log(fn ->
        assert {:error, :session_account_mismatch} ==
                 CharacterSession.validate_session_ownership(session_data, expected_account_id)
      end)
    end

    test "returns {:error, :session_account_mismatch} for an unauthenticated session with matching account_id" do
      session_data = %{account_id: 123, authenticated: false}
      expected_account_id = 123

      capture_log(fn ->
        assert {:error, :session_account_mismatch} ==
                 CharacterSession.validate_session_ownership(session_data, expected_account_id)
      end)
    end

    test "returns {:error, :session_not_authenticated} for a session without account_id but with authenticated field" do
      session_data = %{authenticated: false}
      expected_account_id = 123

      capture_log(fn ->
        assert {:error, :session_not_authenticated} ==
                 CharacterSession.validate_session_ownership(session_data, expected_account_id)
      end)
    end

    test "returns {:error, :invalid_session} for malformed session data" do
      session_data = %{some_other_key: "value"}
      expected_account_id = 123

      capture_log(fn ->
        assert {:error, :invalid_session} ==
                 CharacterSession.validate_session_ownership(session_data, expected_account_id)
      end)
    end

    test "returns {:error, :invalid_session} for nil session data" do
      session_data = nil
      expected_account_id = 123

      capture_log(fn ->
        assert {:error, :invalid_session} ==
                 CharacterSession.validate_session_ownership(session_data, expected_account_id)
      end)
    end

    test "returns {:error, :invalid_session} for empty map" do
      session_data = %{}
      expected_account_id = 123

      capture_log(fn ->
        assert {:error, :invalid_session} ==
                 CharacterSession.validate_session_ownership(session_data, expected_account_id)
      end)
    end
  end

  describe "prepare_zone_transfer_session/2" do
    test "creates a correctly structured zone session" do
      fixed_now = ~U[2024-01-01 12:00:00Z]
      stub(DateTime, :utc_now, fn -> fixed_now end)

      session_data = %{account_id: 123, login_id1: 456, login_id2: 789, sex: 1}
      character = %{id: 1, name: "Zoner", last_map: "morocc", last_x: 50, last_y: 50}

      assert {:ok, zone_session} =
               CharacterSession.prepare_zone_transfer_session(session_data, character)

      expected_zone_session = %{
        account_id: 123,
        character_id: 1,
        character_name: "Zoner",
        login_id1: 456,
        login_id2: 789,
        last_map: "morocc",
        last_x: 50,
        last_y: 50,
        sex: 1,
        transferred_at: fixed_now
      }

      assert zone_session == expected_zone_session
    end

    test "defaults last_x and last_y to 0 if they are nil" do
      fixed_now = ~U[2024-01-01 12:00:00Z]
      stub(DateTime, :utc_now, fn -> fixed_now end)

      session_data = %{account_id: 123, login_id1: 456, login_id2: 789, sex: 0}
      character = %{id: 1, name: "Zoner", last_map: "morocc", last_x: nil, last_y: nil}

      {:ok, zone_session} =
        CharacterSession.prepare_zone_transfer_session(session_data, character)

      assert zone_session.last_x == 0
      assert zone_session.last_y == 0
    end

    test "handles mixed nil coordinates properly" do
      fixed_now = ~U[2024-01-01 12:00:00Z]
      stub(DateTime, :utc_now, fn -> fixed_now end)

      session_data = %{account_id: 123, login_id1: 456, login_id2: 789, sex: 1}
      character = %{id: 2, name: "MixedZoner", last_map: "alberta", last_x: 100, last_y: nil}

      {:ok, zone_session} =
        CharacterSession.prepare_zone_transfer_session(session_data, character)

      assert zone_session.last_x == 100
      assert zone_session.last_y == 0
    end
  end

  describe "cleanup_character_session/1" do
    test "calls SessionManager.end_session and returns :ok" do
      account_id = 123
      expect(SessionManager, :end_session, fn ^account_id -> :ok end)

      assert :ok == CharacterSession.cleanup_character_session(account_id)
    end

    test "returns :ok even if SessionManager.end_session fails" do
      account_id = 123
      expect(SessionManager, :end_session, fn ^account_id -> {:error, :not_found} end)

      assert :ok == CharacterSession.cleanup_character_session(account_id)
    end
  end

  describe "get_session_status/1" do
    test "returns {:ok, :online} when a session exists" do
      stub(SessionManager, :get_session, fn 123 -> {:ok, %{}} end)

      capture_log(fn ->
        assert {:ok, :online} == CharacterSession.get_session_status(123)
      end)
    end

    test "returns {:ok, :offline} when session is not found" do
      stub(SessionManager, :get_session, fn 123 -> {:error, :not_found} end)

      capture_log(fn ->
        assert {:ok, :offline} == CharacterSession.get_session_status(123)
      end)
    end

    test "returns {:ok, :offline} for any other session manager error" do
      stub(SessionManager, :get_session, fn 123 -> {:error, :internal_server_error} end)

      assert {:ok, :offline} == CharacterSession.get_session_status(123)
    end

    test "returns {:ok, :offline} for timeout errors" do
      stub(SessionManager, :get_session, fn 123 -> {:error, :timeout} end)

      assert {:ok, :offline} == CharacterSession.get_session_status(123)
    end

    test "returns {:ok, :online} for valid session with data" do
      stub(SessionManager, :get_session, fn 123 ->
        {:ok, %{account_id: 123, username: "test", authenticated: true}}
      end)

      assert {:ok, :online} == CharacterSession.get_session_status(123)
    end
  end

  describe "validate_session_for_operations/1" do
    test "returns {:ok, session_data} for a valid session" do
      session_data = %{account_id: 123, authenticated: true, username: "test"}

      assert {:ok, session_data} == CharacterSession.validate_session_for_operations(session_data)
    end

    test "returns {:error, :session_not_authenticated} if authenticated is false" do
      session_data = %{account_id: 123, authenticated: false, username: "test"}

      capture_log(fn ->
        assert {:error, :session_not_authenticated} ==
                 CharacterSession.validate_session_for_operations(session_data)
      end)
    end

    test "returns {:error, :incomplete_session} if username field is missing" do
      session_data = %{account_id: 123, authenticated: true}

      capture_log(fn ->
        assert {:error, :incomplete_session} ==
                 CharacterSession.validate_session_for_operations(session_data)
      end)
    end

    test "returns {:error, :incomplete_session} if account_id field is missing" do
      session_data = %{authenticated: true, username: "test"}

      capture_log(fn ->
        assert {:error, :incomplete_session} ==
                 CharacterSession.validate_session_for_operations(session_data)
      end)
    end

    test "returns {:error, :incomplete_session} if authenticated field is missing" do
      session_data = %{account_id: 123, username: "test"}

      capture_log(fn ->
        assert {:error, :incomplete_session} ==
                 CharacterSession.validate_session_for_operations(session_data)
      end)
    end

    test "returns {:error, :incomplete_session} and lists all missing fields" do
      session_data = %{authenticated: true}

      capture_log(fn ->
        assert {:error, :incomplete_session} ==
                 CharacterSession.validate_session_for_operations(session_data)
      end)
    end

    test "returns {:error, :incomplete_session} for completely empty session" do
      session_data = %{}

      capture_log(fn ->
        assert {:error, :incomplete_session} ==
                 CharacterSession.validate_session_for_operations(session_data)
      end)
    end

    test "handles nil session data gracefully" do
      session_data = nil

      assert_raise BadMapError, fn ->
        CharacterSession.validate_session_for_operations(session_data)
      end
    end
  end
end
