defmodule Aesir.ZoneServer.Unit.Player.Handlers.EmoteHandlerTest do
  use ExUnit.Case, async: true
  import Aesir.ZoneServer.Factory
  import Mimic

  alias Aesir.ZoneServer.Mmo.Emotion
  alias Aesir.ZoneServer.Unit.Emote
  alias Aesir.ZoneServer.Unit.Player.Handlers.EmoteHandler

  setup :set_mimic_from_context
  setup :verify_on_exit!

  @char_id 42
  @nv_basic_id 1

  defp state(attrs \\ [], basic_level \\ 2) do
    player =
      build(
        :player_state,
        [
          character_id: @char_id,
          stats: %{progression: %{learned_skills: %{@nv_basic_id => basic_level}}}
        ] ++ attrs
      )

    build(:session_state, game_state: player)
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
      st = state(last_emote_at: now)

      assert {:noreply, ^st} = EmoteHandler.handle_emote(Emotion.id(:surprise), st)
    end

    test "emote after the flood window passes" do
      expect(Emote, :show, fn {:player, @char_id}, _type -> :ok end)

      past = System.monotonic_time(:millisecond) - 2000
      st = state(last_emote_at: past)

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

    test "an emote is refused when NV_BASIC is below level 2" do
      reject(&Emote.show/2)

      st = state([], 1)
      assert {:noreply, ^st} = EmoteHandler.handle_emote(Emotion.id(:surprise), st)
    end

    test "an emote passes when NV_BASIC is at level 2" do
      expect(Emote, :show, fn {:player, @char_id}, _type -> :ok end)

      st = state([], 2)
      {:noreply, new_state} = EmoteHandler.handle_emote(Emotion.id(:surprise), st)
      assert is_integer(new_state.game_state.last_emote_at)
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
