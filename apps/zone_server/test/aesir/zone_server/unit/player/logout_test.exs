defmodule Aesir.ZoneServer.Unit.Player.LogoutTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.Logout
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState

  @window 10_000

  describe "within_window?/2" do
    test "is false before any stamp" do
      refute Logout.within_window?(nil, 50_000)
    end

    test "holds up to and including 10 s after the stamp" do
      now = 50_000

      assert Logout.within_window?(now - @window, now)
      refute Logout.within_window?(now - @window - 1, now)
    end
  end

  describe "stamp/1 and reset_on_death/1" do
    test "a stamp opens the window at the current time" do
      before = System.monotonic_time(:millisecond)
      %SessionState{canlog_at: at} = Logout.stamp(session(1))

      assert at >= before
      assert at <= System.monotonic_time(:millisecond)
    end

    test "death leaves the window open for the same millisecond only" do
      before = System.monotonic_time(:millisecond)
      %SessionState{canlog_at: at} = Logout.reset_on_death(Logout.stamp(session(1)))

      assert at >= before - @window
      assert at <= System.monotonic_time(:millisecond) - @window
      assert Logout.within_window?(at, at + @window)
      refute Logout.within_window?(at, at + @window + 1)
    end
  end

  describe "refuse_char_select?/1" do
    setup do
      Aesir.TestEtsSetup.setup_ets_tables(%{})
    end

    test "refuses inside the window and allows outside it" do
      now = System.monotonic_time(:millisecond)

      assert Logout.refuse_char_select?(%{session(88_101) | canlog_at: now})
      refute Logout.refuse_char_select?(%{session(88_101) | canlog_at: now - @window - 1})
      refute Logout.refuse_char_select?(session(88_101))
    end

    test "refuses a concealed player outside the window" do
      on_exit(fn -> StatusStorage.remove_status(:player, 88_102, :sc_cloaking) end)
      :ok = StatusStorage.apply_status(:player, 88_102, :sc_cloaking, val1: 3)

      assert Logout.refuse_char_select?(session(88_102))
    end
  end

  defp session(character_id),
    do: %SessionState{
      game_state: %PlayerState{character_id: character_id},
      connection_pid: self()
    }
end
