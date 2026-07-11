defmodule Aesir.ZoneServer.Unit.Player.Handlers.EmoteHandlerTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Emotion
  alias Aesir.ZoneServer.Unit.Emote
  alias Aesir.ZoneServer.Unit.Player.Handlers.EmoteHandler

  setup :verify_on_exit!

  @char_id 42

  defp state(overrides \\ %{}) do
    game_state = Map.merge(%{character_id: @char_id, last_emote_at: nil}, overrides)
    %{game_state: game_state, connection_pid: self()}
  end

  describe "handle_emote/2" do
    test "first emote broadcasts and stamps last_emote_at" do
      test_pid = self()

      expect(Emote, :show, fn {:player, @char_id}, type ->
        send(test_pid, {:shown, type})
        :ok
      end)

      {:noreply, new_state} = EmoteHandler.handle_emote(Emotion.id(:surprise), state())

      assert_received {:shown, 0}
      assert is_integer(new_state.game_state.last_emote_at)
    end

    test "second emote within the flood window is dropped and leaves state unchanged" do
      reject(&Emote.show/2)

      now = System.monotonic_time(:millisecond)
      st = state(%{last_emote_at: now})

      assert {:noreply, ^st} = EmoteHandler.handle_emote(Emotion.id(:surprise), st)
    end

    test "emote after the flood window passes" do
      expect(Emote, :show, fn {:player, @char_id}, _type -> :ok end)

      past = System.monotonic_time(:millisecond) - 2000
      st = state(%{last_emote_at: past})

      {:noreply, new_state} = EmoteHandler.handle_emote(Emotion.id(:surprise), st)
      assert new_state.game_state.last_emote_at > past
    end

    test "out-of-range emote (>= :max) is dropped" do
      reject(&Emote.show/2)

      st = state()
      assert {:noreply, ^st} = EmoteHandler.handle_emote(Emotion.id(:max), st)
    end

    test "the muted :chat_prohibit emote is dropped" do
      reject(&Emote.show/2)

      st = state()
      assert {:noreply, ^st} = EmoteHandler.handle_emote(Emotion.id(:chat_prohibit), st)
    end

    test "a dice emote is reshuffled to a value within the dice range" do
      test_pid = self()

      expect(Emote, :show, fn {:player, @char_id}, type ->
        send(test_pid, {:shown, type})
        :ok
      end)

      EmoteHandler.handle_emote(Emotion.id(:dice1), state())

      assert_received {:shown, type}
      assert type in Emotion.id(:dice1)..Emotion.id(:dice6)
    end
  end
end
