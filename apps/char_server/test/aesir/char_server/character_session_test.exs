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
end
