defmodule Aesir.ZoneServer.Unit.Player.Handlers.ChatHandler do
  @moduledoc """
  Handles area chat messages and routes GM commands.

  The client sends `"CharName : message"`; the prefix and length are validated
  before the message is echoed to the sender and broadcast to visible players.
  A message whose body starts with `@` is dispatched as a GM command instead
  of being broadcast.
  """

  require Logger

  alias Aesir.Net.ChatMessage
  alias Aesir.ZoneServer.Gm.Dispatcher
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Unit.Broadcast

  @chat_max_size 255

  @doc """
  Processes an area chat message (protobuf analogue of CZ_REQUEST_CHAT 0x008C).
  """
  @spec handle_chat(String.t(), map()) :: {:noreply, map()}
  def handle_chat(raw_message, %{game_state: game_state, connection_pid: connection_pid} = state) do
    name_prefix = game_state.character_name <> " : "

    cond do
      byte_size(raw_message) > @chat_max_size ->
        Logger.warning(
          "Player #{game_state.character_id} sent a message exceeding maximum length."
        )

      command = gm_command(raw_message, name_prefix) ->
        Dispatcher.dispatch(command, %{game_state: game_state, connection_pid: connection_pid})

      String.starts_with?(raw_message, name_prefix) ->
        packet = %ChatMessage{gid: game_state.character_id, message: raw_message}
        MessageRouter.send_to(connection_pid, packet)
        Broadcast.to_visible_players(game_state, packet, exclude_id: game_state.character_id)

      true ->
        Logger.warning(
          "Player #{game_state.character_id} sent a malformed chat message (expected '#{name_prefix}'). Message: '#{raw_message}'"
        )
    end

    {:noreply, state}
  end

  # Returns the `@`-prefixed command string when `raw_message` carries the valid
  # name prefix and the remainder begins with `@`; otherwise nil. Keeps the chat
  # `cond` flat instead of nesting a check inside the broadcast branch.
  defp gm_command(raw_message, name_prefix) do
    case String.replace_prefix(raw_message, name_prefix, "") do
      ^raw_message -> nil
      "@" <> _ = command -> command
      _ -> nil
    end
  end
end
