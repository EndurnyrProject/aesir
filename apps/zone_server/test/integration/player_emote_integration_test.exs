defmodule Aesir.ZoneServer.Integration.PlayerEmoteIntegrationTest do
  @moduledoc """
  Integration test for the player emote broadcast round-trip.

  Drives the real dispatch path: an `%EmoteRequest{}` delivered to a
  `PlayerSession` routes through `PacketHandler` and `EmoteHandler`, which
  broadcasts an `%Aesir.Net.Emotion{}` to every player in view range via
  `Unit.Emote.show/2`. Asserts a nearby player's connection receives the
  bubble and, crucially, that the sender's own connection receives it too
  (the "sender sees own bubble" guarantee of the design).

  Each player is spawned with its own tagged fake connection so per-connection
  delivery can be asserted independently, rather than counting duplicates in a
  shared mailbox.
  """

  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Net.EmoteRequest
  alias Aesir.Net.Emotion, as: EmotionMsg
  alias Aesir.ZoneServer.Mmo.Emotion

  describe "player emote broadcast" do
    test "an emote reaches a nearby player and the emoting player itself" do
      test_pid = self()
      conn_a = spawn_tagged_connection(test_pid, :a)
      conn_b = spawn_tagged_connection(test_pid, :b)

      player_a =
        start_player_session(
          id: 2001,
          name: "Emoter",
          map_name: "prontera",
          position: {150, 150},
          connection_pid: conn_a
        )

      _player_b =
        start_player_session(
          id: 2002,
          name: "Watcher",
          map_name: "prontera",
          position: {151, 150},
          connection_pid: conn_b
        )

      a_id = player_a.character.id

      simulate_incoming_message(player_a.pid, %EmoteRequest{type: Emotion.id(:surprise)})

      assert_receive {:emote_for, :b, %EmotionMsg{gid: ^a_id, type: 0}}, 500
      assert_receive {:emote_for, :a, %EmotionMsg{gid: ^a_id, type: 0}}, 500
    end
  end

  defp spawn_tagged_connection(test_pid, label) do
    spawn_link(fn -> tagged_connection_loop(test_pid, label) end)
  end

  defp tagged_connection_loop(test_pid, label) do
    receive do
      {:send, _channel, {_tag, proto}} ->
        send(test_pid, {:emote_for, label, proto})
        tagged_connection_loop(test_pid, label)

      _msg ->
        tagged_connection_loop(test_pid, label)
    end
  end
end
